extends "res://addons/grid_kit/tests/grid_test.gd"

## Heights per cell (`GridBoard.height_key` and `height_scale`): where the board puts a cell, tiles and marks that move
## instead of being made again, and picking on columns (a tall cell hides the low one behind it).

const KEY := &"height"


func _hexes() -> GridBoard:
	var board := build_board(3)
	board.height_key = KEY
	return board


func _squares() -> GridBoard:
	var board := build_square_board(5, 5)
	board.height_key = KEY
	return board


func _view(board: GridBoard) -> GridView3D:
	return board.get_node(^"View") as GridView3D


# A ray in world space that comes down at 45° toward `target` (a point of the view's local space), from the side of
# `toward` (another local point): [origin, direction].
func _ray(view: GridView3D, target: Vector3, toward: Vector3) -> Array[Vector3]:
	var side := Vector3(toward.x - target.x, 0.0, toward.z - target.z).normalized()
	var from := target + side * 6.0 + Vector3.UP * 6.0
	var origin := view.to_global(from)
	return [origin, (view.to_global(target) - origin).normalized()]


func _pick(view: GridView3D, target: Vector3, toward: Vector3, on_board_only := true) -> Vector2i:
	var ray := _ray(view, target, toward)
	return view.cell_at_ray(ray[0], ray[1], on_board_only)


func _flat(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z)


func test_cell_to_position_without_a_height_key() -> void:
	var board := build_board(2)
	board.set_value(Vector2i(1, 0), KEY, 3)
	check(board.height_key == &"" and board.height_scale == 1.0, "the defaults: no key, scale 1")
	check(board.cell_to_position(Vector2i(1, 0)) == Vector3(1.0, 0.0, 0.0), "no height_key: the board is flat")
	check(board.cell_height(Vector2i(1, 0)) == 0.0, "and cell_height is 0")
	board.free()


func test_cell_to_position_with_int_and_float_heights() -> void:
	var board := _hexes()
	board.set_value(Vector2i(1, 0), KEY, 2)
	board.set_value(Vector2i(-1, 0), KEY, 1.5)
	check(board.cell_to_position(Vector2i(1, 0)) == Vector3(1.0, 2.0, 0.0), "an int height is the cell's Y")
	check(board.cell_to_position(Vector2i(-1, 0)) == Vector3(-1.0, 1.5, 0.0), "so is a float one")
	check(board.cell_to_position(Vector2i(0, 0)) == Vector3.ZERO, "a cell with no height is at 0")
	check(board.cell_to_position(Vector2i(9, 0)).y == 0.0, "and so is a cell off the board")
	board.height_scale = 0.5
	check(board.cell_to_position(Vector2i(1, 0)).y == 1.0, "height_scale multiplies: 2 × 0.5")
	check(is_equal_approx(board.cell_height(Vector2i(-1, 0)), 0.75), "cell_height is in world units: 1.5 × 0.5")
	board.free()


func test_a_height_that_is_not_a_number_counts_as_zero() -> void:
	var board := _hexes()
	board.set_value(Vector2i(1, 0), KEY, &"tall")
	board.set_value(Vector2i(0, 0), KEY, true)
	check(board.cell_height(Vector2i(1, 0)) == 0.0, "text is not a height")
	check(board.cell_height(Vector2i(0, 0)) == 0.0, "nor is a bool")
	check(board._height_warned, "and the board said so once")
	board.free()


func test_positions_ignore_height() -> void:
	var board := _hexes()
	board.set_value(Vector2i(1, 0), KEY, 4)
	var top := board.cell_to_position(Vector2i(1, 0))
	check(board.position_to_cell(top) == Vector2i(1, 0), "the top of a cell is that cell")
	check(board.position_to_cell(_flat(top)) == Vector2i(1, 0), "and so is the ground under it")
	check(board.position_to_cell(top + Vector3.UP * 50.0) == Vector2i(1, 0), "and any point over it")
	check(board.position_to_any_cell(Vector3(9.0, 7.0, 0.0)) == Vector2i(9, 0), "off the board too")
	board.free()


func test_a_height_change_moves_the_tile_and_the_mark() -> void:
	var board := _hexes()
	var view := _view(board)
	var cursor := view.get_node(^"Cursor") as GridCursor
	await tree.process_frame
	var cell := Vector2i(1, 0)
	cursor.highlight([cell, Vector2i(0, 0)] as Array[Vector2i])
	var tile := view.tile_at(cell)
	var made: Array[Vector2i] = []
	view.tile_created.connect(func(at: Vector2i, _tile: Node3D) -> void: made.append(at))
	var marks := cursor.get_children()
	board.set_value(cell, KEY, 2)
	check(view.tile_at(cell) == tile and made.is_empty(), "the same tile, not a new one")
	check(tile.position == Vector3(1.0, 2.0, 0.0), "moved up at once: %s" % tile.position)
	check(cursor.get_children() == marks, "the same marks")
	var mark := marks[0] as Node3D
	check(is_equal_approx(mark.position.y, 2.0 + cursor.lift), "the mark of that cell went up: %s" % mark.position)
	check(is_equal_approx((marks[1] as Node3D).position.y, cursor.lift), "the other one did not")
	board.paint(KEY, {cell: 0.5})
	check(tile.position.y == 0.5, "paint moves it too")
	board.grid.erase_value(cell, KEY)
	check(tile.position.y == 0.0 and is_equal_approx(mark.position.y, cursor.lift), "no height: back to the ground")
	board.set_value(cell, &"terrain", &"water")
	check(view.tile_at(cell) != tile, "(another terrain still makes another tile)")
	board.set_value(cell, KEY, 1)
	check(view.tile_at(cell).position.y == 1.0, "and the new tile follows the height")
	board.free()


func test_a_new_tile_is_born_at_its_height() -> void:
	var board := _hexes()
	var view := _view(board)
	board.set_value(Vector2i(1, 0), KEY, 2)
	var seen: Dictionary[Vector2i, float] = {}
	view.tile_created.connect(func(cell: Vector2i, tile: Node3D) -> void: seen[cell] = tile.position.y)
	await tree.process_frame
	check(seen.get(Vector2i(1, 0)) == 2.0, "tile_created hands the tile over at its height")
	check(seen.get(Vector2i(0, 0)) == 0.0, "and a cell with no height on the ground")
	board.free()


func test_height_scale_and_height_key_move_everything() -> void:
	var board := _hexes()
	var view := _view(board)
	var cursor := view.get_node(^"Cursor") as GridCursor
	board.set_value(Vector2i(1, 0), KEY, 2)
	board.set_value(Vector2i(0, 1), KEY, 1)
	board.set_value(Vector2i(0, 1), &"floor", 5)
	await tree.process_frame
	cursor.highlight([Vector2i(1, 0)] as Array[Vector2i])
	var tile := view.tile_at(Vector2i(1, 0))
	var other := view.tile_at(Vector2i(0, 1))
	var mark := cursor.get_child(0) as Node3D
	var rebuilds: Array[int] = [0]
	board.rebuilt.connect(func() -> void: rebuilds[0] += 1)
	board.height_scale = 3.0
	check(rebuilds[0] == 1, "height_scale tells the views, as cell_size does")
	await tree.process_frame
	check(view.tile_at(Vector2i(1, 0)) == tile and view.tile_at(Vector2i(0, 1)) == other, "the same tiles")
	check(tile.position.y == 6.0 and other.position.y == 3.0, "every tile at its new height")
	check(cursor.get_child(0) == mark and is_equal_approx(mark.position.y, 6.0 + cursor.lift), "and the mark")
	board.height_key = &"floor"
	await tree.process_frame
	check(tile.position.y == 0.0 and other.position.y == 15.0, "another height_key: the heights of that key")
	board.height_key = &""
	await tree.process_frame
	check(tile.position.y == 0.0 and other.position.y == 0.0, "no height_key: flat again")
	check(view.tile_at(Vector2i(0, 1)) == other, "still the same tiles")
	board.height_scale = 3.0
	check(rebuilds[0] == 3, "setting the same value again rebuilds nothing: %d" % rebuilds[0])
	board.free()


func test_a_layout_with_heights_shows_them() -> void:
	var grid := HexGrid.hexagon(2)
	grid.set_value(Vector2i(1, 0), KEY, 2)
	var board := GridBoard.new()
	board._in_editor = true
	board.layout = GridLayout.from_grid(grid)
	board.height_key = KEY
	add_view(board)
	tree.root.add_child(board)
	var view := _view(board)
	await tree.process_frame
	check(view.tile_at(Vector2i(1, 0)).position.y == 2.0, "the preview of a layout stands at its heights")
	board.layout.set_value(Vector2i(0, 0), KEY, 1.5)
	await tree.process_frame
	await tree.process_frame
	check(view.tile_at(Vector2i(0, 0)).position.y == 1.5, "and follows the layout when it changes in the editor")
	board.free()


# `tall` stands between the eye and `low`: the pick is `tall`. From the other side `low` is in the open.
func _check_hiding(board: GridBoard, tall: Vector2i, low: Vector2i, label: String) -> void:
	var view := _view(board)
	board.set_value(tall, KEY, 3)
	var tall_top := board.cell_to_position(tall)
	var low_top := board.cell_to_position(low)
	check(
		_pick(view, low_top, tall_top) == tall, "%s: aiming at a low cell through a tall one picks the tall one" % label
	)
	check(_pick(view, low_top, low_top * 2.0 - tall_top) == low, "%s: from the open side it picks the low one" % label)
	check(_pick(view, tall_top, low_top) == tall, "%s: the top of the tall one, over the low one" % label)
	check(_pick(view, tall_top, tall_top * 2.0 - _flat(low_top)) == tall, "%s: and from behind it" % label)
	check(view.cell_at_ray(view.to_global(low_top + Vector3.UP * 9.0), -view.global_basis.y) == low, "%s: down" % label)
	check(
		view.cell_at_ray(view.to_global(tall_top + Vector3.UP * 9.0), -view.global_basis.y) == tall,
		"%s: straight down on the tall one" % label
	)
	# On the flat plane the same ray lands on another cell: this is what heights fix.
	var ray := _ray(view, tall_top, low_top)
	board.height_key = &""
	check(view.cell_at_ray(ray[0], ray[1]) != tall, "%s: (without heights that ray lands past it)" % label)
	board.height_key = KEY


func test_picking_hexes() -> void:
	var board := _hexes()
	await tree.process_frame
	_check_hiding(board, Vector2i(0, 0), Vector2i(1, 0), "hex, east")
	_check_hiding(board, Vector2i(0, 0), Vector2i(-1, 1), "hex, south-west")
	board.free()


func test_picking_squares() -> void:
	var board := _squares()
	await tree.process_frame
	_check_hiding(board, Vector2i(2, 2), Vector2i(2, 1), "square, north")
	_check_hiding(board, Vector2i(2, 2), Vector2i(3, 2), "square, east")
	board.free()


func test_picking_on_a_view_that_is_moved_turned_and_scaled() -> void:
	var board := _hexes()
	var view := _view(board)
	view.position = Vector3(40.0, -3.0, 7.0)
	view.rotation = Vector3(0.3, 1.1, -0.2)
	view.scale = Vector3(2.0, 2.0, 2.0)
	await tree.process_frame
	_check_hiding(board, Vector2i(0, 0), Vector2i(1, 0), "moved view")
	board.free()


func test_picking_every_cell_of_a_rough_board() -> void:
	for board: GridBoard in [_hexes(), _squares()]:
		var view := _view(board)
		await tree.process_frame
		var cells := board.cells()
		for i in cells.size():
			board.set_value(cells[i], KEY, (i * 7) % 5 * 0.5 - 0.5)
		var missed: Array[Vector2i] = []
		for cell in cells:
			var top := board.cell_to_position(cell)
			if view.cell_at_ray(view.to_global(top + Vector3.UP * 20.0), Vector3.DOWN) != cell:
				missed.append(cell)
		check(missed.is_empty(), "%s: straight down finds every cell, pits included: %s" % [board.shape, missed])
		board.free()


func test_picking_off_the_board() -> void:
	var board := _squares()
	var view := _view(board)
	await tree.process_frame
	var edge := Vector2i(4, 2)
	var beside := Vector2i(5, 2)
	board.set_value(edge, KEY, 3)
	var edge_top := board.cell_to_position(edge)
	var ground := _flat(board.cell_to_position(beside))
	var open_side := ground * 2.0 - _flat(edge_top)
	check(_pick(view, ground, open_side, false) == beside, "a cell beside the board is picked on the ground (height 0)")
	check(_pick(view, ground, open_side) == CellGrid.NO_CELL, "and is no cell with on_board_only")
	check(_pick(view, ground, edge_top, false) == edge, "the tall cell on the edge hides it")
	var far := Vector3(60.0, 0.0, 2.0)
	check(_pick(view, far, far + Vector3.RIGHT, false) == Vector2i(60, 2), "far from the board: the ground plane")
	check(view.cell_at_ray(view.to_global(Vector3(2, 9, 2)), Vector3.UP) == CellGrid.NO_CELL, "a ray going away: none")
	board.free()


func test_picking_follows_changes() -> void:
	var board := _hexes()
	var view := _view(board)
	await tree.process_frame
	var tall := Vector2i(0, 0)
	var low := Vector2i(1, 0)
	var low_top := board.cell_to_position(low)
	var toward := board.cell_to_position(tall)
	check(_pick(view, low_top, toward) == low, "flat so far: the low cell")
	board.set_value(tall, KEY, 3)
	check(_pick(view, low_top, toward) == tall, "a cell raised after the first pick hides it")
	board.set_value(tall, KEY, 0)
	check(_pick(view, low_top, toward) == low, "lowered again: in the open")
	board.set_value(tall, KEY, 1)
	board.height_scale = 3.0
	check(_pick(view, low_top, toward) == tall, "height_scale counts")
	board.grid.remove_cell(tall)
	check(_pick(view, low_top, toward) == low, "a removed cell hides nothing")
	board.free()


func test_cell_at_screen_and_hover_on_a_tall_cell() -> void:
	var board := _hexes()
	var view := _view(board)
	var eye := Camera3D.new()
	tree.root.add_child(eye)
	eye.position = Vector3(0.0, 6.0, 8.0)
	eye.look_at(Vector3.ZERO)
	eye.current = true
	view.camera = eye
	await tree.process_frame
	var tall := Vector2i(0, 1)
	board.set_value(tall, KEY, 3)
	var screen := eye.unproject_position(board.cell_to_position(tall))
	check(view.cell_at_screen(screen) == tall, "the screen point of a tall cell's top is that cell")
	var hovered: Array[Vector2i] = []
	view.cell_hovered.connect(func(cell: Vector2i) -> void: hovered.append(cell))
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	view._unhandled_input(motion)
	check(hovered == ([tall] as Array[Vector2i]), "and hover reports it: %s" % [hovered])
	board.height_key = &""
	check(view.cell_at_screen(screen) != tall, "(on a flat board that point is another cell)")
	eye.free()
	board.free()


func test_nothing_changes_without_a_height_key() -> void:
	var board := build_board(3)
	var view := _view(board)
	var cursor := view.get_node(^"Cursor") as GridCursor
	await tree.process_frame
	var cell := Vector2i(1, 0)
	cursor.highlight([cell] as Array[Vector2i])
	var tile := view.tile_at(cell)
	board.set_value(cell, KEY, 5)
	board.height_scale = 2.0
	await tree.process_frame
	check(view.tile_at(cell) == tile and tile.position == Vector3(1.0, 0.0, 0.0), "the tile stays on the plane")
	check(is_equal_approx((cursor.get_child(0) as Node3D).position.y, cursor.lift), "and the mark")
	var low_top := board.cell_to_position(Vector2i(2, 0))
	check(_pick(view, low_top, board.cell_to_position(cell)) == Vector2i(2, 0), "picking is the plane's")
	check(view._height_pick._dirty, "and the board was never measured for heights")
	board.free()
