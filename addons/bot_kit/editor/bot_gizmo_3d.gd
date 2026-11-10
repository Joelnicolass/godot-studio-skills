@tool
extends EditorNode3DGizmoPlugin

## Editor only, in the 3D view:
## - a Bot3D: a line up to its eyes, its sight (its difficulty's sight_m, around its eyes), its fire cone ahead, the
##   distance it keeps in a fight (around its feet) and where it aims on an enemy; handles for eye height and aim
##   height.
## - a BotGoal3D: its reach, with a handle.
## Every drag is one step of the editor's history. Sight, cone and distance live in the difficulty (a shared preset):
## they are drawn, and changed in the inspector.

const Handles := preload("bot_handles.gd")
## How far ahead the fire cone is drawn at most.
const CONE_M := 12.0


func _init() -> void:
	create_material("sight", Color(1.0, 0.55, 0.2), false, true)
	create_material("keep", Color(0.35, 0.7, 1.0), false, true)
	create_material("goal", Color(1.0, 0.85, 0.2), false, true)
	create_handle_material("handles")


func _get_gizmo_name() -> String:
	return "BotKit"


func _has_gizmo(node: Node3D) -> bool:
	return node is Bot3D or node is BotGoal3D


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var node := gizmo.get_node_3d()
	var to_local := node.global_transform.affine_inverse()
	if node is BotGoal3D:
		var goal := node as BotGoal3D
		var ring := PackedVector3Array()
		for point in Handles.circle(goal.global_position, goal.reach_m):
			ring.append(to_local * point)
		if not ring.is_empty():
			gizmo.add_lines(ring, get_material("goal", gizmo))
		gizmo.add_handles(PackedVector3Array([to_local * goal_handle(goal)]), get_material("handles", gizmo), PackedInt32Array([0]))
		return
	var bot := node as Bot3D
	var level := bot.current_difficulty()
	var feet := bot.feet()
	var eye := bot.eye_position()
	var sight := PackedVector3Array([to_local * feet, to_local * eye])
	for point in Handles.circle(eye, level.sight_m, 64):
		sight.append(to_local * point)
	var forward := -bot.global_basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	var cone := minf(level.sight_m, CONE_M)
	for side: float in [-1.0, 1.0]:
		sight.append(to_local * eye)
		sight.append(to_local * (eye + forward.rotated(Vector3.UP, deg_to_rad(level.fire_cone_deg) * side) * cone))
	var aim := aim_handle(bot)
	for axis: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
		sight.append(to_local * (aim - axis * 0.15))
		sight.append(to_local * (aim + axis * 0.15))
	gizmo.add_lines(sight, get_material("sight", gizmo))
	var keep := PackedVector3Array()
	for point in Handles.circle(feet + Vector3.UP * 0.05, level.keep_m):
		keep.append(to_local * point)
	if not keep.is_empty():
		gizmo.add_lines(keep, get_material("keep", gizmo))
	gizmo.add_handles(PackedVector3Array([to_local * eye, to_local * aim]), get_material("handles", gizmo), PackedInt32Array([0, 1]))


func _get_handle_name(gizmo: EditorNode3DGizmo, id: int, _secondary: bool) -> String:
	return "Reach" if gizmo.get_node_3d() is BotGoal3D else Handles.BOT_NAMES[id]


func _get_handle_value(gizmo: EditorNode3DGizmo, id: int, _secondary: bool) -> Variant:
	return gizmo.get_node_3d().get(_property(gizmo.get_node_3d(), id))


func _set_handle(gizmo: EditorNode3DGizmo, id: int, _secondary: bool, camera: Camera3D, at: Vector2) -> void:
	drag(gizmo.get_node_3d(), id, camera.project_ray_origin(at), camera.project_ray_normal(at))


func _commit_handle(gizmo: EditorNode3DGizmo, id: int, _secondary: bool, restore: Variant, cancel: bool) -> void:
	var node := gizmo.get_node_3d()
	var property := _property(node, id)
	if cancel:
		node.set(property, restore)
		return
	var history := EditorInterface.get_editor_undo_redo()
	history.create_action("Drag %s's %s" % [node.name, _get_handle_name(gizmo, id, false).to_lower()], UndoRedo.MERGE_DISABLE, node)
	history.add_do_property(node, property, node.get(property))
	history.add_undo_property(node, property, restore)
	history.commit_action()


## Handle `id` of `node` (a Bot3D or a BotGoal3D) dragged to where a ray (`from`, `dir`) points.
static func drag(node: Node3D, id: int, from: Vector3, dir: Vector3) -> void:
	if node is BotGoal3D:
		var reach := Handles.reach_at(node.global_position, from, dir)
		if not is_nan(reach):
			node.set(&"reach_m", snappedf(reach, 0.5))
		return
	var bot := node as Bot3D
	var height := Handles.height_at(bot.feet(), from, dir)
	if not is_nan(height):
		bot.set(Handles.BOT_PROPERTIES[id], clampf(snappedf(height, 0.01), 0.0, 5.0))


## Where a bot's aim height handle sits: on its feet's vertical line, a little ahead so it never hides the eye handle.
static func aim_handle(bot: Bot3D) -> Vector3:
	var forward := -bot.global_basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	return bot.feet() + Vector3.UP * bot.aim_height_m + forward * 0.3


static func goal_handle(goal: BotGoal3D) -> Vector3:
	return goal.global_position + Vector3.RIGHT * goal.reach_m


static func _property(node: Node3D, id: int) -> StringName:
	return &"reach_m" if node is BotGoal3D else Handles.BOT_PROPERTIES[id]
