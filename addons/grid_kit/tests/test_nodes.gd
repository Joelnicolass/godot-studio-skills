extends "res://addons/grid_kit/tests/grid_test.gd"

## GridBoard, GridView3D and GridCursor in a tree: tiles per cell, redraw on change, picking and warnings.

const TILE := preload("res://addons/grid_kit/examples/minimal_3d/tiles/plain.tscn")
const OTHER := preload("res://addons/grid_kit/examples/minimal_3d/tiles/water.tscn")


func _build(radius: int) -> GridBoard:
	var board := GridBoard.new()
	board.radius = radius
	var view := GridView3D.new()
	view.name = "View"
	view.default_tile = TILE
	view.tiles = {&"water": OTHER}
	board.add_child(view)
	var cursor := GridCursor.new()
	cursor.name = "Cursor"
	view.add_child(cursor)
	tree.root.add_child(board)
	return board


func test_board_from_inspector() -> void:
	var board := _build(2)
	check(board.cells().size() == 19, "radius 2: 19 cells")
	board.radius = 0
	board.columns = 3
	board.rows = 2
	check(board.cells().size() == 6, "radius 0 uses columns x rows: %d" % board.cells().size())
	check(board._get_configuration_warnings().is_empty(), "no warnings with cells")
	board.free()


func test_view_draws_tiles() -> void:
	var board := _build(2)
	var view := board.get_node(^"View") as GridView3D
	await tree.process_frame
	check(view.tile_at(Vector2i.ZERO) != null, "a tile per cell")
	check(view.tile_at(Vector2i.ZERO).scene_file_path == TILE.resource_path, "no value: the default tile")
	var center := board.cell_to_position(Vector2i(1, 0))
	check(view.tile_at(Vector2i(1, 0)).position.is_equal_approx(center), "tiles sit on their cell center")
	board.set_value(Vector2i(1, 0), &"terrain", &"water")
	check(view.tile_at(Vector2i(1, 0)).scene_file_path == OTHER.resource_path, "a new value redraws that cell")
	board.free()


func test_use_external_grid() -> void:
	var board := _build(1)
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


func test_click_and_drag() -> void:
	var board := _build(3)
	var view := board.get_node(^"View") as GridView3D
	var eye := Camera3D.new()
	tree.root.add_child(eye)
	eye.position = Vector3(0, 10, 0.01)
	eye.look_at(Vector3.ZERO)
	eye.current = true
	view.camera = eye
	await tree.process_frame
	var clicked: Array[Vector2i] = []
	view.cell_clicked.connect(func(cell: Vector2i) -> void: clicked.append(cell))
	var target := Vector2i(1, 0)
	var screen := eye.unproject_position(board.cell_to_position(target))
	check(view.cell_at_screen(screen) == target, "picking maps the screen point to the cell")
	_click(view, screen, screen)
	check(clicked == [target], "a click emits cell_clicked: %s" % [clicked])
	_click(view, screen, screen + Vector2(40, 0))
	check(clicked.size() == 1, "a drag is not a click")
	view.input_enabled = false
	_click(view, screen, screen)
	check(clicked.size() == 1, "input_enabled off ignores clicks")
	var far := eye.unproject_position(Vector3(500, 0, 0))
	check(view.cell_at_screen(far) == HexGrid.NO_CELL, "off the board: NO_CELL")
	eye.free()
	board.free()


func test_cursor() -> void:
	var board := _build(2)
	var cursor := board.get_node(^"View/Cursor") as GridCursor
	var ring := board.neighbors(Vector2i.ZERO)
	cursor.highlight(ring)
	var sorted_ring := ring.duplicate()
	sorted_ring.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	check(cursor.highlighted() == sorted_ring, "the cursor marks the cells it gets, sorted")
	cursor.highlight([Vector2i.ZERO, Vector2i(9, 9)] as Array[Vector2i])
	var only: Array[Vector2i] = [Vector2i.ZERO]
	check(cursor.highlighted() == only, "a new highlight replaces the old one, off-board cells ignored")
	cursor.clear()
	check(cursor.highlighted().is_empty(), "clear removes every marker")
	board.free()


func test_warnings() -> void:
	var view := GridView3D.new()
	tree.root.add_child(view)
	check(view._get_configuration_warnings().size() == 2, "no board parent and no tiles: 2 warnings")
	var cursor := GridCursor.new()
	view.add_child(cursor)
	check(cursor._get_configuration_warnings().is_empty(), "a cursor under a view: no warning")
	view.free()


func _click(view: GridView3D, down: Vector2, up: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = down
	view._unhandled_input(press)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	release.position = up
	view._unhandled_input(release)
