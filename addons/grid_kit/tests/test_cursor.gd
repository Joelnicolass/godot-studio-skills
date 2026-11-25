extends "res://addons/grid_kit/tests/grid_test.gd"

## GridCursor: marks that move instead of being made again, shared mesh and material, shapes.

const TILE := preload("res://addons/grid_kit/examples/minimal_3d/tiles/plain.tscn")
const OTHER := preload("res://addons/grid_kit/examples/minimal_3d/tiles/water.tscn")


func test_cursor() -> void:
	var board := build_board(2)
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


func test_cells_added_and_removed_in_play() -> void:
	var board := build_board(1)
	var view := board.get_node(^"View") as GridView3D
	var cursor := board.get_node(^"View/Cursor") as GridCursor
	await tree.process_frame
	cursor.highlight([Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i])
	board.grid.add_cell(Vector2i(3, 0))
	await tree.process_frame
	check(view.tile_at(Vector2i(3, 0)) != null, "a cell added in play gets its tile")
	board.grid.remove_cell(Vector2i(1, 0))
	await tree.process_frame
	check(view.tile_at(Vector2i(1, 0)) == null, "a removed cell loses its tile")
	check(cursor.highlighted() == ([Vector2i(0, 0)] as Array[Vector2i]), "and its mark: %s" % [cursor.highlighted()])
	board.cell_size = 2.0
	var marker := cursor.get_child(cursor.get_child_count() - 1) as Node3D
	check(
		marker.position.is_equal_approx(board.cell_to_position(Vector2i(0, 0)) + Vector3.UP * cursor.lift),
		"marks follow a new cell_size"
	)
	board.free()


func _live_children(cursor: GridCursor) -> Array[int]:
	var ids: Array[int] = []
	for child in cursor.get_children():
		if not child.is_queued_for_deletion():
			ids.append(child.get_instance_id())
	ids.sort()
	return ids


func test_cursor_survives_a_thousand_rebuilds() -> void:
	var board := build_board(2)
	var cursor := board.get_node(^"View/Cursor") as GridCursor
	await tree.process_frame
	var seven := board.neighbors(Vector2i.ZERO)
	seven.append(Vector2i.ZERO)
	cursor.highlight(seven)
	var before := _live_children(cursor)
	check(before.size() == 7, "seven marks: %d" % before.size())
	for i in 1000:
		board.grid.add_cell(Vector2i(100 + i, 100))
	await tree.process_frame
	var after := _live_children(cursor)
	check(after == before, "the same seven marker nodes after 1000 add_cell")
	check(cursor.get_child_count() == 7, "and nothing waiting to be freed: %d children" % cursor.get_child_count())
	check(cursor.highlighted().size() == 7, "the same seven cells are marked")
	board.free()


func test_cursor_drops_only_the_marks_of_removed_cells() -> void:
	var board := build_board(2)
	var cursor := board.get_node(^"View/Cursor") as GridCursor
	await tree.process_frame
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	cursor.highlight(cells)
	var gone := cursor.get_child(cursor.highlighted().find(Vector2i(1, 0))) as Node3D
	var others: Array[int] = []
	for child in cursor.get_children():
		if child != gone:
			others.append(child.get_instance_id())
	board.grid.remove_cell(Vector2i(1, 0))
	await tree.process_frame
	var remaining: Array[int] = []
	for child in cursor.get_children():
		remaining.append(child.get_instance_id())
	check(not cursor.highlighted().has(Vector2i(1, 0)) and cursor.highlighted().size() == 2, "that mark is gone")
	check(
		remaining.size() == 2 and remaining.all(func(id: int) -> bool: return others.has(id)),
		"the others are the same nodes"
	)
	board.free()


func test_cursor_moves_marks_when_cell_size_changes() -> void:
	var board := build_board(1)
	var cursor := board.get_node(^"View/Cursor") as GridCursor
	await tree.process_frame
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	cursor.highlight(cells)
	var before := _live_children(cursor)
	var mesh := (cursor.get_child(0) as MeshInstance3D).mesh
	var size_before := mesh.get_aabb().size.x
	board.cell_size = 2.0
	await tree.process_frame
	check(_live_children(cursor) == before, "the same nodes after cell_size changed")
	var second := cursor.get_child(cursor.highlighted().find(Vector2i(1, 0))) as Node3D
	check(second.position.is_equal_approx(Vector3(2, cursor.lift, 0)), "at their new places: %s" % [second.position])
	var marker := cursor.get_child(0) as MeshInstance3D
	check(marker.mesh == mesh, "they still share one mesh")
	check(is_equal_approx(marker.mesh.get_aabb().size.x, size_before * 2.0), "which grew with the cell")
	board.free()


func test_cursor_markers_share_one_mesh_and_material() -> void:
	var board := build_board(2)
	var cursor := board.get_node(^"View/Cursor") as GridCursor
	cursor.highlight(board.cells_in_range(Vector2i.ZERO, 2))
	var first := cursor.get_child(0) as MeshInstance3D
	var shared := true
	for child in cursor.get_children():
		var node := child as MeshInstance3D
		shared = shared and node.mesh == first.mesh and node.material_override == first.material_override
	check(shared and cursor.get_child_count() == 19, "19 marks, one mesh, one material")
	cursor.color = Color.RED
	check((first.material_override as StandardMaterial3D).albedo_color == Color.RED, "a new color reaches every mark")
	board.free()


func test_cursor_square_marker_and_shape_change() -> void:
	var board := build_square_board(3, 3)
	var cursor := board.get_node(^"View/Cursor") as GridCursor
	var cell: Array[Vector2i] = [Vector2i(1, 1)]
	cursor.highlight(cell)
	var marker := cursor.get_child(0) as MeshInstance3D
	var square_size := marker.mesh.get_aabb().size
	check(
		is_equal_approx(square_size.x, 0.9) and is_equal_approx(square_size.z, 0.9), "a square mark: %s" % [square_size]
	)
	check(marker.position.is_equal_approx(Vector3(1, cursor.lift, 1)), "on its square")
	board.shape = GridBoard.Shape.HEXAGONS
	await tree.process_frame
	check(cursor.get_child(0) == marker and cursor.highlighted() == cell, "a new shape keeps the mark")
	var hex_size := marker.mesh.get_aabb().size
	check(
		is_equal_approx(hex_size.x, 0.9) and hex_size.z > 0.9 * 1.1, "and its mesh is a pointy hex now: %s" % [hex_size]
	)
	board.free()


func test_cursor_with_own_marker_scene_moves_too() -> void:
	var board := build_board(1)
	var cursor := board.get_node(^"View/Cursor") as GridCursor
	cursor.marker = TILE
	var cells: Array[Vector2i] = [Vector2i(1, 0)]
	cursor.highlight(cells)
	var node := cursor.get_child(0)
	board.cell_size = 2.0
	await tree.process_frame
	check(
		cursor.get_child(0) == node and (node as Node3D).position.is_equal_approx(Vector3(2, cursor.lift, 0)), "moved"
	)
	board.free()
