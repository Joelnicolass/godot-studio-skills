@tool
class_name GridCursor
extends Node3D

## Marks cells of the board its parent `GridView3D` draws: `highlight(cells)` puts a marker on each, `clear()` takes
## them away. Use one cursor per meaning (valid moves, the selection, the hover) with its own color or marker.

## The scene placed on each highlighted cell. Empty: a flat hexagon or square (the shape of the board) in `color`.
@export var marker: PackedScene
## Color of the default marker.
@export var color := Color(1.0, 0.89, 0.48, 0.45):
	set(value):
		color = value
		if _material != null:
			_material.albedo_color = value
## How high above the board the markers float, so they never fight with the tiles.
@export_range(0.0, 1.0, 0.001, "or_greater") var lift := 0.02:
	set(value):
		lift = value
		_queue_refresh()
## Size of the default marker relative to a cell (1 touches the neighbors).
@export_range(0.1, 1.0, 0.01) var fill := 0.9:
	set(value):
		fill = value
		_queue_refresh()

var _markers: Dictionary[Vector2i, Node3D] = {}
# One mesh and one material shared by every default marker.
var _mesh := ArrayMesh.new()
var _mesh_key := ""
var _material: StandardMaterial3D
var _board: GridBoard
var _refresh_queued := false


func _enter_tree() -> void:
	var view := get_parent() as GridView3D
	_board = view.board() if view != null else null
	if _board != null and not _board.rebuilt.is_connected(_queue_refresh):
		_board.rebuilt.connect(_queue_refresh)


func _exit_tree() -> void:
	if _board != null and _board.rebuilt.is_connected(_queue_refresh):
		_board.rebuilt.disconnect(_queue_refresh)
	_board = null


## Marks exactly these cells (any cell marked before and not in the list is cleared).
func highlight(cells: Array[Vector2i]) -> void:
	var view := get_parent() as GridView3D
	if view == null or view.board() == null:
		return
	var board := view.board()
	_fit_mesh(board)
	var keep: Dictionary[Vector2i, bool] = {}
	for cell in cells:
		if not board.has_cell(cell):
			continue
		keep[cell] = true
		if not _markers.has(cell):
			var node := _make_marker()
			if node == null:
				continue
			node.position = _marker_position(board, cell)
			add_child(node)
			_markers[cell] = node
	for cell: Vector2i in _markers.keys():
		if not keep.has(cell):
			_drop(cell)


func clear() -> void:
	for cell: Vector2i in _markers.keys():
		_drop(cell)


## The cells marked now, sorted by row and then column.
func highlighted() -> Array[Vector2i]:
	var list: Array[Vector2i] = []
	list.assign(_markers.keys())
	list.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return list


# The board changed its cells, its shape or its size. Many changes in a frame make one pass: the marks of cells that
# are gone are freed and the others move; none is made again.
func _queue_refresh() -> void:
	if _refresh_queued or _markers.is_empty() or not is_inside_tree():
		return
	_refresh_queued = true
	_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	if _board == null:
		return
	for cell: Vector2i in _markers.keys():
		if not _board.has_cell(cell):
			_drop(cell)
	if _markers.is_empty():
		return
	_fit_mesh(_board)
	for cell: Vector2i in _markers:
		_markers[cell].position = _marker_position(_board, cell)


func _drop(cell: Vector2i) -> void:
	var node := _markers[cell]
	_markers.erase(cell)
	remove_child(node)
	node.queue_free()


func _marker_position(board: GridBoard, cell: Vector2i) -> Vector3:
	return board.cell_to_position(cell) + Vector3.UP * lift


func _make_marker() -> Node3D:
	if marker != null:
		return marker.instantiate() as Node3D
	var mesh_node := MeshInstance3D.new()
	mesh_node.mesh = _mesh
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.albedo_color = color
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_node.material_override = _material
	return mesh_node


# The shared mesh is the outline of one cell; it is made again, in place, only when the shape, size or `fill` change.
func _fit_mesh(board: GridBoard) -> void:
	var key := "%s|%s|%s" % [board.grid.shape_name(), board.cell_size, fill]
	if key == _mesh_key:
		return
	_mesh_key = key
	var outline := board.grid.cell_outline(board.cell_size * fill)
	var vertices := PackedVector3Array()
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		vertices.append_array([Vector3.ZERO, Vector3(b.x, 0.0, b.y), Vector3(a.x, 0.0, a.y)])
	_mesh.clear_surfaces()
	if vertices.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _get_configuration_warnings() -> PackedStringArray:
	if not get_parent() is GridView3D:
		return PackedStringArray(["GridCursor marks cells of its parent: make it a child of a GridView3D."])
	return PackedStringArray()
