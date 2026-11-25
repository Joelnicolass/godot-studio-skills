extends "res://addons/grid_kit/tests/grid_test.gd"

## GridLayout: the map as a Resource. It builds copies, reads grids, edits its cells and survives a save.


func test_make_grid_is_a_copy() -> void:
	var layout := GridLayout.new()
	layout.shape = GridLayout.Shape.SQUARE
	layout.diagonals = true
	layout.set_value(Vector2i(0, 0), &"terrain", &"plain")
	layout.set_value(Vector2i(1, 0), &"terrain", &"water")
	layout.add_cell(Vector2i(0, 1))
	var grid := layout.make_grid()
	check(grid is SquareGrid and (grid as SquareGrid).diagonals, "a square layout makes a SquareGrid with diagonals")
	check(grid.size() == 3 and grid.get_value(Vector2i(1, 0), &"terrain") == &"water", "its cells and values")
	grid.set_value(Vector2i(0, 0), &"terrain", &"forest")
	grid.add_cell(Vector2i(5, 5))
	check(layout.get_value(Vector2i(0, 0), &"terrain") == &"plain", "changing the grid leaves the layout alone")
	check(not layout.has_cell(Vector2i(5, 5)), "and its cells")
	layout.shape = GridLayout.Shape.HEX
	check(layout.make_grid() is HexGrid, "a hex layout makes a HexGrid")


func test_read_grid_and_from_grid() -> void:
	var grid := HexGrid.hexagon(2)
	grid.set_value(Vector2i(1, 0), &"terrain", &"mountain")
	var layout := GridLayout.from_grid(grid)
	check(layout.shape == GridLayout.Shape.HEX and layout.cells.size() == 19, "from_grid copies the cells")
	check(layout.get_value(Vector2i(1, 0), &"terrain") == &"mountain", "and the values")
	check(layout.make_grid().to_dict() == grid.to_dict(), "the grid comes back as it was")
	var squares := SquareGrid.rect(3, 3, true)
	squares.set_value(Vector2i(2, 2), &"owner", 4)
	var other := GridLayout.new()
	other.read_grid(squares)
	check(other.shape == GridLayout.Shape.SQUARE and other.diagonals, "read_grid takes the shape and the diagonals")
	check(other.make_grid().to_dict() == squares.to_dict(), "squares round trip")
	grid.set_value(Vector2i(1, 0), &"terrain", &"plain")
	check(layout.get_value(Vector2i(1, 0), &"terrain") == &"mountain", "the layout does not follow the grid after")


func test_edit_and_changed() -> void:
	var layout := GridLayout.new()
	var count := [0]
	layout.changed.connect(func() -> void: count[0] += 1)
	layout.add_cell(Vector2i(0, 0))
	check(count[0] == 1 and layout.has_cell(Vector2i(0, 0)), "add_cell emits changed")
	layout.add_cell(Vector2i(0, 0))
	check(count[0] == 1, "adding a cell that is there emits nothing")
	layout.set_value(Vector2i(0, 0), &"terrain", &"forest")
	layout.set_value(Vector2i(0, 0), &"terrain", &"forest")
	check(count[0] == 2, "a value emits once, the same value again emits nothing: %d" % count[0])
	layout.set_value(Vector2i(4, 4), &"terrain", &"water")
	check(layout.has_cell(Vector2i(4, 4)), "set_value adds the cell when it is not there")
	layout.erase_value(Vector2i(0, 0), &"terrain")
	check(layout.get_value(Vector2i(0, 0), &"terrain", &"none") == &"none", "erase_value takes it out")
	var before: int = count[0]
	layout.erase_value(Vector2i(0, 0), &"terrain")
	layout.erase_value(Vector2i(8, 8), &"terrain")
	layout.remove_cell(Vector2i(8, 8))
	check(count[0] == before, "erasing or removing what is not there emits nothing")
	layout.remove_cell(Vector2i(4, 4))
	check(not layout.has_cell(Vector2i(4, 4)) and count[0] == before + 1, "remove_cell emits changed")
	layout.shape = GridLayout.Shape.SQUARE
	check(count[0] == before + 2, "changing the shape emits changed")


func test_save_and_load() -> void:
	var layout := GridLayout.from_grid(HexGrid.hexagon(2))
	layout.set_value(Vector2i(1, 0), &"terrain", &"forest")
	layout.set_value(Vector2i(-1, 1), &"owner", 2)
	var path := "user://grid_kit_test_layout.tres"
	check(ResourceSaver.save(layout, path) == OK, "the layout saves as a .tres")
	var text := FileAccess.get_file_as_string(path)
	check(text.contains("Vector2i(1, 0)") and text.contains('&"terrain"'), "readable: keys are cells")
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as GridLayout
	check(loaded != null, "it loads back as a GridLayout")
	if loaded != null:
		check(loaded.make_grid().to_dict() == layout.make_grid().to_dict(), "the same grid after a save")
	var squares := GridLayout.from_grid(SquareGrid.rect(3, 2, true))
	squares.set_value(Vector2i(2, 1), &"terrain", &"water")
	ResourceSaver.save(squares, path)
	var again := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as GridLayout
	check(again != null and again.make_grid().to_dict() == squares.make_grid().to_dict(), "squares survive a save")
	check(again != null and again.shape == GridLayout.Shape.SQUARE and again.diagonals, "shape and diagonals too")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_cells_with() -> void:
	var layout := GridLayout.new()
	layout.set_value(Vector2i(2, 0), &"start", 1)
	layout.set_value(Vector2i(0, 1), &"start", 1)
	layout.set_value(Vector2i(1, 0), &"start", 0)
	var seat_one: Array[Vector2i] = [Vector2i(2, 0), Vector2i(0, 1)]
	check(layout.cells_with(&"start", 1) == seat_one, "the layout answers too: %s" % [layout.cells_with(&"start", 1)])
