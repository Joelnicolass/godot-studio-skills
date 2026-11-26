extends "res://addons/grid_kit/tests/grid_test.gd"

## CellFog (the three states per observer, the signals, saving) and GridFog (the fog drawn over the tiles).

const HIDDEN := CellFog.State.HIDDEN
const EXPLORED := CellFog.State.EXPLORED
const VISIBLE := CellFog.State.VISIBLE


func test_reveal_and_clear_visible() -> void:
	var fog := CellFog.new()
	var shown: Array = []
	fog.revealed.connect(func(observer: int, cells: Array[Vector2i]) -> void: shown.append([observer, cells]))
	check(fog.state(0, Vector2i(1, 1)) == HIDDEN, "a cell starts hidden")
	fog.reveal(0, [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 1)] as Array[Vector2i])
	check(fog.state(0, Vector2i(1, 1)) == VISIBLE and fog.sees(0, Vector2i(2, 1)), "revealed cells are visible")
	check(fog.state(1, Vector2i(1, 1)) == HIDDEN, "every observer has its own fog")
	check(shown.size() == 1 and (shown[0][1] as Array).size() == 2, "revealed once, each cell once: %s" % [shown])
	fog.reveal(0, [Vector2i(1, 1)] as Array[Vector2i])
	check(shown.size() == 1, "revealing what is visible already says nothing")
	var gone: Array = []
	fog.faded.connect(func(observer: int, cells: Array[Vector2i]) -> void: gone.append([observer, cells]))
	fog.clear_visible(0)
	check(fog.state(0, Vector2i(1, 1)) == EXPLORED and fog.knows(0, Vector2i(2, 1)), "visible cells become explored")
	check(not fog.sees(0, Vector2i(1, 1)), "and are not seen any more")
	var both: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1)]
	check(gone.size() == 1 and gone[0][0] == 0 and gone[0][1] == both, "faded says which, sorted: %s" % [gone])
	check(fog.visible_cells(0).is_empty() and fog.explored_cells(0) == both, "the lists follow")
	fog.clear_visible(0)
	check(gone.size() == 1, "clearing again says nothing")
	var learned: Array = []
	fog.explored.connect(func(_o: int, cells: Array[Vector2i]) -> void: learned.append(cells))
	fog.reveal(0, [Vector2i(3, 3)] as Array[Vector2i])
	fog.clear_visible(0)
	check(learned == [[Vector2i(3, 3)]], "what fades is explored too, and explored says so: %s" % [learned])


func test_see_keeps_only_what_is_seen() -> void:
	var fog := CellFog.new()
	fog.see(2, [Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i])
	var events: Array[String] = []
	fog.faded.connect(func(_o: int, cells: Array[Vector2i]) -> void: events.append("faded %s" % [cells]))
	fog.explored.connect(func(_o: int, cells: Array[Vector2i]) -> void: events.append("explored %s" % [cells]))
	fog.revealed.connect(func(_o: int, cells: Array[Vector2i]) -> void: events.append("revealed %s" % [cells]))
	fog.see(2, [Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i])
	check(fog.state(2, Vector2i(0, 0)) == EXPLORED, "what is not seen now is explored")
	check(fog.state(2, Vector2i(1, 0)) == VISIBLE and fog.state(2, Vector2i(2, 0)) == VISIBLE, "the rest is visible")
	check(
		events == (["faded [(0, 0)]", "explored [(0, 0)]", "revealed [(2, 0)]"] as Array[String]),
		"only the changes: faded, explored, revealed: %s" % [events]
	)


func test_explore_and_clear() -> void:
	var fog := CellFog.new()
	var learned: Array = []
	fog.explored.connect(func(_o: int, cells: Array[Vector2i]) -> void: learned.append(cells))
	fog.reveal(0, [Vector2i(0, 0)] as Array[Vector2i])
	fog.explore(0, [Vector2i(0, 0), Vector2i(5, 5)] as Array[Vector2i])
	check(fog.state(0, Vector2i(0, 0)) == VISIBLE, "exploring a visible cell leaves it visible")
	check(fog.state(0, Vector2i(5, 5)) == EXPLORED, "a hidden cell becomes explored without being seen")
	check(learned == [[Vector2i(5, 5)]], "explored lists only the hidden ones: %s" % [learned])
	fog.reveal(3, [Vector2i(1, 1)] as Array[Vector2i])
	check(fog.observers() == ([0, 3] as Array[int]), "observers are listed, sorted")
	var cleared: Array[int] = []
	fog.cleared.connect(func(observer: int) -> void: cleared.append(observer))
	fog.clear_observer(0)
	check(fog.state(0, Vector2i(5, 5)) == HIDDEN and fog.sees(3, Vector2i(1, 1)), "clear_observer(0) forgets 0 only")
	fog.clear()
	check(fog.observers().is_empty() and cleared == ([0, 3] as Array[int]), "clear() forgets everyone: %s" % [cleared])


func test_save_and_load() -> void:
	var fog := CellFog.new()
	fog.reveal(0, [Vector2i(-1, 2), Vector2i(3, 0)] as Array[Vector2i])
	fog.clear_visible(0)
	fog.reveal(0, [Vector2i(0, 0)] as Array[Vector2i])
	fog.explore(1, [Vector2i(4, 4)] as Array[Vector2i])
	var data := fog.to_dict()
	var back := CellFog.from_dict(JSON.parse_string(JSON.stringify(data)) as Dictionary)
	check(back.to_dict() == data, "a trip through JSON gives the same fog: %s" % [back.to_dict()])
	check(back.state(0, Vector2i(0, 0)) == VISIBLE and back.state(0, Vector2i(3, 0)) == EXPLORED, "states come back")
	check(back.state(1, Vector2i(4, 4)) == EXPLORED and back.state(1, Vector2i(0, 0)) == HIDDEN, "per observer")
	check(CellFog.from_dict({}).observers().is_empty(), "an empty dict is an empty fog")


func test_cells_near() -> void:
	var board := GridBoard.new()
	board.radius = 3
	var near := board.cells_near([Vector2i(-3, 0), Vector2i(3, 0)] as Array[Vector2i], 1)
	var expected := board.cells_in_range(Vector2i(-3, 0), 1)
	expected.append_array(board.cells_in_range(Vector2i(3, 0), 1))
	expected.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	check(near == expected, "the cells near two centers are both ranges, sorted: %s" % [near])
	var overlap := board.cells_near([Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i], 1)
	check(overlap.size() == 10, "a cell in both ranges counts once: %d" % overlap.size())
	check(board.cells_near([] as Array[Vector2i], 2).is_empty(), "no centers, no cells")
	board.free()


func test_the_fog_hides_and_darkens_tiles() -> void:
	var board := build_board(2)
	var view := board.get_node(^"View") as GridView3D
	var fog := GridFog.new()
	view.add_child(fog)
	await tree.process_frame
	await tree.process_frame
	var caps := fog.get_child(0, true) as MultiMeshInstance3D
	check(caps.multimesh.instance_count == board.cells().size(), "every cell starts under a cap")
	check(not view.tile_at(Vector2i.ZERO).visible, "and its tile is hidden")
	fog.see_around(0, [Vector2i.ZERO] as Array[Vector2i], 1)
	await tree.process_frame
	check(fog.visible_cells(0).size() == 7, "see_around: the cell and its 6 neighbors")
	check(view.tile_at(Vector2i.ZERO).visible, "a visible tile shows")
	check(caps.multimesh.instance_count == board.cells().size() - 7, "visible cells lose their cap")
	var mesh := view.tile_at(Vector2i.ZERO).get_child(0) as MeshInstance3D
	check(mesh.material_overlay == null, "a visible tile is not darkened")
	fog.see_around(0, [Vector2i(2, 0)] as Array[Vector2i], 0)
	await tree.process_frame
	check(fog.state(0, Vector2i.ZERO) == CellFog.State.EXPLORED, "moving away leaves it explored")
	check(view.tile_at(Vector2i.ZERO).visible and mesh.material_overlay != null, "an explored tile shows, darkened")
	fog.shown_observer = 1
	await tree.process_frame
	check(not view.tile_at(Vector2i.ZERO).visible and mesh.material_overlay == null, "observer 1 has seen nothing")
	fog.shown_observer = -1
	await tree.process_frame
	check(view.tile_at(Vector2i.ZERO).visible and caps.multimesh.instance_count == 0, "-1 shows the whole board")
	fog.shown_observer = 0
	await tree.process_frame
	view.remove_child(fog)
	check(view.tile_at(Vector2i.ZERO).visible and mesh.material_overlay == null, "taken out, it gives every tile back")
	fog.free()
	board.free()


func test_redrawn_tiles_get_the_fog_again() -> void:
	var board := build_board(1)
	var view := board.get_node(^"View") as GridView3D
	var fog := GridFog.new()
	view.add_child(fog)
	fog.reveal(0, [Vector2i.ZERO] as Array[Vector2i])
	await tree.process_frame
	await tree.process_frame
	board.set_value(Vector2i(1, 0), &"terrain", &"water")
	await tree.process_frame
	await tree.process_frame
	var tile := view.tile_at(Vector2i(1, 0))
	check(tile != null and tile.scene_file_path.ends_with("water.tscn"), "the cell got a new tile")
	check(not tile.visible, "the new tile of a hidden cell is hidden too")
	check(view.tile_at(Vector2i.ZERO).visible, "the visible one still shows")
	board.free()


func test_use_fog_of_the_rules() -> void:
	var board := build_board(1)
	var view := board.get_node(^"View") as GridView3D
	var fog := GridFog.new()
	view.add_child(fog)
	var rules := CellFog.new()
	rules.reveal(0, [Vector2i.ZERO] as Array[Vector2i])
	var rebuilt := [0]
	fog.rebuilt.connect(func() -> void: rebuilt[0] += 1)
	fog.use_fog(rules)
	check(fog.fog == rules and rebuilt[0] == 1, "it shows the rules' fog and says so")
	check(fog.sees(0, Vector2i.ZERO), "and answers from it")
	var heard: Array[Vector2i] = []
	fog.revealed.connect(func(_o: int, cells: Array[Vector2i]) -> void: heard.append_array(cells))
	rules.reveal(0, [Vector2i(1, 0)] as Array[Vector2i])
	check(heard == ([Vector2i(1, 0)] as Array[Vector2i]), "the rules' signals come through the node")
	await tree.process_frame
	check(view.tile_at(Vector2i(1, 0)).visible, "and redraw the fog")
	fog.use_own_fog()
	check(fog.fog != rules and not fog.knows(0, Vector2i.ZERO), "its own fog starts hidden")
	rules.reveal(0, [Vector2i(-1, 0)] as Array[Vector2i])
	check(heard.size() == 1, "the old fog is not heard any more")
	board.free()


func test_warnings() -> void:
	var fog := GridFog.new()
	check(fog._get_configuration_warnings().size() == 1, "a fog outside a view warns")
	var board := build_board(1)
	var view := board.get_node(^"View") as GridView3D
	view.add_child(fog)
	check(fog._get_configuration_warnings().is_empty(), "under a view it does not")
	board.free()


func test_signals_list_cells_sorted() -> void:
	var fog := CellFog.new()
	var heard: Array = []
	fog.revealed.connect(func(_o: int, cells: Array[Vector2i]) -> void: heard.append(cells))
	fog.explored.connect(func(_o: int, cells: Array[Vector2i]) -> void: heard.append(cells))
	fog.reveal(0, [Vector2i(2, 1), Vector2i(0, 1), Vector2i(5, 0)] as Array[Vector2i])
	fog.explore(0, [Vector2i(9, 9), Vector2i(1, 4)] as Array[Vector2i])
	var shown: Array[Vector2i] = [Vector2i(5, 0), Vector2i(0, 1), Vector2i(2, 1)]
	var learned: Array[Vector2i] = [Vector2i(1, 4), Vector2i(9, 9)]
	check(heard == [shown, learned], "revealed and explored come sorted by row and column: %s" % [heard])


func test_one_observer_at_a_time() -> void:
	var fog := CellFog.new()
	fog.reveal(0, [Vector2i(0, 0)] as Array[Vector2i])
	fog.reveal(1, [Vector2i(4, 4)] as Array[Vector2i])
	fog.clear_visible(1)
	var mine := fog.observer_to_dict(1)
	check(not str(mine).contains("0, 0"), "one observer's data has nothing of the others: %s" % [mine])
	var other := CellFog.new()
	other.reveal(1, [Vector2i(7, 7)] as Array[Vector2i])
	var heard: Array[String] = []
	other.cleared.connect(func(o: int) -> void: heard.append("cleared %d" % o))
	other.explored.connect(func(_o: int, cells: Array[Vector2i]) -> void: heard.append("explored %s" % [cells]))
	other.set_observer_from_dict(1, JSON.parse_string(JSON.stringify(mine)) as Dictionary)
	check(
		other.state(1, Vector2i(4, 4)) == EXPLORED and other.state(1, Vector2i(7, 7)) == HIDDEN, "replaced, not added"
	)
	check(heard == (["cleared 1", "explored [(4, 4)]"] as Array[String]), "and a view hears it: %s" % [heard])
	fog.reveal(-1, [Vector2i(0, 0)] as Array[Vector2i])
	check(fog.observers() == ([0, 1] as Array[int]), "a negative observer is refused")


func test_line_and_sight() -> void:
	var hexes := HexGrid.hexagon(4)
	var straight: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	check(
		hexes.line(Vector2i(0, 0), Vector2i(3, 0)) == straight,
		"a line along a row: %s" % [hexes.line(Vector2i(0, 0), Vector2i(3, 0))]
	)
	var diagonal := hexes.line(Vector2i(0, 0), Vector2i(-1, 3))
	check(diagonal.size() == hexes.distance(Vector2i(0, 0), Vector2i(-1, 3)) + 1, "one cell per step: %s" % [diagonal])
	for i in range(1, diagonal.size()):
		check(hexes.distance(diagonal[i - 1], diagonal[i]) == 1, "each cell touches the one before")
	check(hexes.line(Vector2i(2, 2), Vector2i(2, 2)) == ([Vector2i(2, 2)] as Array[Vector2i]), "a line to itself")
	var squares := SquareGrid.rect(6, 6)
	var across := squares.line(Vector2i(0, 0), Vector2i(4, 0))
	check(across.size() == 5 and across.back() == Vector2i(4, 0), "on squares too: %s" % [across])
	var wall := func(cell: Vector2i) -> bool: return cell == Vector2i(1, 0)
	var seen := hexes.cells_visible_from(Vector2i(0, 0), 3, wall)
	check(seen.has(Vector2i(1, 0)), "the blocking cell is seen")
	check(not seen.has(Vector2i(2, 0)) and not seen.has(Vector2i(3, 0)), "what is behind it is not")
	check(seen.has(Vector2i(-1, 0)) and seen.has(Vector2i(0, 2)), "the other sides are")
	check(
		hexes.cells_visible_from(Vector2i(0, 0), 2) == hexes.cells_in_range(Vector2i(0, 0), 2), "no blocks: the range"
	)


func test_see_around_with_blocks() -> void:
	var board := build_board(3)
	var view := board.get_node(^"View") as GridView3D
	var fog := GridFog.new()
	view.add_child(fog)
	board.set_value(Vector2i(1, 0), &"terrain", &"water")
	var water := func(cell: Vector2i) -> bool: return board.get_value(cell, &"terrain") == &"water"
	fog.see_around(0, [Vector2i.ZERO] as Array[Vector2i], 3, water)
	check(fog.sees(0, Vector2i(1, 0)) and not fog.sees(0, Vector2i(2, 0)), "water blocks the view behind it")
	fog.see_around(0, [Vector2i.ZERO, Vector2i(3, 0)] as Array[Vector2i], 3, water)
	check(fog.sees(0, Vector2i(2, 0)), "another unit on the far side sees it")
	board.free()


func test_caps_lift_height_and_transparent() -> void:
	var board := build_board(1)
	board.height_key = &"height"
	board.set_value(Vector2i(1, 0), &"height", 2)
	var view := board.get_node(^"View") as GridView3D
	var fog := GridFog.new()
	fog.lift = 0.25
	view.add_child(fog)
	await tree.process_frame
	await tree.process_frame
	var caps := fog.get_child(0, true) as MultiMeshInstance3D
	var expected := board.cell_to_position(Vector2i(1, 0)) + Vector3.UP * 0.25
	check(expected.y > 2.0, "the cell stands at height 2")
	# The dummy renderer of a headless run keeps no MultiMesh transforms: the place each cap gets is read here.
	check(fog._cap_origin(Vector2i(1, 0)).is_equal_approx(expected), "a cap sits lift above its cell, at its height")
	check(caps.multimesh.instance_count == board.cells().size(), "every hidden cell has a cap")
	fog.hidden_color = Color(0, 0, 0, 0)
	await tree.process_frame
	check(caps.multimesh.instance_count == 0, "a transparent hidden_color draws no cap")
	check(not view.tile_at(Vector2i(1, 0)).visible, "but the tile stays hidden")
	board.free()


func test_a_tile_with_its_own_overlay_gets_it_back() -> void:
	var board := build_board(1)
	var view := board.get_node(^"View") as GridView3D
	await tree.process_frame
	var mesh := view.tile_at(Vector2i.ZERO).get_child(0) as MeshInstance3D
	var own := StandardMaterial3D.new()
	mesh.material_overlay = own
	var fog := GridFog.new()
	view.add_child(fog)
	fog.reveal(0, [Vector2i.ZERO] as Array[Vector2i])
	fog.clear_visible(0)
	await tree.process_frame
	check(mesh.material_overlay != own and mesh.material_overlay != null, "explored: the fog's veil is on")
	fog.reveal(0, [Vector2i.ZERO] as Array[Vector2i])
	await tree.process_frame
	check(mesh.material_overlay == own, "visible again: the tile's own overlay is back")
	board.free()


func test_fade_and_tile_shown() -> void:
	var board := build_board(1)
	var view := board.get_node(^"View") as GridView3D
	var fog := GridFog.new()
	fog.fade_time = 0.2
	view.add_child(fog)
	await tree.process_frame
	await tree.process_frame
	var shown: Array[Vector2i] = []
	fog.tile_shown.connect(
		func(cell: Vector2i, tile: Node3D) -> void:
			if tile.visible:
				shown.append(cell)
	)
	fog.reveal(0, [Vector2i.ZERO] as Array[Vector2i])
	await tree.process_frame
	var mesh := view.tile_at(Vector2i.ZERO).get_child(0) as MeshInstance3D
	check(shown == ([Vector2i.ZERO] as Array[Vector2i]), "tile_shown says which tile came out, already visible")
	var veil := mesh.material_overlay as StandardMaterial3D
	check(veil != null and veil.albedo_color.a > 0.0, "while it fades a veil is still on it")
	await tree.create_timer(0.35).timeout
	check(mesh.material_overlay == null, "after fade_time the veil is gone")
	fog.clear_visible(0)
	await tree.process_frame
	await tree.create_timer(0.35).timeout
	check(mesh.material_overlay != null, "fading out ends darkened")
	board.free()
