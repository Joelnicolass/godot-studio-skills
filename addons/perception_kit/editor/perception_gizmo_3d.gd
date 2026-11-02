@tool
extends EditorNode3DGizmoPlugin

## Editor only: a PerceptionSensor3D's view (the sight fan, the lose arc, the near circle, a line up
## to its eyes) with a handle to drag each of `sight_radius_m`, `lose_radius_m`, `view_angle_deg`,
## `near_radius_m` and `eye_height_m`. Every drag is one step of the editor's history.

const Handles := preload("perception_handles.gd")


func _init() -> void:
	# On top: the view lies at the eyes' height, inside the actor's own mesh.
	create_material("view", Color(1.0, 0.7, 0.2), false, true)
	create_handle_material("handles")


func _get_gizmo_name() -> String:
	return "PerceptionKit"


func _has_gizmo(node: Node3D) -> bool:
	return node is PerceptionSensor3D


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var sensor := gizmo.get_node_3d() as PerceptionSensor3D
	var to_local := sensor.global_transform.affine_inverse()
	var frame := view_frame(sensor)
	var lose := maxf(sensor.lose_radius_m, sensor.sight_radius_m)
	var lines := PackedVector3Array()
	for point in PerceptionGeometry.view_lines_3d(sensor.sight_radius_m, lose, sensor.view_angle_deg, sensor.near_radius_m):
		lines.append(to_local * (frame * point))
	if not is_zero_approx(sensor.eye_height_m):
		lines.append(Vector3.ZERO)
		lines.append(to_local * sensor.eye_position())
	if not lines.is_empty():
		gizmo.add_lines(lines, get_material("view", gizmo))
	var handles := PackedVector3Array()
	for point in Handles.points(sensor.sight_radius_m, sensor.lose_radius_m, sensor.view_angle_deg, sensor.near_radius_m):
		handles.append(to_local * Handles.to_space(frame, point))
	handles.append(to_local * sensor.eye_position())
	gizmo.add_handles(handles, get_material("handles", gizmo), PackedInt32Array([0, 1, 2, 3, 4]))


func _get_handle_name(_gizmo: EditorNode3DGizmo, id: int, _secondary: bool) -> String:
	return Handles.NAMES[id]


func _get_handle_value(gizmo: EditorNode3DGizmo, id: int, _secondary: bool) -> Variant:
	return gizmo.get_node_3d().get(Handles.PROPERTIES_3D[id])


func _set_handle(
	gizmo: EditorNode3DGizmo, id: int, _secondary: bool, camera: Camera3D, at: Vector2
) -> void:
	var sensor := gizmo.get_node_3d() as PerceptionSensor3D
	drag(sensor, id, camera.project_ray_origin(at), camera.project_ray_normal(at))


func _commit_handle(
	gizmo: EditorNode3DGizmo, id: int, _secondary: bool, restore: Variant, cancel: bool
) -> void:
	var sensor := gizmo.get_node_3d() as PerceptionSensor3D
	var property := Handles.PROPERTIES_3D[id]
	if cancel:
		sensor.set(property, restore)
		return
	var history := EditorInterface.get_editor_undo_redo()
	history.create_action("Drag %s's %s" % [sensor.name, Handles.NAMES[id].to_lower()], UndoRedo.MERGE_DISABLE, sensor)
	history.add_do_property(sensor, property, sensor.get(property))
	history.add_undo_property(sensor, property, restore)
	history.commit_action()


## Handle `id` of `sensor` dragged to where a ray (`from`, `dir`) points.
static func drag(sensor: PerceptionSensor3D, id: int, from: Vector3, dir: Vector3) -> void:
	if id == Handles.EYE:
		var height := Handles.height_at(sensor.global_position, from, dir)
		if not is_nan(height):
			sensor.eye_height_m = snappedf(height, 0.01)
		return
	var at: Variant = Handles.on_plane(view_frame(sensor), from, dir)
	if at == null:
		return
	var value := Handles.value_at(id, at, sensor.sight_radius_m, sensor.lose_radius_m, 0.1)
	sensor.set(Handles.PROPERTIES_3D[id], value)


## The sensor's view: at its eyes, facing its -Z, without its scale.
static func view_frame(sensor: PerceptionSensor3D) -> Transform3D:
	return Transform3D(sensor.global_basis.orthonormalized(), sensor.eye_position())
