extends "res://addons/grid_kit/tests/grid_test.gd"

## The examples play as a person would: the board is drawn, a click lights the neighborhood, hover follows.


func test_minimal_3d_runs() -> void:
	var scene := (load("res://addons/grid_kit/examples/minimal_3d/minimal_3d.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	var board := scene.get_node(^"Board") as GridBoard
	var view := scene.get_node(^"Board/View") as GridView3D
	var selection := scene.get_node(^"Board/View/Selection") as GridCursor
	var hover := scene.get_node(^"Board/View/Hover") as GridCursor
	check(board.layout != null, "the map is a saved layout")
	check(board.cells().size() == 61, "a hexagon of radius 4: %d cells" % board.cells().size())
	check(view.tile_at(Vector2i.ZERO) != null, "every cell has a tile")
	check(board.get_value(Vector2i(4, 0), &"terrain") == &"water", "water on the rim")
	var rim_tile := view.tile_at(Vector2i(4, 0))
	check(rim_tile != null and rim_tile.scene_file_path.ends_with("water.tscn"), "the rim draws the water tile")
	var camera := scene.get_node(^"Camera") as Camera3D
	var screen := camera.unproject_position(board.cell_to_position(Vector2i(1, 1)))
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	view._unhandled_input(motion)
	var expected_hover: Array[Vector2i] = [Vector2i(1, 1)]
	check(hover.highlighted() == expected_hover, "hover marks the cell under the pointer: %s" % [hover.highlighted()])
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen
	view._unhandled_input(press)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	view._unhandled_input(release)
	check(
		selection.highlighted().size() == 7,
		"a click lights the cell and its 6 neighbors: %d" % selection.highlighted().size()
	)
	check(board.layout.get_value(Vector2i(4, 0), &"terrain") == &"water", "the layout itself is not touched by playing")
	scene.queue_free()
	await tree.process_frame


func test_squares_3d_runs() -> void:
	var scene := (load("res://addons/grid_kit/examples/squares_3d/squares_3d.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	var board := scene.get_node(^"Board") as GridBoard
	var view := scene.get_node(^"Board/View") as GridView3D
	var reach := scene.get_node(^"Board/View/Reach") as GridCursor
	var route := scene.get_node(^"Board/View/Route") as GridCursor
	var camera := scene.get_node(^"Camera") as Camera3D
	check(board.grid is SquareGrid and board.cells().size() == 64, "an 8 x 8 board of squares")
	check(view.tile_at(Vector2i(0, 0)).scene_file_path.ends_with("light.tscn"), "a light tile at (0, 0)")
	check(view.tile_at(Vector2i(1, 0)).scene_file_path.ends_with("dark.tscn"), "a dark tile next to it")
	_click(view, camera.unproject_position(board.cell_to_position(Vector2i(3, 3))))
	check(reach.highlighted().size() == 13, "a click lights the cells within 2 steps: %d" % reach.highlighted().size())
	check(route.highlighted().is_empty(), "no path with only one click")
	_click(view, camera.unproject_position(board.cell_to_position(Vector2i(6, 5))))
	check(route.highlighted().size() == 6, "the second click draws the path: %d cells" % route.highlighted().size())
	check(route.highlighted().has(Vector2i(3, 3)) and route.highlighted().has(Vector2i(6, 5)), "from the first click")
	scene.queue_free()
	await tree.process_frame


func _click(view: GridView3D, at: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = at
	view._unhandled_input(press)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	view._unhandled_input(release)
