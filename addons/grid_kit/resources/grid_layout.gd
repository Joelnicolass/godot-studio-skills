@tool
class_name GridLayout
extends Resource

## A board map you can save: its shape and the values of every cell. Assign one to a `GridBoard` (`layout`) and the
## board plays a copy of it: `make_grid()` builds a fresh grid, so the game can change its cells without touching this
## file. The cells are the keys of `cells`; each one holds its values (`{&"terrain": &"forest"}`).

enum Shape { HEX, SQUARE }

## Hexagons or squares.
@export var shape := Shape.HEX:
	set(value):
		shape = value
		emit_changed()
		if Engine.is_editor_hint():
			notify_property_list_changed()
## Squares only: 8 neighbors instead of 4.
@export var diagonals := false:
	set(value):
		diagonals = value
		emit_changed()
## Every cell of the map and its values. The shape of the map is these keys.
@export var cells: Dictionary[Vector2i, Dictionary] = {}:
	set(value):
		cells = value
		emit_changed()


## A layout with the shape and the values of `grid`.
static func from_grid(grid: CellGrid) -> GridLayout:
	var layout := GridLayout.new()
	layout.read_grid(grid)
	return layout


## A new grid with these cells and values. It is a copy: changing it does not change the layout.
func make_grid() -> CellGrid:
	var grid: CellGrid
	if shape == Shape.SQUARE:
		var square := SquareGrid.new()
		square.diagonals = diagonals
		grid = square
	else:
		grid = HexGrid.new()
	var list: Array[Vector2i] = []
	list.assign(cells.keys())
	grid.add_cells(list)
	for cell in list:
		var values: Dictionary = cells[cell]
		for key: Variant in values:
			grid.set_value(cell, StringName(key), values[key])
	return grid


## Copies the shape and the values of `grid` into this layout.
func read_grid(grid: CellGrid) -> void:
	var next: Dictionary[Vector2i, Dictionary] = {}
	for cell in grid.cells():
		next[cell] = grid.values(cell)
	var square := grid as SquareGrid
	shape = Shape.SQUARE if square != null else Shape.HEX
	diagonals = square.diagonals if square != null else false
	cells = next


func has_cell(cell: Vector2i) -> bool:
	return cells.has(cell)


## Adds `cell` with no values (nothing happens when it is there).
func add_cell(cell: Vector2i) -> void:
	if not cells.has(cell):
		cells[cell] = {}
		emit_changed()


## Takes `cell` and its values out.
func remove_cell(cell: Vector2i) -> void:
	if cells.erase(cell):
		emit_changed()


## Sets a value of `cell`; the cell is added when it is not in the layout yet.
func set_value(cell: Vector2i, key: StringName, value: Variant) -> void:
	if not cells.has(cell):
		cells[cell] = {}
	var values: Dictionary = cells[cell]
	if values.has(key) and values[key] == value:
		return
	values[key] = value
	emit_changed()


## Takes one value out of `cell` (nothing happens when it is not there).
func erase_value(cell: Vector2i, key: StringName) -> void:
	if not cells.has(cell):
		return
	var values: Dictionary = cells[cell]
	if values.erase(key):
		emit_changed()


## The cells of the map whose `key` value is `value`, sorted by row and then column (the same rule as
## `CellGrid.cells_with`).
func cells_with(key: StringName, value: Variant) -> Array[Vector2i]:
	return make_grid().cells_with(key, value)


func get_value(cell: Vector2i, key: StringName, default: Variant = null) -> Variant:
	if not cells.has(cell):
		return default
	return (cells[cell] as Dictionary).get(key, default)


func _validate_property(property: Dictionary) -> void:
	if property.name == &"diagonals" and shape != Shape.SQUARE:
		property.usage = PROPERTY_USAGE_STORAGE
