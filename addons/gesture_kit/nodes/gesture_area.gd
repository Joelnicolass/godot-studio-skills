@tool
@icon("res://addons/gesture_kit/icons/gesture_area.svg")
class_name GestureArea
extends Control

## A screen area that reads the fingers landing on it and tells the gestures with signals: taps with one
## or more fingers, a double tap, a long press, a swipe, a drag with any number of fingers, a pinch and
## a twist. Put it where the gestures count (Full Rect for the whole screen); a Control drawn over it
## (a HUD button) keeps its own fingers. Positions and motion are in the viewport's pixels, like an
## `InputEventScreenTouch` in `_input`.
##
## Every gesture can also press an input action (`swipe_left_action = &"ui_left"`). The mouse is a finger
## too (`use_mouse`): Alt + drag puts down two fingers mirrored around the area's center, to pinch and
## twist; Alt + Shift + drag moves both together. A trackpad pinch arrives as `pinched`.
##
## The gestures are read by `reader` (a `GestureReader`), which you can also feed yourself.

## Every finger lifted without moving past `slop_px`, before `long_press_s`. `at`: where they landed.
## `fingers`: how many were down at once. Each tap of a double tap arrives here too.
signal tapped(at: Vector2, fingers: int)
## The second tap of a pair (within `double_tap_s` and `double_tap_px`, the same fingers).
signal double_tapped(at: Vector2, fingers: int)
## A tap that no second tap followed in `double_tap_s`: for a tap that must not start a double tap.
signal tap_confirmed(at: Vector2, fingers: int)
## The fingers stayed still for `long_press_s`. No tap or swipe follows; moving on drags.
signal long_pressed(at: Vector2, fingers: int)
## The fingers of a long press lifted (also after dragging), or the area forgot them. For «hold to
## charge, let go to fire».
signal long_press_ended(at: Vector2, fingers: int)
## A quick line: at least `swipe_min_px`, at most `swipe_max_s` after the fingers started to move, with
## no long press, pinch or twist. `direction`: a unit vector snapped to `swipe_directions`. `drag_ended`
## came first.
signal swiped(direction: Vector2, fingers: int)
## The fingers moved past `slop_px`. `at`: their middle where the drag began.
signal drag_started(at: Vector2, fingers: int)
## The middle of the fingers moved by `relative` (the first call covers the slop). Where it is now:
## `reader.center()`.
signal dragged(relative: Vector2, fingers: int)
## The drag's last finger lifted. `velocity`: pixels per second just before (zero if they had stopped).
signal drag_ended(velocity: Vector2, fingers: int)
## Two fingers spread (`ratio` above 1) or closed (below 1) around `center` since the last call. A zoom
## multiplies by `ratio`.
signal pinched(ratio: float, center: Vector2)
## Two fingers turned by `radians` (clockwise on screen) around `center` since the last call.
signal twisted(radians: float, center: Vector2)

## How the pixel thresholds (`slop_px`, `double_tap_px`, `swipe_min_px`) are measured.
enum Units {
	## Pixels of the viewport, like the positions. With Stretch Mode `canvas_items` they follow the design
	## resolution; with no stretch mode they are the screen's own, which are small on a phone.
	VIEWPORT_PIXELS,
	## Density-independent pixels (dp, 160 per inch, as Android measures): the same size on every screen.
	DENSITY_PIXELS,
}

# The finger indices of the mouse and of its mirrored twin (a screen's fingers count from 0).
const MOUSE_FINGER := 1000
const MOUSE_TWIN := 1001
const OUTLINE := Color(0.45, 0.8, 1.0, 0.6)
const FINGER_RADIUS := 28.0

## How `slop_px`, `double_tap_px` and `swipe_min_px` are measured: viewport pixels, or density-independent
## pixels (the same size on every screen; read from the screen's DPI and the window's stretch).
@export var units := Units.VIEWPORT_PIXELS:
	set(value):
		units = value
		_apply_pixels()

@export_group("Taps")
## Pixels the fingers can move and still tap or hold. Past it they drag; two fingers whose gap changes
## by more than it pinch.
@export_range(0, 64, 1, "or_greater", "suffix:px") var slop_px := 12.0:
	set(value):
		slop_px = maxf(value, 0.0)
		_apply_pixels()
## Seconds held still for a long press. A tap lifts before it.
@export_range(0.1, 3, 0.05, "or_greater", "suffix:s") var long_press_s := 0.5:
	set(value):
		long_press_s = maxf(value, 0.01)
		_reader.long_press_s = long_press_s
## Seconds between a tap lifting and the next one landing for a double tap; `tap_confirmed` waits this.
@export_range(0.05, 1, 0.05, "or_greater", "suffix:s") var double_tap_s := 0.3:
	set(value):
		double_tap_s = maxf(value, 0.0)
		_reader.double_tap_s = double_tap_s
## Pixels between the two taps of a double tap.
@export_range(0, 200, 1, "or_greater", "suffix:px") var double_tap_px := 50.0:
	set(value):
		double_tap_px = maxf(value, 0.0)
		_apply_pixels()

@export_group("Swipe")
## Pixels the fingers travel for a swipe.
@export_range(1, 400, 1, "or_greater", "suffix:px") var swipe_min_px := 60.0:
	set(value):
		swipe_min_px = maxf(value, 1.0)
		_apply_pixels()
## Seconds from the first finger landing to the last one lifting for a swipe.
@export_range(0.05, 2, 0.05, "or_greater", "suffix:s") var swipe_max_s := 0.5:
	set(value):
		swipe_max_s = maxf(value, 0.01)
		_reader.swipe_max_s = swipe_max_s
## The directions `swiped` reports: four (compare with `Vector2.LEFT` and the others), eight, or any.
@export var swipe_directions := GestureReader.Directions.FOUR:
	set(value):
		swipe_directions = value
		_reader.swipe_directions = value

@export_group("Two fingers")
## Degrees two fingers turn before `twisted` starts, so a pinch does not also turn.
@export_range(0, 45, 0.5, "suffix:°") var twist_start_deg := 10.0:
	set(value):
		twist_start_deg = clampf(value, 0.0, 180.0)
		_reader.twist_start_deg = twist_start_deg

@export_group("Actions")
## The input action a tap presses and releases in one go (empty: none). `is_action_just_pressed` and
## `_unhandled_input` see it; `is_action_pressed` and `get_axis` do not, it is never held.
@export var tap_action := &"":
	set(value):
		tap_action = value
		update_configuration_warnings()
## The input action a double tap presses and releases.
@export var double_tap_action := &"":
	set(value):
		double_tap_action = value
		update_configuration_warnings()
## The input action a long press presses and releases.
@export var long_press_action := &"":
	set(value):
		long_press_action = value
		update_configuration_warnings()
## The input action a swipe to the left presses and releases (the nearest of the four directions; a
## diagonal of `Directions.EIGHT` presses both of its own).
@export var swipe_left_action := &"":
	set(value):
		swipe_left_action = value
		update_configuration_warnings()
## The input action a swipe to the right presses and releases.
@export var swipe_right_action := &"":
	set(value):
		swipe_right_action = value
		update_configuration_warnings()
## The input action a swipe up presses and releases.
@export var swipe_up_action := &"":
	set(value):
		swipe_up_action = value
		update_configuration_warnings()
## The input action a swipe down presses and releases.
@export var swipe_down_action := &"":
	set(value):
		swipe_down_action = value
		update_configuration_warnings()

@export_group("Testing")
## The left mouse button is a finger. Alt + drag: two fingers mirrored around the area's center (pinch
## and twist); Alt + Shift + drag: both move together. Off while Godot's Emulate Touch From Mouse is on
## (its touches already come in), and the mouse Godot emulates from a real finger never counts.
@export var use_mouse := true:
	set(value):
		use_mouse = value
		if not value:
			_lift_mouse(_mouse_at)
## Draws a circle on each finger, the long press filling up and the last gesture's name, in the game.
@export var show_fingers := false:
	set(value):
		show_fingers = value
		_wake()
		queue_redraw()

## The gesture reader this area feeds; its thresholds are the ones above.
var reader: GestureReader:
	get:
		return _reader

var _reader := GestureReader.new()
var _mouse_down := false
var _twin := false
var _mouse_at := Vector2.ZERO
var _twin_at := Vector2.ZERO
var _said := ""
var _said_s := -10.0
# Where the last gesture's name is drawn (local): beside the fingers.
var _said_at := Vector2(8, 24)


func _init() -> void:
	_reader.tapped.connect(_on_tapped)
	_reader.double_tapped.connect(_on_double_tapped)
	_reader.tap_confirmed.connect(_on_tap_confirmed)
	_reader.long_pressed.connect(_on_long_pressed)
	_reader.long_press_ended.connect(_on_long_press_ended)
	_reader.swiped.connect(_on_swiped)
	_reader.drag_started.connect(_on_drag_started)
	_reader.dragged.connect(dragged.emit)
	_reader.drag_ended.connect(_on_drag_ended)
	_reader.pinched.connect(_on_pinched)
	_reader.twisted.connect(_on_twisted)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE:
			if not Engine.is_editor_hint():
				get_viewport().size_changed.connect(_apply_pixels)
			_apply_pixels()
		NOTIFICATION_VISIBILITY_CHANGED:
			if not is_visible_in_tree():
				_forget()
		NOTIFICATION_EXIT_TREE:
			_forget()
			if not Engine.is_editor_hint():
				get_viewport().size_changed.disconnect(_apply_pixels)
		# A paused or disabled area gets no more events: the lift of a finger down would be lost.
		NOTIFICATION_PAUSED, NOTIFICATION_DISABLED:
			_forget()
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_forget()


func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var at := _screen(touch.position)
		if touch.canceled:
			# The system cancels every finger at once (a call, a system gesture).
			_forget()
		elif touch.pressed:
			_reader.press(touch.index, at, _clock())
		else:
			_reader.lift(touch.index, at, _clock())
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_reader.move(drag.index, _screen(drag.position), _clock())
	elif event is InputEventMouse:
		_on_mouse(event as InputEventMouse)
	elif event is InputEventMagnifyGesture:
		var magnify := event as InputEventMagnifyGesture
		if _reader.fingers_down() == 0:
			_said_at = magnify.position + Vector2(FINGER_RADIUS, -FINGER_RADIUS)
			_on_pinched(magnify.factor, _screen(magnify.position))
	_wake()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	_reader.update(_clock())
	if show_fingers:
		queue_redraw()
	set_process(_reader.is_waiting() or show_fingers)


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, size), OUTLINE, false, 2.0)
		draw_string(get_theme_default_font(), Vector2(8, 20), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, OUTLINE)
		return
	if not show_fingers and not _twin:
		return
	var to_local := get_global_transform_with_canvas().affine_inverse()
	var fingers := _reader.finger_positions()
	for index: int in fingers:
		var at: Vector2 = to_local * fingers[index]
		draw_circle(at, FINGER_RADIUS, Color(1, 1, 1, 0.25))
		draw_arc(at, FINGER_RADIUS, 0.0, TAU, 32, Color(1, 1, 1, 0.8), 2.0)
	if not show_fingers:
		return
	if not fingers.is_empty():
		var middle := Vector2.ZERO
		for index: int in fingers:
			middle += to_local * fingers[index]
		middle /= fingers.size()
		_said_at = middle + Vector2(FINGER_RADIUS + 12.0, -FINGER_RADIUS - 12.0)
		var hold := _reader.hold_progress()
		if hold > 0.0:
			draw_arc(middle, FINGER_RADIUS + 10.0, -PI / 2.0, -PI / 2.0 + TAU * hold, 32, OUTLINE, 4.0)
	if _clock() - _said_s < 1.0:
		draw_string(get_theme_default_font(), _said_at, _said, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if mouse_filter == MOUSE_FILTER_IGNORE:
		warnings.append("mouse_filter is Ignore: the area gets no finger. Use Stop, or Pass to let them through too.")
	var actions: Dictionary[String, StringName] = {
		"tap_action": tap_action,
		"double_tap_action": double_tap_action,
		"long_press_action": long_press_action,
		"swipe_left_action": swipe_left_action,
		"swipe_right_action": swipe_right_action,
		"swipe_up_action": swipe_up_action,
		"swipe_down_action": swipe_down_action,
	}
	for field: String in actions:
		var action := actions[field]
		if not action.is_empty() and not _has_action(action):
			warnings.append('%s: there is no action "%s" in the Input Map.' % [field, action])
	return warnings


func _on_tapped(at: Vector2, fingers: int) -> void:
	_say("tap ×%d" % fingers)
	tapped.emit(at, fingers)
	_press(tap_action)


func _on_double_tapped(at: Vector2, fingers: int) -> void:
	_say("double tap ×%d" % fingers)
	double_tapped.emit(at, fingers)
	_press(double_tap_action)


func _on_tap_confirmed(at: Vector2, fingers: int) -> void:
	tap_confirmed.emit(at, fingers)


func _on_long_pressed(at: Vector2, fingers: int) -> void:
	_say("long press ×%d" % fingers)
	long_pressed.emit(at, fingers)
	_press(long_press_action)


func _on_long_press_ended(at: Vector2, fingers: int) -> void:
	_say("long press ended")
	long_press_ended.emit(at, fingers)


func _on_swiped(direction: Vector2, fingers: int) -> void:
	_say("swipe %s ×%d" % [_arrow(direction), fingers])
	swiped.emit(direction, fingers)
	# The nearest of the four directions; a diagonal (Directions.EIGHT) presses both of its actions.
	if absf(direction.x) >= absf(direction.y):
		_press(swipe_right_action if direction.x > 0.0 else swipe_left_action)
	if absf(direction.y) >= absf(direction.x):
		_press(swipe_down_action if direction.y > 0.0 else swipe_up_action)


func _on_drag_started(at: Vector2, fingers: int) -> void:
	_say("drag ×%d" % fingers)
	drag_started.emit(at, fingers)


func _on_drag_ended(velocity: Vector2, fingers: int) -> void:
	drag_ended.emit(velocity, fingers)


func _on_pinched(ratio: float, center: Vector2) -> void:
	_say("pinch ×%.2f" % ratio)
	pinched.emit(ratio, center)


func _on_twisted(radians: float, center: Vector2) -> void:
	_say("twist %+.0f°" % rad_to_deg(radians))
	twisted.emit(radians, center)


func _on_mouse(event: InputEventMouse) -> void:
	if not use_mouse or event.device == InputEvent.DEVICE_ID_EMULATION or Input.emulate_touch_from_mouse:
		return
	var at := _screen(event.position)
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed and not _mouse_down:
			_mouse_down = true
			_mouse_at = at
			_reader.press(MOUSE_FINGER, at, _clock())
			if button.alt_pressed:
				_twin = true
				_twin_at = _mirror(at)
				_reader.press(MOUSE_TWIN, _twin_at, _clock())
		elif not button.pressed and _mouse_down:
			_lift_mouse(at)
	elif event is InputEventMouseMotion and _mouse_down:
		if _twin:
			_twin_at = _twin_at + (at - _mouse_at) if event.shift_pressed else _mirror(at)
			_reader.move(MOUSE_TWIN, _twin_at, _clock())
		_mouse_at = at
		_reader.move(MOUSE_FINGER, at, _clock())


func _lift_mouse(at: Vector2) -> void:
	if not _mouse_down:
		return
	_mouse_down = false
	if _twin:
		_twin = false
		_reader.lift(MOUSE_TWIN, _twin_at, _clock())
		queue_redraw()
	_reader.lift(MOUSE_FINGER, at, _clock())


func _forget() -> void:
	_mouse_down = false
	_twin = false
	_reader.clear()
	queue_redraw()


func _press(action: StringName) -> void:
	if action.is_empty() or not InputMap.has_action(action):
		return
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)


# The reader's pixel thresholds, in viewport pixels.
func _apply_pixels() -> void:
	var factor := 1.0
	if units == Units.DENSITY_PIXELS and is_inside_tree() and not Engine.is_editor_hint():
		var stretch := get_viewport().get_final_transform().get_scale().x
		factor = DisplayServer.screen_get_dpi() / 160.0 / maxf(stretch, 0.001)
	_reader.slop_px = slop_px * factor
	_reader.double_tap_px = double_tap_px * factor
	_reader.swipe_min_px = swipe_min_px * factor


func _wake() -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	set_process(_reader.is_waiting() or show_fingers)
	if show_fingers or _twin:
		queue_redraw()


func _screen(local: Vector2) -> Vector2:
	return get_global_transform_with_canvas() * local


func _mirror(at: Vector2) -> Vector2:
	return _screen(size * 0.5) * 2.0 - at


func _say(what: String) -> void:
	_said = what
	_said_s = _clock()


func _clock() -> float:
	return Time.get_ticks_usec() / 1000000.0


static func _arrow(direction: Vector2) -> String:
	var arrows := ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
	return arrows[posmod(roundi(direction.angle() / (TAU / 8.0)), 8)]


static func _has_action(action: StringName) -> bool:
	if Engine.is_editor_hint():
		return ProjectSettings.has_setting("input/%s" % action)
	return InputMap.has_action(action)
