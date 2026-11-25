@tool
class_name GridCursor
extends Node3D

## Marks cells of the board its parent `GridView3D` draws: `highlight(cells)` puts a marker on each, `clear()` takes
## them away. Use one cursor per meaning (valid moves, the selection, the hover) with its own color or marker.

## The scene placed on each highlighted cell. Empty: a flat hexagon in `color`.
@export var marker: PackedScene
## Color of the default marker.
@export var color := Color(1.0, 0.89, 0.48, 0.45):
	set(value):
		color = value
		_material = null
## How high above the board the markers float, so they never fight with the tiles.
@export_range(0.0, 1.0, 0.001, "or_greater") var lift := 0.02
## Size of the default marker relative to a cell (1 touches the neighbors).
@export_range(0.1, 1.0, 0.01) var fill := 0.9

var _markers: Dictionary[Vector2i, Node3D] = {}
var _material: StandardMaterial3D
var _board: GridBoard


func _enter_tree() -> void:
	var view := get_parent() as GridView3D
	_board = view.board() if view != null else null
	if _board != null and not _board.rebuilt.is_connected(_on_board_rebuilt):
		_board.rebuilt.connect(_on_board_rebuilt)


func _exit_tree() -> void:
	if _board != null and _board.rebuilt.is_connected(_on_board_rebuilt):
		_board.rebuilt.disconnect(_on_board_rebuilt)
	_board = null


## Marks exactly these cells (any cell marked before and not in the list is cleared).
func highlight(cells: Array[Vector2i]) -> void:
	var view := get_parent() as GridView3D
	if view == null or view.board() == null:
		return
	var board := view.board()
	var keep: Dictionary[Vector2i, bool] = {}
	for cell in cells:
		if not board.has_cell(cell):
			continue
		keep[cell] = true
		if not _markers.has(cell):
			var node := _make_marker(board.cell_size)
			node.position = board.cell_to_position(cell) + Vector3.UP * lift
			add_child(node)
			_markers[cell] = node
	for cell in _markers.keys():
		if not keep.has(cell):
			_markers[cell].queue_free()
			_markers.erase(cell)


# The board changed its cells or its size: drop the marks on cells that are gone, move the rest.
func _on_board_rebuilt() -> void:
	var kept := highlighted()
	clear()
	highlight(kept)


func clear() -> void:
	for node: Node3D in _markers.values():
		node.queue_free()
	_markers.clear()


## The cells marked now, sorted by row and then column.
func highlighted() -> Array[Vector2i]:
	var list: Array[Vector2i] = []
	list.assign(_markers.keys())
	list.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return list


func _make_marker(cell_size: float) -> Node3D:
	if marker != null:
		return marker.instantiate() as Node3D
	var mesh_node := MeshInstance3D.new()
	mesh_node.mesh = _hexagon_mesh(cell_size * fill / HexGrid.SQRT3)
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.albedo_color = color
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_node.material_override = _material
	return mesh_node


## A flat pointy-top hexagon on the XZ plane, `radius` from the center to a corner.
static func _hexagon_mesh(radius: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	for i in 6:
		var angle := deg_to_rad(60.0 * i + 30.0)
		var a := Vector3(cos(angle), 0.0, sin(angle)) * radius
		var next := deg_to_rad(60.0 * (i + 1) + 30.0)
		var b := Vector3(cos(next), 0.0, sin(next)) * radius
		vertices.append_array([Vector3.ZERO, b, a])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _get_configuration_warnings() -> PackedStringArray:
	if not get_parent() is GridView3D:
		return PackedStringArray(["GridCursor marks cells of its parent: make it a child of a GridView3D."])
	return PackedStringArray()
