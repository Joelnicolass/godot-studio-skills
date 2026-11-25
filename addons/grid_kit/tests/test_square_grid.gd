extends "res://addons/grid_kit/tests/grid_test.gd"

## SquareGrid as pure data: shapes, neighbors (4 and 8, in a fixed order), distance, range, paths, flood, coordinates
## and to_dict.


func test_shapes() -> void:
	var rect := SquareGrid.rect(4, 3)
	check(rect.size() == 12, "a 4 x 3 rectangle has 12 cells: %d" % rect.size())
	check(rect.has_cell(Vector2i(3, 2)) and not rect.has_cell(Vector2i(4, 0)), "rectangle bounds")
	check(rect.shape_name() == &"square" and not rect.diagonals, "squares, no diagonals by default")
	var cells := rect.cells()
	check(cells[0] == Vector2i(0, 0) and cells[1] == Vector2i(1, 0) and cells[4] == Vector2i(0, 1), "row, then column")
	check(SquareGrid.rect(2, 2, true).diagonals, "rect can turn diagonals on")
	var diamond := SquareGrid.disc(2)
	check(diamond.size() == 13, "a diamond of radius 2 has 13 cells: %d" % diamond.size())
	check(diamond.has_cell(Vector2i(-2, 0)) and not diamond.has_cell(Vector2i(2, 2)), "diamond cells")
	check(SquareGrid.disc(2, true).size() == 25, "with diagonals the disc is a 5 x 5 square")


func test_neighbors_without_diagonals() -> void:
	var grid := SquareGrid.rect(5, 5)
	var inner := grid.neighbors(Vector2i(2, 2))
	var expected: Array[Vector2i] = [Vector2i(3, 2), Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 3)]
	check(inner == expected, "east, north, west, south: %s" % [inner])
	var corner := grid.neighbors(Vector2i(0, 0))
	var expected_corner: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
	check(corner == expected_corner, "a corner keeps only board cells: %s" % [corner])


func test_neighbors_with_diagonals() -> void:
	var grid := SquareGrid.rect(5, 5, true)
	var inner := grid.neighbors(Vector2i(2, 2))
	var expected: Array[Vector2i] = [
		Vector2i(3, 2),
		Vector2i(2, 1),
		Vector2i(1, 2),
		Vector2i(2, 3),
		Vector2i(3, 1),
		Vector2i(1, 1),
		Vector2i(1, 3),
		Vector2i(3, 3),
	]
	check(inner == expected, "then NE, NW, SW, SE: %s" % [inner])
	check(grid.neighbors(Vector2i(0, 0)).size() == 3, "a corner has 3 with diagonals")


func test_distance_and_range() -> void:
	var flat := SquareGrid.rect(9, 9)
	check(flat.distance(Vector2i(1, 1), Vector2i(1, 1)) == 0, "distance to itself")
	check(flat.distance(Vector2i(0, 0), Vector2i(3, 4)) == 7, "Manhattan without diagonals")
	check(flat.distance(Vector2i(3, 4), Vector2i(0, 0)) == 7, "distance is symmetric")
	var round_board := SquareGrid.rect(9, 9, true)
	check(round_board.distance(Vector2i(0, 0), Vector2i(3, 4)) == 4, "Chebyshev with diagonals")
	check(flat.cells_in_range(Vector2i(4, 4), 2).size() == 13, "range 2 without diagonals: a diamond of 13")
	check(round_board.cells_in_range(Vector2i(4, 4), 2).size() == 25, "range 2 with diagonals: a square of 25")
	check(flat.cells_in_range(Vector2i(0, 0), 2).size() == 6, "range stops at the board edge")
	var near := flat.cells_in_range(Vector2i(4, 4), 1)
	var expected: Array[Vector2i] = [Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4), Vector2i(4, 5)]
	check(near == expected, "range is sorted by row then column: %s" % [near])


func test_find_path() -> void:
	var grid := SquareGrid.rect(6, 6)
	var path := grid.find_path(Vector2i(0, 0), Vector2i(5, 0))
	check(path.size() == 6 and path[0] == Vector2i(0, 0) and path[-1] == Vector2i(5, 0), "straight path: %s" % [path])
	var corner := grid.find_path(Vector2i(0, 0), Vector2i(3, 3))
	check(corner.size() == 7, "no diagonals: 6 steps to (3, 3): %d cells" % corner.size())
	var diagonal := SquareGrid.rect(6, 6, true)
	check(diagonal.find_path(Vector2i(0, 0), Vector2i(3, 3)).size() == 4, "with diagonals a diagonal step counts 1")
	for row in 5:
		grid.set_value(Vector2i(3, row), &"terrain", &"sea")
	var land := func(_from: Vector2i, to: Vector2i) -> float:
		return INF if grid.get_value(to, &"terrain") == &"sea" else 1.0
	var around := grid.find_path(Vector2i(0, 0), Vector2i(5, 0), land)
	check(not around.is_empty() and not around.has(Vector2i(3, 2)), "the path goes around the sea")
	check(around.has(Vector2i(3, 5)), "through the only gap at row 5: %s" % [around])
	grid.set_value(Vector2i(3, 5), &"terrain", &"sea")
	check(grid.find_path(Vector2i(0, 0), Vector2i(5, 0), land).is_empty(), "no path when the wall is closed")
	var first := grid.find_path(Vector2i(0, 0), Vector2i(2, 4))
	check(not first.is_empty() and first == grid.find_path(Vector2i(0, 0), Vector2i(2, 4)), "the same path every time")
	check(grid.find_path(Vector2i(0, 0), Vector2i(9, 9)).is_empty(), "a target off the board: empty")


func test_find_path_with_costs_and_diagonals() -> void:
	var grid := SquareGrid.rect(4, 3, true)
	var swamp := func(_from: Vector2i, to: Vector2i) -> float: return 5.0 if to == Vector2i(1, 1) else 1.0
	var path := grid.find_path(Vector2i(0, 1), Vector2i(2, 1), swamp)
	check(not path.has(Vector2i(1, 1)), "a costly cell is walked around: %s" % [path])
	check(path.size() == 3, "using a diagonal step at the same cost: %s" % [path])
	var straight := grid.find_path(Vector2i(0, 1), Vector2i(3, 1))
	check(straight.size() == 4 and straight == grid.find_path(Vector2i(0, 1), Vector2i(3, 1)), "ties: the same path")


func test_flood() -> void:
	var grid := SquareGrid.rect(4, 2)
	grid.set_value(Vector2i(2, 0), &"terrain", &"sea")
	grid.set_value(Vector2i(2, 1), &"terrain", &"sea")
	var land := func(cell: Vector2i) -> bool: return grid.get_value(cell, &"terrain") != &"sea"
	var area := grid.flood(Vector2i(0, 0), land)
	var expected: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	check(area == expected, "flood stops at the sea: %s" % [area])
	check(grid.flood(Vector2i(2, 0), land).is_empty(), "a start that is not accepted gives nothing")
	var diagonal := SquareGrid.rect(2, 2, true)
	diagonal.set_value(Vector2i(1, 0), &"terrain", &"sea")
	diagonal.set_value(Vector2i(0, 1), &"terrain", &"sea")
	var dry := func(cell: Vector2i) -> bool: return diagonal.get_value(cell, &"terrain") != &"sea"
	check(diagonal.flood(Vector2i(0, 0), dry).size() == 2, "with diagonals flood crosses a corner")


func test_local_round_trip() -> void:
	var grid := SquareGrid.rect(6, 6)
	check(grid.cell_to_local(Vector2i(2, 3), 2.0) == Vector2(4.0, 6.0), "a cell sits at column * size, row * size")
	var ok := true
	for row in range(-4, 5):
		for column in range(-4, 5):
			var cell := Vector2i(column, row)
			var center := grid.cell_to_local(cell, 1.5)
			ok = ok and grid.local_to_cell(center, 1.5) == cell
			ok = ok and grid.local_to_cell(center + Vector2(0.7, -0.7), 1.5) == cell
	check(ok, "a point near a cell center maps back to that cell, negatives included")
	check(grid.local_to_cell(Vector2(0.49, 0.49), 1.0) == Vector2i(0, 0), "the edge belongs to the cell: inside")
	check(grid.local_to_cell(Vector2(0.51, -0.51), 1.0) == Vector2i(1, -1), "the edge belongs to the cell: outside")
	check(grid.local_to_cell(Vector2(-0.49, -0.49), 1.0) == Vector2i(0, 0), "negative side of the origin cell")


func test_outline() -> void:
	var corners := SquareGrid.new().cell_outline(2.0)
	check(corners.size() == 4, "a square has 4 corners")
	check(corners[0] == Vector2(-1, -1) and corners[2] == Vector2(1, 1), "corners around the center")


func test_to_dict() -> void:
	var grid := SquareGrid.rect(3, 2, true)
	grid.set_value(Vector2i(1, 0), &"terrain", &"mountain")
	var data := grid.to_dict()
	check(data["shape"] == "square" and data["diagonals"] == true, "the shape and the diagonals are written")
	var copy := CellGrid.from_dict(data)
	check(copy is SquareGrid and (copy as SquareGrid).diagonals, "from_dict gives a SquareGrid with diagonals")
	check(copy.get_value(Vector2i(1, 0), &"terrain") == &"mountain", "values survive")
	check(copy.to_dict() == data, "to_dict is stable")
	var plain := SquareGrid.rect(2, 2).to_dict()
	check(plain["diagonals"] == false and (CellGrid.from_dict(plain) as SquareGrid).diagonals == false, "no diagonals")
	var through_square := SquareGrid.from_dict(data)
	check(through_square is SquareGrid, "from_dict called on SquareGrid gives what the data says")


func test_directions() -> void:
	var grid := SquareGrid.rect(3, 3)
	check(grid.direction_count() == 4, "4 directions without diagonals")
	check(grid.direction_to(Vector2i(1, 1), Vector2i(2, 1)) == 0, "east is 0")
	check(grid.direction_to(Vector2i(1, 1), Vector2i(1, 2)) == 3, "south is 3")
	check(grid.direction_to(Vector2i(1, 1), Vector2i(2, 0)) == -1, "a diagonal without diagonals: -1")
	check(grid.neighbor(Vector2i(1, 1), 4) == CellGrid.NO_CELL, "no direction 4 without diagonals")
	grid.diagonals = true
	check(grid.direction_count() == 8, "8 with diagonals")
	check(grid.direction_to(Vector2i(1, 1), Vector2i(2, 0)) == 4, "north-east is 4")
	check(grid.direction_to(Vector2i(1, 1), Vector2i(2, 2)) == 7, "south-east is 7")
	check(grid.direction_to(Vector2i(0, 0), Vector2i(-1, 0)) == 2, "a cell off the board still has a direction")


func test_neighbors_off_the_board() -> void:
	var grid := SquareGrid.rect(2, 2)
	var all := grid.neighbors(Vector2i(0, 0), false)
	var expected: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1)]
	check(all == expected, "the four, in direction order: %s" % [all])
	grid.diagonals = true
	check(grid.neighbors(Vector2i(0, 0), false).size() == 8, "eight with diagonals")


func test_cells_around_the_board() -> void:
	var grid := SquareGrid.rect(3, 3)
	var ring := grid.outline()
	check(ring.size() == 16, "a 3 x 3 has 16 cells around it, corners included: %d" % ring.size())
	check(ring.has(Vector2i(-1, -1)) and ring.has(Vector2i(3, 3)), "the corners touch, even without diagonals")
	check(not ring.has(Vector2i(1, 1)), "no board cell")
	check(grid.outline(2).size() == 40, "two rings: 16 + 24 = %d" % grid.outline(2).size())


func test_cells_with_and_center() -> void:
	var grid := SquareGrid.rect(4, 4)
	grid.set_value(Vector2i(3, 0), &"start", &"red")
	grid.set_value(Vector2i(0, 3), &"start", &"blue")
	var red: Array[Vector2i] = [Vector2i(3, 0)]
	check(grid.cells_with(&"start", &"red") == red, "the cell with that value")
	check(SquareGrid.rect(3, 3).center_cell() == Vector2i(1, 1), "the middle of a 3 x 3")
	check(grid.center_cell() == Vector2i(1, 1), "a 4 x 4 has four in the middle: the first by row and column")
