@tool
extends EditorPlugin

## PerceptionKit in the editor: the handles of a sensor's view.
## - 3D: select a PerceptionSensor3D and drag its view's handles in the 3D view (sight, lose,
##   angle, near, eye height): editor/perception_gizmo_3d.gd.
## - 2D: select a PerceptionSensor2D and drag the same handles (without eye height) in the 2D view.
## Every drag is one step of the editor's history. The sensors and targets work without the plugin.

const Handles := preload("editor/perception_handles.gd")
## Pixels around a 2D handle that grab it.
const GRAB_PX := 10.0

var _gizmos: EditorNode3DGizmoPlugin
var _sensor: PerceptionSensor2D
## The 2D handle being dragged (-1: none), and its value before.
var _dragging := -1
var _restore: Variant


func _enter_tree() -> void:
	_gizmos = preload("editor/perception_gizmo_3d.gd").new()
	add_node_3d_gizmo_plugin(_gizmos)


func _exit_tree() -> void:
	_edit(null)
	remove_node_3d_gizmo_plugin(_gizmos)


func _handles(object: Object) -> bool:
	return object is PerceptionSensor2D


func _edit(object: Object) -> void:
	if _sensor != null and is_instance_valid(_sensor) and _sensor.draw.is_connected(update_overlays):
		_sensor.draw.disconnect(update_overlays)
	_sensor = object as PerceptionSensor2D
	_dragging = -1
	if _sensor != null:
		_sensor.draw.connect(update_overlays)
	update_overlays()


func _make_visible(visible: bool) -> void:
	if not visible:
		_edit(null)


func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	if not _editing():
		return
	for point in screen_handles(_sensor):
		overlay.draw_circle(point, 6.0, Color.WHITE)
		overlay.draw_circle(point, 4.0, PerceptionSensor2D.EDITOR_COLOR)


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if not _editing():
		return false
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_dragging = handle_at(_sensor, button.position)
			if _dragging < 0:
				return false
			_restore = _sensor.get(Handles.PROPERTIES_2D[_dragging])
			return true
		if _dragging >= 0:
			_commit()
			return true
		return false
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging >= 0:
		drag(_sensor, _dragging, motion.position)
		update_overlays()
		return true
	return false


## Where `sensor`'s handles are on the 2D view's screen.
static func screen_handles(sensor: PerceptionSensor2D) -> PackedVector2Array:
	var to_screen := sensor.get_viewport_transform() * _frame(sensor)
	var out := PackedVector2Array()
	for point in Handles.points(sensor.sight_radius_px, sensor.lose_radius_px, sensor.view_angle_deg, sensor.near_radius_px):
		out.append(to_screen * point)
	return out


## The handle of `sensor` under `screen` (a point of the 2D view), or -1. The nearest wins.
static func handle_at(sensor: PerceptionSensor2D, screen: Vector2) -> int:
	var best := -1
	var best_distance := GRAB_PX
	var handles := screen_handles(sensor)
	for id in handles.size():
		var distance := handles[id].distance_to(screen)
		if distance <= best_distance:
			best = id
			best_distance = distance
	return best


## Handle `id` of `sensor` dragged to `screen` (a point of the 2D view).
static func drag(sensor: PerceptionSensor2D, id: int, screen: Vector2) -> void:
	var at := (sensor.get_viewport_transform() * _frame(sensor)).affine_inverse() * screen
	var value := Handles.value_at(id, at, sensor.sight_radius_px, sensor.lose_radius_px, 1.0)
	sensor.set(Handles.PROPERTIES_2D[id], value)


## The sensor's view: at its position, facing its +X, without its scale.
static func _frame(sensor: PerceptionSensor2D) -> Transform2D:
	return Transform2D(sensor.global_rotation, sensor.global_position)


func _editing() -> bool:
	return _sensor != null and is_instance_valid(_sensor) and _sensor.is_inside_tree()


func _commit() -> void:
	var property := Handles.PROPERTIES_2D[_dragging]
	var history := get_undo_redo()
	history.create_action("Drag %s's %s" % [_sensor.name, Handles.NAMES[_dragging].to_lower()], UndoRedo.MERGE_DISABLE, _sensor)
	history.add_do_property(_sensor, property, _sensor.get(property))
	history.add_undo_property(_sensor, property, _restore)
	history.commit_action()
	_dragging = -1
