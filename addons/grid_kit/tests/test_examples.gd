extends "res://addons/grid_kit/tests/grid_test.gd"

## The minimal example plays as a person would: the board is drawn, a click lights the neighborhood, hover follows.


func test_minimal_3d_runs() -> void:
	var scene := (load("res://addons/grid_kit/examples/minimal_3d/minimal_3d.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	var board := scene.get_node(^"Board") as GridBoard
	var view := scene.get_node(^"Board/View") as GridView3D
	var selection := scene.get_node(^"Board/View/Selection") as GridCursor
	var hover := scene.get_node(^"Board/View/Hover") as GridCursor
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
	scene.queue_free()
	await tree.process_frame
