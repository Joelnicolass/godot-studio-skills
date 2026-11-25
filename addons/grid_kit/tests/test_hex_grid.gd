extends "res://addons/grid_kit/tests/grid_test.gd"

## HexGrid as pure data: shapes, coordinates, neighbors, distance, range, paths, flood and to_dict.


func test_shapes() -> void:
	var rect := HexGrid.rect(4, 3)
	check(rect.size() == 12, "a 4 x 3 rectangle has 12 cells: %d" % rect.size())
	check(rect.has_cell(Vector2i(3, 2)) and not rect.has_cell(Vector2i(4, 0)), "rectangle bounds")
	var hexagon := HexGrid.hexagon(4)
	check(hexagon.size() == 61, "a hexagon of radius 4 has 61 cells: %d" % hexagon.size())
	check(hexagon.has_cell(Vector2i.ZERO), "the hexagon is centered on (0, 0)")
	var cells := rect.cells()
	check(cells[0] == Vector2i(0, 0) and cells[1] == Vector2i(1, 0), "cells sorted by row then column")


func test_cube_round_trip() -> void:
	var ok := true
	for row in range(-5, 6):
		for column in range(-5, 6):
			var cell := Vector2i(column, row)
			ok = ok and HexGrid.from_cube(HexGrid.to_cube(cell)) == cell
	check(ok, "offset -> cube -> offset is the identity, negatives included")


func test_neighbors() -> void:
	var grid := HexGrid.rect(5, 5)
	var even := grid.neighbors(Vector2i(2, 2))
	check(even.size() == 6, "an inner cell has 6 neighbors: %d" % even.size())
	var expected_even: Array[Vector2i] = [
		Vector2i(3, 2), Vector2i(2, 1), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 3)
	]
	check(even == expected_even, "even row, fixed order: %s" % [even])
	var odd := grid.neighbors(Vector2i(2, 1))
	var expected_odd: Array[Vector2i] = [
		Vector2i(3, 1), Vector2i(3, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 2)
	]
	check(odd == expected_odd, "odd row is shifted right: %s" % [odd])
	check(grid.neighbors(Vector2i(0, 0)).size() == 2, "a corner keeps only board cells")


func test_distance_and_range() -> void:
	var grid := HexGrid.hexagon(4)
	check(grid.distance(Vector2i(0, 0), Vector2i(0, 0)) == 0, "distance to itself")
	check(grid.distance(Vector2i(2, 2), Vector2i(2, 1)) == 1, "a neighbor is 1 away")
	check(
		grid.distance(Vector2i(0, 0), Vector2i(3, 4)) == 5,
		"far cell: %d" % grid.distance(Vector2i(0, 0), Vector2i(3, 4))
	)
	check(grid.cells_in_range(Vector2i.ZERO, 1).size() == 7, "range 1 = the cell + 6")
	check(grid.cells_in_range(Vector2i.ZERO, 2).size() == 19, "range 2 = 19 cells")
	check(grid.cells_in_range(Vector2i.ZERO, 9).size() == 61, "range never leaves the board")


func test_values() -> void:
	var grid := HexGrid.rect(3, 3)
	var changes: Array = []
	grid.value_changed.connect(
		func(cell: Vector2i, key: StringName, value: Variant) -> void: changes.append([cell, key, value])
	)
	grid.set_value(Vector2i(1, 1), &"terrain", &"forest")
	check(grid.get_value(Vector2i(1, 1), &"terrain") == &"forest", "a value is stored by key")
	check(grid.get_value(Vector2i(0, 0), &"terrain", &"plain") == &"plain", "missing value returns the default")
	grid.set_value(Vector2i(1, 1), &"terrain", &"forest")
	check(changes.size() == 1, "setting the same value again does not emit: %d" % changes.size())
	check(grid.get_value(Vector2i(9, 9), &"terrain", 7) == 7, "a cell off the board returns the default")


func test_find_path() -> void:
	var grid := HexGrid.rect(6, 6)
	var path := grid.find_path(Vector2i(0, 0), Vector2i(5, 0))
	check(path.size() == 6 and path[0] == Vector2i(0, 0) and path[-1] == Vector2i(5, 0), "straight path: %s" % [path])
	for row in 5:
		grid.set_value(Vector2i(3, row), &"terrain", &"sea")
	var land := func(_from: Vector2i, to: Vector2i) -> float:
		return INF if grid.get_value(to, &"terrain") == &"sea" else 1.0
	var around := grid.find_path(Vector2i(0, 0), Vector2i(5, 0), land)
	check(not around.is_empty() and not around.has(Vector2i(3, 2)), "the path goes around the sea")
	check(around.has(Vector2i(3, 5)), "through the only gap at row 5: %s" % [around])
	grid.set_value(Vector2i(3, 5), &"terrain", &"sea")
	check(grid.find_path(Vector2i(0, 0), Vector2i(5, 0), land).is_empty(), "no path when the wall is closed")
	var again := grid.find_path(Vector2i(0, 0), Vector2i(2, 4))
	check(again == grid.find_path(Vector2i(0, 0), Vector2i(2, 4)), "the same path every time")
	check(grid.find_path(Vector2i(0, 0), Vector2i(9, 9)).is_empty(), "a target off the board: empty")


func test_flood() -> void:
	var grid := HexGrid.rect(4, 1)
	grid.set_value(Vector2i(2, 0), &"terrain", &"sea")
	var land := func(cell: Vector2i) -> bool: return grid.get_value(cell, &"terrain") != &"sea"
	var area := grid.flood(Vector2i(0, 0), land)
	var expected: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	check(area == expected, "flood stops at the sea: %s" % [area])
	check(grid.flood(Vector2i(2, 0), land).is_empty(), "a start that is not accepted gives nothing")


func test_local_round_trip() -> void:
	var ok := true
	var grid := HexGrid.hexagon(4)
	for cell in grid.cells():
		var center := grid.cell_to_local(cell, 1.5)
		ok = ok and grid.local_to_cell(center, 1.5) == cell
		ok = ok and grid.local_to_cell(center + Vector2(0.3, -0.2), 1.5) == cell
	check(ok, "a point near a cell center maps back to that cell")


func test_to_dict() -> void:
	var grid := HexGrid.hexagon(2)
	grid.set_value(Vector2i(1, 0), &"terrain", &"mountain")
	grid.set_value(Vector2i(-1, 1), &"owner", 2)
	var copy := CellGrid.from_dict(grid.to_dict())
	check(copy is HexGrid and copy.shape_name() == &"hex", "from_dict gives a HexGrid back")
	check(grid.to_dict()["shape"] == "hex", "the shape is written as a name")
	check(copy.size() == grid.size(), "same cells")
	check(copy.get_value(Vector2i(1, 0), &"terrain") == &"mountain", "values survive")
	check(copy.to_dict() == grid.to_dict(), "to_dict is stable")


func test_cells_changed() -> void:
	var grid := HexGrid.rect(2, 2)
	var count := [0]
	grid.cells_changed.connect(func() -> void: count[0] += 1)
	grid.add_cell(Vector2i(0, 0))
	check(count[0] == 0, "adding a cell that is there emits nothing")
	grid.add_cell(Vector2i(5, 5))
	check(count[0] == 1, "a new cell emits cells_changed")
	grid.remove_cell(Vector2i(9, 9))
	check(count[0] == 1, "removing a cell that is not there emits nothing")
	grid.remove_cell(Vector2i(5, 5))
	check(count[0] == 2 and not grid.has_cell(Vector2i(5, 5)), "removing one emits it")


func test_outline() -> void:
	var corners := HexGrid.new().cell_outline(1.0)
	check(corners.size() == 6, "a hex has 6 corners")
	var radius := 1.0 / HexGrid.SQRT3
	var ok := true
	for corner in corners:
		ok = ok and is_equal_approx(corner.length(), radius)
	check(ok, "every corner is one radius from the center")
	check(
		is_equal_approx(corners[0].x, 0.5) and is_equal_approx(corners[0].y, radius * 0.5), "pointy-top: first corner"
	)


func test_directions() -> void:
	var grid := HexGrid.hexagon(1)
	var center := Vector2i.ZERO
	check(grid.direction_count() == 6, "6 directions")
	var all_back := true
	for direction in 6:
		var next := grid.neighbor(center, direction)
		all_back = all_back and grid.direction_to(center, next) == direction
		all_back = all_back and next == HexGrid.from_cube(HexGrid.to_cube(center) + HexGrid.CUBE_DIRECTIONS[direction])
	check(all_back, "neighbor and direction_to follow CUBE_DIRECTIONS")
	check(grid.direction_to(center, Vector2i(2, 0)) == -1, "two steps away: -1")
	check(grid.direction_to(center, center) == -1, "the same cell: -1")
	check(
		grid.neighbor(center, 6) == CellGrid.NO_CELL and grid.neighbor(center, -1) == CellGrid.NO_CELL, "no direction 6"
	)
	var odd := Vector2i(3, 1)
	var odd_back := true
	for direction in 6:
		odd_back = odd_back and grid.direction_to(odd, grid.neighbor(odd, direction)) == direction
	check(odd_back, "an odd row off the board too")


func test_neighbors_off_the_board() -> void:
	var grid := HexGrid.rect(3, 3)
	var all := grid.neighbors(Vector2i(0, 0), false)
	check(all.size() == 6, "all six, on the board or not: %d" % all.size())
	var by_direction := true
	for direction in 6:
		by_direction = by_direction and all[direction] == grid.neighbor(Vector2i(0, 0), direction)
	check(by_direction, "the index is the direction")
	var on_board := grid.neighbors(Vector2i(0, 0))
	var kept: Array[Vector2i] = []
	for cell in all:
		if grid.has_cell(cell):
			kept.append(cell)
	check(on_board == kept, "on_board_only keeps the same order: %s" % [on_board])


func test_cells_around_the_board() -> void:
	var grid := HexGrid.hexagon(1)
	var ring := grid.outline()
	check(ring.size() == 12, "the ring around a radius 1 hexagon has 12 cells: %d" % ring.size())
	var all_at_two := true
	for cell in ring:
		all_at_two = all_at_two and not grid.has_cell(cell) and grid.distance(cell, Vector2i.ZERO) == 2
	check(all_at_two, "every one off the board, two steps from the middle")
	check(grid.outline(2).size() == 30, "two rings: 12 + 18 = %d" % grid.outline(2).size())
	check(grid.outline(0).is_empty(), "zero rings: none")
	var sorted := ring.duplicate()
	sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	check(ring == sorted, "sorted by row and then column")
	check(HexGrid.new().outline().is_empty(), "an empty board has no outline")


func test_cells_with() -> void:
	var grid := HexGrid.rect(3, 2)
	grid.set_value(Vector2i(2, 1), &"start", 1)
	grid.set_value(Vector2i(0, 0), &"start", 0)
	grid.set_value(Vector2i(1, 0), &"start", 1)
	grid.set_value(Vector2i(1, 1), &"terrain", &"forest")
	var seat_one := grid.cells_with(&"start", 1)
	var expected: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 1)]
	check(seat_one == expected, "the cells with that value, by row and column: %s" % [seat_one])
	check(grid.cells_with(&"start", 1.0) == expected, "an int and a float with the same number match")
	var forest: Array[Vector2i] = [Vector2i(1, 1)]
	check(grid.cells_with(&"terrain", "forest") == forest, "a String matches a StringName")
	check(grid.cells_with(&"terrain", 3).is_empty(), "another type does not match and does not fail")
	check(grid.cells_with(&"missing", null).is_empty(), "no cell has that key")


func test_center_cell() -> void:
	check(HexGrid.hexagon(2).center_cell() == Vector2i.ZERO, "the middle of a hexagon")
	var middle := HexGrid.rect(3, 3).center_cell()
	check(middle == Vector2i(1, 1), "the middle of a 3 x 3: %s" % middle)
	check(HexGrid.new().center_cell() == CellGrid.NO_CELL, "an empty board: NO_CELL")
