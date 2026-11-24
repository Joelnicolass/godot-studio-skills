@tool
class_name GridBoard
extends Node

## A hex board in the scene tree. It owns a `HexGrid` built from its inspector values (a rectangle of `columns` ×
## `rows`, or a hexagon of `radius`), or shows one your game already has (`use_grid`). Views (`GridView3D`) are its
## children and draw it. Every query goes to the grid: `set_value`, `get_value`, `neighbors`, `distance`,
## `cells_in_range`, `find_path`, `flood`.

## A value of a cell changed (from the board or from the grid it shows).
signal cell_changed(cell: Vector2i, key: StringName, value: Variant)
## The board got a new set of cells (inspector change or `use_grid`): views draw it again.
signal rebuilt

## Columns of a rectangular board (used when `radius` is 0).
@export_range(1, 256) var columns := 7:
	set(value):
		columns = value
		_rebuild_own()
## Rows of a rectangular board (used when `radius` is 0).
@export_range(1, 256) var rows := 7:
	set(value):
		rows = value
		_rebuild_own()
## Above 0: a hexagon-shaped board of every cell within `radius` of (0, 0), instead of the rectangle.
@export_range(0, 64) var radius := 0:
	set(value):
		radius = value
		_rebuild_own()
## Width of one hex, side to side, in world units. Views place cells with it.
@export_range(0.01, 100.0, 0.01, "or_greater") var cell_size := 1.0:
	set(value):
		cell_size = value
		rebuilt.emit()

## The grid this board shows.
var grid: HexGrid:
	get:
		if _grid == null:
			_rebuild_own()
		return _grid

var _grid: HexGrid
var _own := true


## Shows `other` instead of the board's own grid (your game's rules keep it). The inspector shape no longer applies
## until `use_own_grid()`.
func use_grid(other: HexGrid) -> void:
	_own = false
	_set_grid(other)


## Goes back to the grid built from the inspector values.
func use_own_grid() -> void:
	_own = true
	_rebuild_own()


func has_cell(cell: Vector2i) -> bool:
	return grid.has_cell(cell)


func cells() -> Array[Vector2i]:
	return grid.cells()


func set_value(cell: Vector2i, key: StringName, value: Variant) -> void:
	grid.set_value(cell, key, value)


func get_value(cell: Vector2i, key: StringName, default: Variant = null) -> Variant:
	return grid.get_value(cell, key, default)


func neighbors(cell: Vector2i) -> Array[Vector2i]:
	return grid.neighbors(cell)


func distance(a: Vector2i, b: Vector2i) -> int:
	return HexGrid.distance(a, b)


func cells_in_range(cell: Vector2i, range_radius: int) -> Array[Vector2i]:
	return grid.cells_in_range(cell, range_radius)


func find_path(from: Vector2i, to: Vector2i, cost: Callable = Callable()) -> Array[Vector2i]:
	return grid.find_path(from, to, cost)


func flood(cell: Vector2i, accepts: Callable) -> Array[Vector2i]:
	return grid.flood(cell, accepts)


## The center of `cell` in the board's local space (on the XZ plane, Y = 0).
func cell_to_position(cell: Vector2i) -> Vector3:
	var flat := HexGrid.cell_to_local(cell, cell_size)
	return Vector3(flat.x, 0.0, flat.y)


## The cell under a point of the board's local space; `HexGrid.NO_CELL` when it is off the board.
func position_to_cell(point: Vector3) -> Vector2i:
	var cell := HexGrid.local_to_cell(Vector2(point.x, point.z), cell_size)
	return cell if grid.has_cell(cell) else HexGrid.NO_CELL


func _rebuild_own() -> void:
	if not _own:
		return
	_set_grid(HexGrid.hexagon(radius) if radius > 0 else HexGrid.rect(columns, rows))


func _set_grid(next: HexGrid) -> void:
	if _grid != null and _grid.value_changed.is_connected(_on_value_changed):
		_grid.value_changed.disconnect(_on_value_changed)
	_grid = next
	_grid.value_changed.connect(_on_value_changed)
	rebuilt.emit()
	update_configuration_warnings()


func _on_value_changed(cell: Vector2i, key: StringName, value: Variant) -> void:
	cell_changed.emit(cell, key, value)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if grid.size() == 0:
		warnings.append("The board has no cells: set columns and rows, or a radius above 0.")
	return warnings
