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
	check(HexGrid.distance(Vector2i(0, 0), Vector2i(0, 0)) == 0, "distance to itself")
	check(HexGrid.distance(Vector2i(2, 2), Vector2i(2, 1)) == 1, "a neighbor is 1 away")
	check(
		HexGrid.distance(Vector2i(0, 0), Vector2i(3, 4)) == 5,
		"far cell: %d" % HexGrid.distance(Vector2i(0, 0), Vector2i(3, 4))
	)
	var grid := HexGrid.hexagon(4)
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
	for cell in HexGrid.hexagon(4).cells():
		var center := HexGrid.cell_to_local(cell, 1.5)
		ok = ok and HexGrid.local_to_cell(center, 1.5) == cell
		ok = ok and HexGrid.local_to_cell(center + Vector2(0.3, -0.2), 1.5) == cell
	check(ok, "a point near a cell center maps back to that cell")


func test_to_dict() -> void:
	var grid := HexGrid.hexagon(2)
	grid.set_value(Vector2i(1, 0), &"terrain", &"mountain")
	grid.set_value(Vector2i(-1, 1), &"owner", 2)
	var copy := HexGrid.from_dict(grid.to_dict())
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
