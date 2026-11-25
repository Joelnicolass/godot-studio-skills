extends "res://addons/grid_kit/tests/grid_test.gd"

## GridView3D in a tree: tiles per cell, redraw on change, the tiles handed over, picking and warnings.

const TILE := preload("res://addons/grid_kit/examples/minimal_3d/tiles/plain.tscn")
const OTHER := preload("res://addons/grid_kit/examples/minimal_3d/tiles/water.tscn")


func test_view_draws_tiles() -> void:
	var board := build_board(2)
	var view := board.get_node(^"View") as GridView3D
	await tree.process_frame
	check(view.tile_at(Vector2i.ZERO) != null, "a tile per cell")
	check(view.tile_at(Vector2i.ZERO).scene_file_path == TILE.resource_path, "no value: the default tile")
	var center := board.cell_to_position(Vector2i(1, 0))
	check(view.tile_at(Vector2i(1, 0)).position.is_equal_approx(center), "tiles sit on their cell center")
	board.set_value(Vector2i(1, 0), &"terrain", &"water")
	check(view.tile_at(Vector2i(1, 0)).scene_file_path == OTHER.resource_path, "a new value redraws that cell")
	board.free()


func test_click_and_drag() -> void:
	var board := build_board(3)
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
	check(view.cell_at_screen(far) == CellGrid.NO_CELL, "off the board: NO_CELL")
	eye.free()
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


func test_view_cell_at_ray_and_squares() -> void:
	var board := build_square_board(4, 4)
	var view := board.get_node(^"View") as GridView3D
	await tree.process_frame
	check(view.tile_at(Vector2i(3, 3)).position.is_equal_approx(Vector3(3, 0, 3)), "square tiles sit on a square grid")
	var down := Vector3.DOWN
	check(view.cell_at_ray(Vector3(2, 5, 1), down) == Vector2i(2, 1), "a ray down meets the cell under it")
	check(view.cell_at_ray(Vector3(9, 5, 9), down) == CellGrid.NO_CELL, "off the board: NO_CELL")
	check(view.cell_at_ray(Vector3(9, 5, 9), down, false) == Vector2i(9, 9), "or the cell there, if asked")
	check(view.cell_at_ray(Vector3(0, 5, 0), Vector3.UP) == CellGrid.NO_CELL, "a ray away from the plane misses")
	check(view.cell_at_ray(Vector3(0, 5, 0), Vector3.RIGHT) == CellGrid.NO_CELL, "a parallel ray misses")
	view.position = Vector3(10, 1, 0)
	check(view.cell_at_ray(Vector3(11, 5, 2), down) == Vector2i(1, 2), "the view's transform counts")
	board.free()


func test_view_erase_redraws_with_default() -> void:
	var board := build_board(1)
	var view := board.get_node(^"View") as GridView3D
	await tree.process_frame
	board.set_value(Vector2i(0, 0), &"terrain", &"water")
	check(view.tile_at(Vector2i(0, 0)).scene_file_path == OTHER.resource_path, "water")
	board.grid.erase_value(Vector2i(0, 0), &"terrain")
	check(view.tile_at(Vector2i(0, 0)).scene_file_path == TILE.resource_path, "erased: the default tile again")
	board.grid.set_value(Vector2i(0, 0), &"other_key", 1)
	check(view.tile_at(Vector2i(0, 0)).scene_file_path == TILE.resource_path, "other keys leave the tile alone")
	board.free()


func test_view_keeps_tiles_when_cells_come_and_go() -> void:
	var board := build_board(1)
	var view := board.get_node(^"View") as GridView3D
	await tree.process_frame
	var kept := view.tile_at(Vector2i(1, 0))
	board.grid.add_cell(Vector2i(4, 0))
	await tree.process_frame
	check(view.tile_at(Vector2i(1, 0)) == kept, "a cell that stays keeps its tile node")
	check(view.tile_at(Vector2i(4, 0)) != null, "the new cell gets one")
	board.cell_size = 3.0
	await tree.process_frame
	check(
		view.tile_at(Vector2i(1, 0)) == kept and kept.position.is_equal_approx(board.cell_to_position(Vector2i(1, 0))),
		"cell_size moves the tiles, it does not remake them"
	)
	board.free()


func test_view_hands_over_each_tile() -> void:
	var board := build_board(1)
	var view := board.get_node(^"View") as GridView3D
	var created: Dictionary[Vector2i, Node3D] = {}
	var outside_tree: Array[bool] = []
	var on_center: Array[bool] = []
	var drawn: Array[int] = [0]
	view.tile_created.connect(
		func(cell: Vector2i, tile: Node3D) -> void:
			created[cell] = tile
			outside_tree.append(not tile.is_inside_tree())
			on_center.append(tile.position.is_equal_approx(board.cell_to_position(cell)))
	)
	view.drawn.connect(func() -> void: drawn[0] += 1)
	await tree.process_frame
	check(created.size() == board.cells().size(), "one tile_created per cell: %d" % created.size())
	check(not outside_tree.has(false), "a tile is handed over before it enters the tree")
	check(not on_center.has(false), "already on its cell's center")
	check(created.get(Vector2i(1, 0)) == view.tile_at(Vector2i(1, 0)), "the tile handed over is the one drawn there")
	check(drawn[0] == 1, "drawn once every tile is there: %d" % drawn[0])
	board.set_value(Vector2i(1, 0), &"terrain", &"water")
	check(created.get(Vector2i(1, 0)) == view.tile_at(Vector2i(1, 0)), "a value change hands over the new tile")
	check(drawn[0] == 1, "a value change alone is not drawn")
	board.set_cells([Vector2i(4, 0)], [])
	await tree.process_frame
	check(created.has(Vector2i(4, 0)) and drawn[0] == 2, "a new cell: its tile, then drawn: %d" % drawn[0])
	board.free()
