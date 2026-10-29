@tool
extends EditorNode3DGizmoPlugin

## Editor only: a GrassClear3D's two circles (no grass inside the inner one, full grass outside
## the outer one) and a GrassField3D's ground area, so both can be placed by eye.

const SEGMENTS := 48


func _init() -> void:
	# On top: the circles lie on the ground, which would hide them.
	create_material("clear", Color(1.0, 0.85, 0.3), false, true)
	create_material("area", Color(0.95, 0.95, 0.95), false, true)


func _get_gizmo_name() -> String:
	return "GrassKit"


func _has_gizmo(node: Node3D) -> bool:
	return node is GrassClear3D or node is GrassField3D


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var node := gizmo.get_node_3d()
	var clear := node as GrassClear3D
	if clear != null:
		var lines := PackedVector3Array()
		for r in [clear.radius, clear.radius + clear.soft]:
			for k in SEGMENTS:
				var a := TAU * k / SEGMENTS
				var b := TAU * (k + 1) / SEGMENTS
				lines.append(Vector3(cos(a), 0.0, sin(a)) * r)
				lines.append(Vector3(cos(b), 0.0, sin(b)) * r)
		gizmo.add_lines(lines, get_material("clear", gizmo))
		return
	var field := node as GrassField3D
	if field.ground == null:
		return
	var rect := field.ground.area
	var y := field.ground.flat_height
	var to_local := field.global_transform.affine_inverse()
	var corners := [
		rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y),
	]
	var lines := PackedVector3Array()
	for k in 4:
		var a: Vector2 = corners[k]
		var b: Vector2 = corners[(k + 1) % 4]
		lines.append(to_local * Vector3(a.x, y, a.y))
		lines.append(to_local * Vector3(b.x, y, b.y))
	gizmo.add_lines(lines, get_material("area", gizmo))
