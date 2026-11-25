extends "res://addons/grid_kit/tests/grid_test.gd"

## GridBoard: shapes from the inspector, layouts, paint and set_cells, positions and inspector rules.

const TILE := preload("res://addons/grid_kit/examples/minimal_3d/tiles/plain.tscn")
const OTHER := preload("res://addons/grid_kit/examples/minimal_3d/tiles/water.tscn")


func test_board_from_inspector() -> void:
	var board := build_board(2)
	check(board.cells().size() == 19, "radius 2: 19 cells")
	board.radius = 0
	board.columns = 3
	board.rows = 2
	check(board.cells().size() == 6, "radius 0 uses columns x rows: %d" % board.cells().size())
	check(board._get_configuration_warnings().is_empty(), "no warnings with cells")
	board.free()


func test_board_squares_from_inspector() -> void:
	var board := build_square_board(4, 3)
	check(board.grid is SquareGrid and board.cells().size() == 12, "squares: 4 x 3 = 12 cells")
	check(board.neighbors(Vector2i(1, 1)).size() == 4, "no diagonals: 4 neighbors")
	board.diagonals = true
	check(
		board.neighbors(Vector2i(1, 1)).size() == 8 and board.distance(Vector2i(0, 0), Vector2i(2, 2)) == 2, "diagonals"
	)
	board.radius = 2
	check(board.cells().size() == 25, "radius works on squares too (with diagonals a 5 x 5): %d" % board.cells().size())
	board.diagonals = false
	check(board.cells().size() == 13, "radius 2 without diagonals is a diamond: %d" % board.cells().size())
	board.shape = GridBoard.Shape.HEXAGONS
	check(board.grid is HexGrid and board.cells().size() == 19, "back to hexagons: 19 cells")
	check(board.cell_to_position(Vector2i(1, 0)).is_equal_approx(Vector3(1, 0, 0)), "hex position")
	board.shape = GridBoard.Shape.SQUARES
	board.radius = 0
	board.cell_size = 2.0
	check(board.cell_to_position(Vector2i(1, 2)).is_equal_approx(Vector3(2, 0, 4)), "square position uses cell_size")
	check(board.position_to_cell(Vector3(2.2, 0, 3.9)) == Vector2i(1, 2), "and picks back")
	board.free()


func test_position_to_any_cell() -> void:
	var board := build_square_board(3, 3)
	check(board.position_to_cell(Vector3(7, 0, 0)) == CellGrid.NO_CELL, "off the board: NO_CELL")
	check(board.position_to_any_cell(Vector3(7, 0, 0)) == Vector2i(7, 0), "position_to_any_cell answers anyway")
	check(board.position_to_any_cell(Vector3(-1.1, 0, -0.2)) == Vector2i(-1, 0), "negatives too")
	board.free()


func test_inspector_visibility() -> void:
	var board := build_square_board(3, 3)
	var property := {"name": &"diagonals", "usage": PROPERTY_USAGE_DEFAULT}
	board._validate_property(property)
	check(property["usage"] & PROPERTY_USAGE_EDITOR != 0, "diagonals show for squares")
	board.shape = GridBoard.Shape.HEXAGONS
	property = {"name": &"diagonals", "usage": PROPERTY_USAGE_DEFAULT}
	board._validate_property(property)
	check(property["usage"] & PROPERTY_USAGE_EDITOR == 0, "diagonals hide for hexagons")
	board.layout = GridLayout.from_grid(HexGrid.rect(2, 2))
	var columns := {"name": &"columns", "usage": PROPERTY_USAGE_DEFAULT}
	board._validate_property(columns)
	check(columns["usage"] & PROPERTY_USAGE_READ_ONLY != 0, "with a layout the shape values are read only")
	var cell_size := {"name": &"cell_size", "usage": PROPERTY_USAGE_DEFAULT}
	board._validate_property(cell_size)
	check(cell_size["usage"] & PROPERTY_USAGE_READ_ONLY == 0, "cell_size still applies")
	board.free()


func test_layout_rules_the_board() -> void:
	var layout := GridLayout.from_grid(SquareGrid.rect(3, 2, true))
	layout.set_value(Vector2i(2, 1), &"terrain", &"water")
	var board := build_board(4)
	check(board.cells().size() == 61, "without a layout the inspector shape rules")
	board.layout = layout
	check(board.grid is SquareGrid and board.cells().size() == 6, "a layout rules the shape")
	check(board.get_value(Vector2i(2, 1), &"terrain") == &"water", "and the values")
	check(board.neighbors(Vector2i(1, 0)).size() == 5, "with its diagonals")
	board.radius = 1
	board.columns = 9
	board.shape = GridBoard.Shape.HEXAGONS
	check(board.cells().size() == 6 and board.grid is SquareGrid, "the inspector shape does not apply to a layout")
	board.set_value(Vector2i(0, 0), &"terrain", &"forest")
	check(layout.get_value(Vector2i(0, 0), &"terrain") == null, "playing never writes the layout")
	layout.set_value(Vector2i(0, 0), &"terrain", &"sea")
	await tree.process_frame
	check(board.get_value(Vector2i(0, 0), &"terrain") == &"forest", "in a game the layout is not watched")
	board.layout = null
	check(board.cells().size() == 7 and board.grid is HexGrid, "no layout: the inspector values apply again")
	board.free()


func test_layout_change_rebuilds_grouped() -> void:
	var layout := GridLayout.from_grid(HexGrid.rect(2, 2))
	var board := build_board(1)
	board._in_editor = true
	var rebuilds := [0]
	board.layout = layout
	board.rebuilt.connect(func() -> void: rebuilds[0] += 1)
	for i in 20:
		layout.add_cell(Vector2i(10 + i, 0))
	check(rebuilds[0] == 0 and board.cells().size() == 4, "nothing rebuilds while the frame runs")
	await tree.process_frame
	check(rebuilds[0] == 1, "20 changes in a frame make one rebuild: %d" % rebuilds[0])
	check(board.cells().size() == 24, "and the board has them all: %d" % board.cells().size())
	layout.shape = GridLayout.Shape.SQUARE
	await tree.process_frame
	check(board.grid is SquareGrid, "a layout shape change rebuilds with the new class")
	board.free()


func test_paint_with_and_without_layout() -> void:
	var board := build_board(1)
	await tree.process_frame
	var view := board.get_node(^"View") as GridView3D
	board.paint(&"terrain", {Vector2i(0, 0): &"water", Vector2i(1, 0): &"water", Vector2i(9, 9): &"water"})
	check(board.get_value(Vector2i(0, 0), &"terrain") == &"water", "paint sets the value")
	check(not board.has_cell(Vector2i(9, 9)), "a cell off the board is skipped")
	check(view.tile_at(Vector2i(1, 0)).scene_file_path == OTHER.resource_path, "the view draws it")
	board.paint(&"terrain", {Vector2i(0, 0): null})
	check(board.get_value(Vector2i(0, 0), &"terrain") == null, "null takes the value out")
	check(view.tile_at(Vector2i(0, 0)).scene_file_path == TILE.resource_path, "and the cell goes back to default_tile")
	var layout := GridLayout.from_grid(board.grid)
	board.layout = layout
	board.paint(&"terrain", {Vector2i(0, 0): &"water"})
	check(layout.get_value(Vector2i(0, 0), &"terrain") == null, "in a game paint leaves the layout alone")
	board._in_editor = true
	board.paint(&"terrain", {Vector2i(0, 0): &"water", Vector2i(1, 0): &"forest"})
	check(layout.get_value(Vector2i(0, 0), &"terrain") == &"water", "in the editor paint writes the layout")
	check(board.get_value(Vector2i(1, 0), &"terrain") == &"forest", "and the live grid")
	var grid_before := board.grid
	await tree.process_frame
	check(board.grid == grid_before, "the board does not rebuild itself over its own writes")
	board.paint(&"terrain", {Vector2i(0, 0): null})
	check(layout.get_value(Vector2i(0, 0), &"terrain") == null, "null erases in the layout too")
	board.free()


func test_set_cells_with_and_without_layout() -> void:
	var board := build_board(1)
	await tree.process_frame
	var view := board.get_node(^"View") as GridView3D
	var rebuilds := [0]
	board.rebuilt.connect(func() -> void: rebuilds[0] += 1)
	var add: Array[Vector2i] = [Vector2i(5, 5), Vector2i(6, 5)]
	var remove: Array[Vector2i] = [Vector2i(0, 0)]
	board.set_cells(add, remove, {Vector2i(5, 5): {&"terrain": &"water"}})
	check(board.has_cell(Vector2i(5, 5)) and not board.has_cell(Vector2i(0, 0)), "cells added and removed")
	check(board.get_value(Vector2i(5, 5), &"terrain") == &"water", "the added cell starts with its values")
	await tree.process_frame
	check(view.tile_at(Vector2i(5, 5)).scene_file_path == OTHER.resource_path, "the view draws the new cell")
	check(view.tile_at(Vector2i(0, 0)) == null, "and drops the removed one")
	var layout := GridLayout.from_grid(board.grid)
	board.layout = layout
	board._in_editor = true
	var again: Array[Vector2i] = [Vector2i(7, 7)]
	var take: Array[Vector2i] = [Vector2i(5, 5)]
	board.set_cells(again, take, {Vector2i(7, 7): {&"terrain": &"forest"}})
	check(layout.has_cell(Vector2i(7, 7)) and not layout.has_cell(Vector2i(5, 5)), "in the editor the layout follows")
	check(layout.get_value(Vector2i(7, 7), &"terrain") == &"forest", "with the values")
	check(board.get_value(Vector2i(7, 7), &"terrain") == &"forest", "and so does the live grid")
	board.free()


func test_save_shape_as_layout() -> void:
	var board := build_board(1)
	board.set_value(Vector2i(0, 0), &"terrain", &"water")
	var saved := board.save_shape_as_layout()
	check(board.layout == saved and saved.cells.size() == 7, "the board now has a layout with its cells")
	check(saved.get_value(Vector2i(0, 0), &"terrain") == &"water", "and its values")
	board.free()


func test_warnings_for_layouts() -> void:
	var board := GridBoard.new()
	board.layout = GridLayout.new()
	tree.root.add_child(board)
	var warnings := board._get_configuration_warnings()
	check(warnings.size() == 1 and warnings[0].contains("layout"), "an empty layout is said: %s" % [warnings])
	board.layout = null
	check(board._get_configuration_warnings().is_empty(), "without a layout the default shape has cells")
	board.free()


func test_use_external_grid() -> void:
	var board := build_board(1)
	var view := board.get_node(^"View") as GridView3D
	var game_grid := HexGrid.rect(2, 2)
	game_grid.set_value(Vector2i(1, 1), &"terrain", &"water")
	board.use_grid(game_grid)
	await tree.process_frame
	check(board.cells().size() == 4, "the board shows the game's grid")
	check(view.tile_at(Vector2i(1, 1)).scene_file_path == OTHER.resource_path, "with its values")
	game_grid.set_value(Vector2i(0, 0), &"terrain", &"water")
	check(view.tile_at(Vector2i(0, 0)).scene_file_path == OTHER.resource_path, "changes in the game's grid redraw")
	board.free()


func test_a_saved_scene_with_a_layout_and_old_shape_values_loads_the_layout() -> void:
	var layout := GridLayout.from_grid(SquareGrid.rect(3, 2, true))
	layout.set_value(Vector2i(2, 1), &"terrain", &"water")
	var board := GridBoard.new()
	board.name = "Board"
	board.columns = 9
	board.rows = 9
	board.radius = 3
	board.shape = GridBoard.Shape.HEXAGONS
	board.layout = layout
	var packed := PackedScene.new()
	check(packed.pack(board) == OK, "the board packs")
	board.free()
	var path := "user://grid_kit_test_scene.tscn"
	check(ResourceSaver.save(packed, path) == OK, "and saves as a scene")
	var loaded := (
		(ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate() as GridBoard
	)
	check(loaded.columns == 9 and loaded.radius == 3, "the old values came back with it")
	check(loaded.cells().size() == 6 and loaded.grid is SquareGrid, "the grid is the layout's, not the rectangle")
	check(loaded.get_value(Vector2i(2, 1), &"terrain") == &"water", "with its values")
	loaded.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_board_queries() -> void:
	var board := build_board(1)
	check(board.direction_to(Vector2i.ZERO, board.neighbor(Vector2i.ZERO, 2)) == 2, "direction_to and neighbor")
	check(board.neighbors(Vector2i.ZERO, false).size() == 6, "neighbors off the board")
	check(board.outline().size() == 12, "outline")
	board.set_value(Vector2i(1, 0), &"start", 0)
	var start: Array[Vector2i] = [Vector2i(1, 0)]
	check(board.cells_with(&"start", 0) == start, "cells_with")
	check(board.center_cell() == Vector2i.ZERO, "center_cell")
	board.free()
