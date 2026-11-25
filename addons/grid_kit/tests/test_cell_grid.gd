extends "res://addons/grid_kit/tests/grid_test.gd"

## What every shape shares: values, cells_changed (one signal per batch), erase_value and from_dict.


func test_from_dict_picks_the_class() -> void:
	var hex := CellGrid.from_dict(HexGrid.rect(2, 2).to_dict())
	var square := CellGrid.from_dict(SquareGrid.rect(2, 2).to_dict())
	check(hex is HexGrid and not hex is SquareGrid, "a hex dict gives a HexGrid")
	check(square is SquareGrid and not square is HexGrid, "a square dict gives a SquareGrid")
	check(hex.size() == 4 and square.size() == 4, "with their cells")
	check(
		HexGrid.from_dict(SquareGrid.rect(1, 1).to_dict()) is SquareGrid, "a subclass call returns what the data says"
	)


func test_reads_the_format_of_0_2() -> void:
	var old := {"shape": 0, "cells": [[0, 0, {&"terrain": &"water"}], [1, 0, {}], [0, 1, {}]]}
	var grid := CellGrid.from_dict(old)
	check(grid is HexGrid, "shape 0 is a hex board")
	check(grid.size() == 3 and grid.get_value(Vector2i(0, 0), &"terrain") == &"water", "cells and values")
	check(grid.to_dict()["shape"] == "hex", "and it writes the new format")
	var from_json := CellGrid.from_dict({"shape": "square", "cells": [[0.0, 1.0, {"terrain": "sea"}]]})
	check(from_json.has_cell(Vector2i(0, 1)) and from_json.get_value(Vector2i(0, 1), &"terrain") == "sea", "JSON-like")
	check(from_json.to_dict()["diagonals"] == false, "diagonals default to off")


func test_values_roundtrip_keys_as_string_names() -> void:
	var grid := HexGrid.rect(2, 1)
	grid.set_value(Vector2i(0, 0), &"owner", 3)
	var copy := CellGrid.from_dict(grid.to_dict())
	var keys := copy.values(Vector2i(0, 0)).keys()
	check(keys.size() == 1 and typeof(keys[0]) == TYPE_STRING_NAME, "keys come back as StringName")


func test_batches_emit_once() -> void:
	var grid := HexGrid.new()
	var count := [0]
	grid.cells_changed.connect(func() -> void: count[0] += 1)
	var many: Array[Vector2i] = []
	for i in 50:
		many.append(Vector2i(i, 0))
	grid.add_cells(many)
	check(count[0] == 1 and grid.size() == 50, "add_cells emits once for 50 cells: %d" % count[0])
	grid.add_cells(many)
	check(count[0] == 1, "adding cells that are there emits nothing")
	var some: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(99, 99)]
	grid.remove_cells(some)
	check(count[0] == 2 and grid.size() == 48, "remove_cells emits once: %d" % count[0])
	grid.remove_cells(some)
	check(count[0] == 2, "removing cells that are gone emits nothing")
	var none: Array[Vector2i] = []
	grid.add_cells(none)
	grid.remove_cells(none)
	check(count[0] == 2, "an empty list emits nothing")


func test_erase_value() -> void:
	var grid := SquareGrid.rect(2, 2)
	var changes: Array = []
	grid.value_changed.connect(
		func(cell: Vector2i, key: StringName, value: Variant) -> void: changes.append([cell, key, value])
	)
	grid.set_value(Vector2i(1, 1), &"terrain", &"forest")
	grid.erase_value(Vector2i(1, 1), &"terrain")
	check(grid.get_value(Vector2i(1, 1), &"terrain") == null, "the value is gone")
	check(changes.size() == 2 and changes[1] == [Vector2i(1, 1), &"terrain", null], "it emits value_changed with null")
	grid.erase_value(Vector2i(1, 1), &"terrain")
	grid.erase_value(Vector2i(9, 9), &"terrain")
	check(changes.size() == 2, "erasing what is not there emits nothing")
	check(grid.values(Vector2i(1, 1)).is_empty(), "no values left")


func test_base_class_is_not_a_board() -> void:
	var grid := CellGrid.new()
	check(grid.shape_name() == &"", "the base has no shape")
	check(CellGrid.NO_CELL == HexGrid.NO_CELL, "NO_CELL is shared")
