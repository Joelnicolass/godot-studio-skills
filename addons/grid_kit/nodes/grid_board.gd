# gdlint: disable=max-public-methods
@tool
class_name GridBoard
extends Node

## A board of hexagons or squares in the scene tree. It owns a grid built from its inspector values (a rectangle of
## `columns` × `rows`, or every cell within `radius` of (0, 0)) or from a saved map (`layout`), or shows one your game
## already has (`use_grid`). Views (`GridView3D`) are its children and draw it. Every query goes to the grid:
## `set_value`, `get_value`, `neighbors`, `distance`, `cells_in_range`, `find_path`, `flood`.

## A value of a cell changed (from the board or from the grid it shows).
signal cell_changed(cell: Vector2i, key: StringName, value: Variant)
## The board got a new set of cells (inspector change, `use_grid`, or cells added or removed): views draw it again.
signal rebuilt

enum Shape { HEXAGONS, SQUARES }

## A saved map. With one, the board plays a copy of it and the shape values below do not apply.
@export var layout: GridLayout:
	set(value):
		if layout == value:
			return
		if layout != null and layout.changed.is_connected(_on_layout_changed):
			layout.changed.disconnect(_on_layout_changed)
		layout = value
		if layout != null:
			layout.changed.connect(_on_layout_changed)
		_rebuild_own()
		_refresh_inspector()
## Hexagons or squares.
@export var shape := Shape.HEXAGONS:
	set(value):
		shape = value
		_shape_changed()
		_refresh_inspector()
## Squares only: 8 neighbors and a diagonal step counts as 1, instead of 4 neighbors.
@export var diagonals := false:
	set(value):
		diagonals = value
		_shape_changed()
## Columns of a rectangular board (used when `radius` is 0).
@export_range(1, 256) var columns := 7:
	set(value):
		columns = value
		_shape_changed()
## Rows of a rectangular board (used when `radius` is 0).
@export_range(1, 256) var rows := 7:
	set(value):
		rows = value
		_shape_changed()
## Above 0: every cell within `radius` steps of (0, 0) (a hexagon, or a diamond of squares), instead of the rectangle.
@export_range(0, 64) var radius := 0:
	set(value):
		radius = value
		_shape_changed()
## Width of one hex, side to side, or side of one square, in world units. Views place cells with it.
@export_range(0.01, 100.0, 0.01, "or_greater") var cell_size := 1.0:
	set(value):
		cell_size = value
		rebuilt.emit()

## The grid this board shows.
var grid: CellGrid:
	get:
		if _grid == null:
			_rebuild_own()
		return _grid

var _grid: CellGrid
var _own := true
var _rebuild_queued := false
# The editor writes the layout while painting; a game never does. Tests flip it to play the editor's part.
var _in_editor := Engine.is_editor_hint()
# Set while this board writes the layout itself, so its own `changed` does not rebuild the grid.
var _writing_layout := false


## Shows `other` instead of the board's own grid (your game's rules keep it). The inspector shape and the layout no
## longer apply until `use_own_grid()`.
func use_grid(other: CellGrid) -> void:
	_own = false
	_set_grid(other)


## Goes back to the grid built from the layout or the inspector values.
func use_own_grid() -> void:
	_own = true
	_rebuild_own()


## Copies the current grid into a new `GridLayout` and assigns it to `layout`. It returns the layout.
func save_shape_as_layout() -> GridLayout:
	var saved := GridLayout.from_grid(grid)
	layout = saved
	return saved


func has_cell(cell: Vector2i) -> bool:
	return grid.has_cell(cell)


func cells() -> Array[Vector2i]:
	return grid.cells()


func set_value(cell: Vector2i, key: StringName, value: Variant) -> void:
	grid.set_value(cell, key, value)


func get_value(cell: Vector2i, key: StringName, default: Variant = null) -> Variant:
	return grid.get_value(cell, key, default)


## The cells next to `cell`, in direction order; with `on_board_only` off, also the ones off the board.
func neighbors(cell: Vector2i, on_board_only := true) -> Array[Vector2i]:
	return grid.neighbors(cell, on_board_only)


## The cell one step from `cell` toward `direction`, on the board or not (see `CellGrid.neighbor`).
func neighbor(cell: Vector2i, direction: int) -> Vector2i:
	return grid.neighbor(cell, direction)


## The direction from `a` to `b` when they are next to each other, or -1.
func direction_to(a: Vector2i, b: Vector2i) -> int:
	return grid.direction_to(a, b)


## The cells around the board, `rings` deep (see `CellGrid.outline`).
func outline(rings := 1) -> Array[Vector2i]:
	return grid.outline(rings)


## The board cells whose `key` value is `value`.
func cells_with(key: StringName, value: Variant) -> Array[Vector2i]:
	return grid.cells_with(key, value)


## The board cell closest to the middle of the board, or `CellGrid.NO_CELL` on an empty board.
func center_cell() -> Vector2i:
	return grid.center_cell()


func distance(a: Vector2i, b: Vector2i) -> int:
	return grid.distance(a, b)


func cells_in_range(cell: Vector2i, range_radius: int) -> Array[Vector2i]:
	return grid.cells_in_range(cell, range_radius)


func find_path(from: Vector2i, to: Vector2i, cost: Callable = Callable()) -> Array[Vector2i]:
	return grid.find_path(from, to, cost)


func flood(cell: Vector2i, accepts: Callable) -> Array[Vector2i]:
	return grid.flood(cell, accepts)


## Sets one value of many cells at once. `values` is `{cell: value}`; a null value takes `key` out of that cell. Cells
## that are not on the board are skipped. In the editor, with a `layout`, the layout gets the same values.
func paint(key: StringName, values: Dictionary) -> void:
	var to_layout := _writes_layout()
	_writing_layout = true
	for cell in _sorted(values.keys()):
		if not grid.has_cell(cell):
			continue
		var value: Variant = values[cell]
		if value == null:
			grid.erase_value(cell, key)
			if to_layout:
				layout.erase_value(cell, key)
		else:
			grid.set_value(cell, key, value)
			if to_layout:
				layout.set_value(cell, key, value)
	_writing_layout = false


## Adds and takes out cells in one go. `values` is `{cell: {key: value}}`: what the added cells start with. In the
## editor, with a `layout`, the layout changes the same way.
func set_cells(add: Array[Vector2i], remove: Array[Vector2i], values: Dictionary = {}) -> void:
	var to_layout := _writes_layout()
	_writing_layout = true
	grid.remove_cells(remove)
	grid.add_cells(add)
	if to_layout:
		for cell in remove:
			layout.remove_cell(cell)
		for cell in add:
			layout.add_cell(cell)
	for cell in _sorted(values.keys()):
		if not add.has(cell) or not grid.has_cell(cell):
			continue
		var cell_values: Dictionary = values[cell]
		for key: Variant in cell_values:
			grid.set_value(cell, StringName(key), cell_values[key])
			if to_layout:
				layout.set_value(cell, StringName(key), cell_values[key])
	_writing_layout = false


## The center of `cell` in the board's local space (on the XZ plane, Y = 0).
func cell_to_position(cell: Vector2i) -> Vector3:
	var flat := grid.cell_to_local(cell, cell_size)
	return Vector3(flat.x, 0.0, flat.y)


## The cell under a point of the board's local space; `CellGrid.NO_CELL` when it is off the board.
func position_to_cell(point: Vector3) -> Vector2i:
	var cell := position_to_any_cell(point)
	return cell if grid.has_cell(cell) else CellGrid.NO_CELL


## The cell under a point of the board's local space, on the board or not (to add cells next to it).
func position_to_any_cell(point: Vector3) -> Vector2i:
	return grid.local_to_cell(Vector2(point.x, point.z), cell_size)


func _writes_layout() -> bool:
	return layout != null and _own and _in_editor


func _shape_changed() -> void:
	# With a layout the shape comes from it: setting these values (a scene loading) builds nothing.
	if layout == null:
		_rebuild_own()


func _refresh_inspector() -> void:
	if Engine.is_editor_hint():
		notify_property_list_changed()


func _rebuild_own() -> void:
	if not _own:
		return
	_set_grid(_make_own_grid())


func _make_own_grid() -> CellGrid:
	if layout != null:
		return layout.make_grid()
	if shape == Shape.SQUARES:
		return SquareGrid.disc(radius, diagonals) if radius > 0 else SquareGrid.rect(columns, rows, diagonals)
	return HexGrid.hexagon(radius) if radius > 0 else HexGrid.rect(columns, rows)


func _set_grid(next: CellGrid) -> void:
	if _grid != null and _grid.value_changed.is_connected(_on_value_changed):
		_grid.value_changed.disconnect(_on_value_changed)
		_grid.cells_changed.disconnect(_on_cells_changed)
	_grid = next
	_grid.value_changed.connect(_on_value_changed)
	_grid.cells_changed.connect(_on_cells_changed)
	rebuilt.emit()
	update_configuration_warnings()


# The layout changed (in the editor): many changes in one frame make one rebuild.
func _on_layout_changed() -> void:
	if _writing_layout or not _in_editor or _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild_from_layout.call_deferred()


func _rebuild_from_layout() -> void:
	_rebuild_queued = false
	_rebuild_own()


func _on_value_changed(cell: Vector2i, key: StringName, value: Variant) -> void:
	cell_changed.emit(cell, key, value)


func _on_cells_changed() -> void:
	rebuilt.emit()
	update_configuration_warnings()


func _validate_property(property: Dictionary) -> void:
	var prop: StringName = property.name
	if prop == &"diagonals" and shape == Shape.HEXAGONS:
		property.usage = PROPERTY_USAGE_STORAGE
	elif layout != null and (prop in [&"shape", &"diagonals", &"columns", &"rows", &"radius"]):
		property.usage |= PROPERTY_USAGE_READ_ONLY


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if grid.size() == 0:
		if layout != null:
			warnings.append("The layout has no cells: paint some with the GridKit bar, or clear layout.")
		else:
			warnings.append("The board has no cells: set columns and rows, or a radius above 0, or a layout.")
	return warnings


static func _sorted(list: Array) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	cells.assign(list)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return cells
