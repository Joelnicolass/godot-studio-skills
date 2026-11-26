@icon("res://addons/rts_kit/icons/rts_camera_2d.svg")
class_name RtsCamera2D
extends Camera2D

## The camera of a 2D RTS, with the contract of RtsCamera3D (`yaw`, `is_dragging()`, `takes_drag()`,
## `focus()`, `debug_pointer`). FOLLOW: it keeps a body in the middle (Camera2D's own smoothing does
## the rest) and zooms with the wheel. FREE: it pans with the keys, the screen edges and a middle
## drag (and a select drag with `select_drag_pans`), zooms with the wheel between `min_zoom` and
## `max_zoom`, turns with the turn keys when `can_turn`, stays inside `bounds` and glides with
## `focus(point, seconds)`. The edges stop over the UI (`edges_over_gui`) and, with `edge_area`,
## only work over it; the wheel does nothing over a `wheel_blockers` control; nothing reads input
## while a modal UI is open (RtsWorldInput).
##
## On a touch screen (`touch_enabled`): one finger drags the map (FREE), two fingers pinch to zoom
## around them and, with `can_turn`, twist to turn. A tap stays a click, a two-finger touch never is
## one, and a gesture that starts over the UI is the UI's, as in RtsCamera3D.

enum Mode { FOLLOW, FREE }

const TouchGesture := preload("rts_touch_gesture.gd")

@export var mode := Mode.FREE:
	set(value):
		mode = value
		_dragged = false
## FOLLOW: the body kept in the middle.
@export var follow: Node2D
## Edges only work while the pointer hovers this control, and a finger only moves the view when it
## lands on it. Empty: anywhere but the UI (`edges_over_gui`).
@export var edge_area: Control
## Without `edge_area`, the edges also work while the pointer is over the UI (a control whose mouse
## filter is not Ignore), and the fingers too. Off: a HUD button or panel does not move the camera.
@export var edges_over_gui := false
## The wheel does not zoom while the pointer is over one of these (`covers(screen)` decides when the
## control has it).
@export var wheel_blockers: Array[Control] = []
## The world rectangle the camera's center stays in; empty = anywhere.
@export var bounds := Rect2()
## FREE: the turn keys rotate the view (the camera's `ignore_rotation` is turned off).
@export var can_turn := false
## FREE: a drag of `select_action` also moves the map, past `drag_px` (a strategy map). Off for an
## RTS, where that drag draws the selection box.
@export var select_drag_pans := false

@export_group("Actions")
@export var select_action: StringName = &"rts_select"
@export var order_action: StringName = &"rts_order"
@export var orbit_action: StringName = &"rts_camera_orbit"
@export var wheel_in_action: StringName = &"rts_camera_wheel_in"
@export var wheel_out_action: StringName = &"rts_camera_wheel_out"
@export var turn_left_action: StringName = &"rts_camera_turn_left"
@export var turn_right_action: StringName = &"rts_camera_turn_right"
@export var zoom_in_action: StringName = &"rts_camera_zoom_in"
@export var zoom_out_action: StringName = &"rts_camera_zoom_out"
@export var pan_left_action: StringName = &"rts_camera_pan_left"
@export var pan_right_action: StringName = &"rts_camera_pan_right"
@export var pan_up_action: StringName = &"rts_camera_pan_up"
@export var pan_down_action: StringName = &"rts_camera_pan_down"

@export_group("Motion")
@export var edge_px := 24.0
## Screen pixels per second the keys and edges pan at.
@export var pan_speed := 900.0
@export var key_turn_rate_deg := 90.0
@export var min_zoom := 0.35
@export var max_zoom := 3.0
## Zoom factor per wheel notch.
@export var wheel_step := 1.12
@export var drag_px := 3.0

@export_group("Touch")
## Reads the fingers: one drags, two pinch to zoom and twist to turn (`can_turn`). A gesture whose
## first finger lands over the UI is the UI's (the edges' rule). Off: the fingers reach the game only
## as the mouse Godot emulates.
@export var touch_enabled := true:
	set(value):
		touch_enabled = value
		if _touch != null:
			_touch.clear()
## Pixels a finger travels before it is a drag (the map moves, the touch is no click).
@export var touch_drag_px := 12.0
## How much two fingers zoom: 1 keeps the world under them, 0 = no pinch.
@export_range(0.0, 2.0, 0.05) var pinch_zoom := 1.0
## How much the view turns with two fingers (with `can_turn`): 1 turns the map with them, 0 = no
## twist.
@export_range(0.0, 2.0, 0.05) var twist_turn := 1.0
## Degrees the fingers twist before the view turns, so a pinch does not turn it by accident.
@export_range(0.0, 45.0, 0.5) var twist_start_deg := 10.0

@export_group("Debug")
## When x >= 0 it replaces the real pointer for the edges and keyboard aiming (test flows).
@export var debug_pointer := Vector2(-1.0, -1.0)

## The view's kit yaw: a formation turned by it faces up the screen.
var yaw: float:
	get:
		var up := Vector2(0.0, -1.0).rotated(0.0 if ignore_rotation else global_rotation)
		return atan2(up.x, up.y)

var _dragged := false
var _drag_travel := 0.0
var _touch := TouchGesture.new()
var _glide: Tween
var _mouse_inside := true
var _pointer := Vector2(-1.0, -1.0)


func _ready() -> void:
	if can_turn:
		ignore_rotation = false
	_keep_in_bounds()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_ENTER:
		_mouse_inside = true
	elif what == NOTIFICATION_WM_MOUSE_EXIT:
		_mouse_inside = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		# The fingers lifted while the window was away never reach it.
		_touch.clear()


## FREE: center on `point` (a kit point; RtsSpace.from_2d for a 2D one), at once or gliding there
## in `seconds` (a pan by the player stops the glide). FOLLOW: nothing (false).
func focus(point: Vector3, seconds := 0.0) -> bool:
	if mode != Mode.FREE:
		return false
	_stop_glide()
	var to := RtsSpace.to_2d(point)
	if bounds.has_area():
		to = to.clamp(bounds.position, bounds.end)
	if seconds <= 0.0 or not is_inside_tree():
		global_position = to
		reset_smoothing()
		return true
	_glide = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_glide.tween_property(self, ^"global_position", to, seconds)
	return true


## True while a held button travelled past `drag_px` (a finger: `touch_drag_px`; two fingers:
## always): the click that ends it is not an order.
func is_dragging() -> bool:
	return _dragged


## True while a held button or finger moves the view instead of picking: the camera's fingers, and
## in FREE the orbit button, or the select button with `select_drag_pans`. RtsSelectInput draws no
## box then (RtsPointer.camera_takes_drag).
func takes_drag() -> bool:
	if not is_current() or RtsWorldInput.blocked(self):
		return false
	if _touch.is_active():
		return true
	return (
		mode == Mode.FREE and (_held(orbit_action) or (select_drag_pans and _held(select_action)))
	)


func _input(event: InputEvent) -> void:
	# The mouse Godot emulates from a finger is no pointer for the edges: a finger lifted at an edge
	# would pan for ever.
	if event is InputEventMouse and event.device != InputEvent.DEVICE_ID_EMULATION:
		_pointer = (event as InputEventMouse).position
	# A finger lifts even while the world is blocked, so none stays down.
	if event is InputEventScreenTouch and not event.pressed:
		_touch.lift((event as InputEventScreenTouch).index)
		return
	if not is_current() or RtsWorldInput.blocked(self):
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if touch_enabled:
			_on_touch(event)
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		var wheel_in := _pressed(button, wheel_in_action)
		var wheel_out := _pressed(button, wheel_out_action)
		if (
			_pressed(button, select_action)
			or _pressed(button, order_action)
			or _pressed(button, orbit_action)
		):
			_dragged = false
			_drag_travel = 0.0
		elif (wheel_in or wheel_out) and _wheel_blocked(button.position):
			pass
		elif wheel_in:
			_zoom_by(wheel_step)
		elif wheel_out:
			_zoom_by(1.0 / wheel_step)
	elif event is InputEventMouseMotion:
		# The mouse Godot emulates from a finger, and any mouse while the camera's fingers are down:
		# the fingers already moved the view.
		var motion := event as InputEventMouseMotion
		var emulated := touch_enabled and motion.device == InputEvent.DEVICE_ID_EMULATION
		if not emulated and not _touch.is_active():
			_on_motion(motion)


func _on_motion(motion: InputEventMouseMotion) -> void:
	var held := false
	if _held(orbit_action):
		held = true
		if mode == Mode.FREE:
			_move_screen(-motion.relative)
	elif select_drag_pans and mode == Mode.FREE and _held(select_action):
		held = true
		# Past the threshold only, so a click with a shaky hand does not nudge the map.
		if _dragged or _drag_travel + motion.relative.length() > drag_px:
			_move_screen(-motion.relative)
	if held:
		_drag_travel += motion.relative.length()
		if _drag_travel > drag_px:
			_dragged = true


# A finger down (a pressed ScreenTouch; `_input` lifts them) or a finger moving.
func _on_touch(event: InputEvent) -> void:
	_touch.drag_px = touch_drag_px
	_touch.twist_start = deg_to_rad(twist_start_deg)
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var ours := false
		if _touch.is_idle():
			ours = _gesture_starts_at(touch.position)
			if ours:
				_dragged = false
				_drag_travel = 0.0
		_touch.press(touch.index, touch.position, ours)
	else:
		var drag := event as InputEventScreenDrag
		var step := _touch.move(drag.index, drag.position, drag.relative)
		if step.fingers == 1 and mode == Mode.FREE and step.drag != Vector2.ZERO:
			_move_screen(-step.drag)
		elif step.fingers == 2:
			_two_fingers(step)
	if _touch.is_dragged():
		_dragged = true


## A gesture is the camera's when its first finger lands where the edges work (RtsCamera3D has the
## same rule).
func _gesture_starts_at(screen: Vector2) -> bool:
	if not Input.emulate_mouse_from_touch:
		return edge_area == null or edge_area.get_global_rect().has_point(screen)
	return _edges_work_here()


# Two fingers: the pinch zooms, the twist turns the view (`can_turn`), and in FREE the world under
# their middle stays under it.
func _two_fingers(step: TouchGesture.Move) -> void:
	var anchor := _world_at(step.middle_from)
	if pinch_zoom > 0.0 and step.ratio != 1.0:
		_zoom_by(pow(step.ratio, pinch_zoom))
	if can_turn and not ignore_rotation:
		rotation -= step.twist * twist_turn
	if mode == Mode.FREE:
		_stop_glide()
		global_position += anchor - _world_at(step.middle_to)
		_keep_in_bounds()


## The world point a screen pixel shows (Camera2D's own drag margins, limits and smoothing aside).
func _world_at(screen: Vector2) -> Vector2:
	var size := get_viewport().get_visible_rect().size
	var from_view := screen - size * 0.5 if anchor_mode == ANCHOR_MODE_DRAG_CENTER else screen
	var turn := 0.0 if ignore_rotation else global_rotation
	return global_position + offset + (from_view / zoom).rotated(turn)


func _process(delta: float) -> void:
	if mode == Mode.FOLLOW and is_instance_valid(follow):
		global_position = follow.global_position
		_keep_in_bounds()
	if not is_current() or RtsWorldInput.blocked(self):
		return
	if _held(zoom_in_action):
		_zoom_by(pow(wheel_step, delta * 8.0))
	if _held(zoom_out_action):
		_zoom_by(pow(1.0 / wheel_step, delta * 8.0))
	if mode != Mode.FREE:
		return
	if can_turn:
		if _held(turn_left_action):
			rotation -= deg_to_rad(key_turn_rate_deg) * delta
		if _held(turn_right_action):
			rotation += deg_to_rad(key_turn_rate_deg) * delta
	var move := Vector2.ZERO
	if _held(pan_left_action):
		move.x -= 1.0
	if _held(pan_right_action):
		move.x += 1.0
	if _held(pan_up_action):
		move.y -= 1.0
	if _held(pan_down_action):
		move.y += 1.0
	var pointer: Variant = _edge_pointer()
	if pointer != null:
		var at := pointer as Vector2
		var size := get_viewport().get_visible_rect().size
		if at.x <= edge_px:
			move.x -= 1.0
		elif at.x >= size.x - edge_px:
			move.x += 1.0
		if at.y <= edge_px:
			move.y -= 1.0
		elif at.y >= size.y - edge_px:
			move.y += 1.0
	if move != Vector2.ZERO:
		_move_screen(move.limit_length(1.0) * pan_speed * delta)


## Moves the view by `screen_step` screen pixels (turned and zoomed into the world).
func _move_screen(screen_step: Vector2) -> void:
	_stop_glide()
	var turn := 0.0 if ignore_rotation else global_rotation
	global_position += (screen_step / zoom).rotated(turn)
	_keep_in_bounds()


func _zoom_by(factor: float) -> void:
	var next := clampf(zoom.x * factor, min_zoom, max_zoom)
	zoom = Vector2(next, next)


func _stop_glide() -> void:
	if _glide != null and _glide.is_valid():
		_glide.kill()
	_glide = null


func _keep_in_bounds() -> void:
	if not bounds.has_area():
		return
	global_position = global_position.clamp(bounds.position, bounds.end)


func _edge_pointer() -> Variant:
	if debug_pointer.x >= 0.0:
		return debug_pointer
	if not _mouse_inside or not get_window().has_focus() or _held(orbit_action):
		return null
	if _pointer.x < 0.0:
		return null
	return _pointer if _edges_work_here() else null


## Over `edge_area` when it is set; otherwise anywhere but the UI, unless `edges_over_gui`.
func _edges_work_here() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	if edge_area:
		return hovered == edge_area
	return hovered == null or edges_over_gui


func _wheel_blocked(screen: Vector2) -> bool:
	for blocker in wheel_blockers:
		if blocker == null or not blocker.is_visible_in_tree():
			continue
		if blocker.has_method("covers"):
			if bool(blocker.call("covers", screen)):
				return true
		elif Rect2(Vector2.ZERO, blocker.size).has_point(
			blocker.get_global_transform().affine_inverse() * screen
		):
			return true
	return false


func _held(action: StringName) -> bool:
	return InputMap.has_action(action) and Input.is_action_pressed(action, true)


func _pressed(event: InputEvent, action: StringName) -> bool:
	return InputMap.has_action(action) and event.is_action_pressed(action)
