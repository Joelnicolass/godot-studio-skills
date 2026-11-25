extends "res://addons/grid_kit/tests/grid_test.gd"

## The brush stroke (editor/grid_stroke.gd) with no editor: what it applies, what it reports, and that the report
## undoes it. The mouse and the editor's undo history are the plugin's, and need an open editor.

const Stroke := preload("res://addons/grid_kit/editor/grid_stroke.gd")
const TILE := preload("res://addons/grid_kit/examples/minimal_3d/tiles/plain.tscn")
const OTHER := preload("res://addons/grid_kit/examples/minimal_3d/tiles/water.tscn")


func _build(as_squares := false) -> GridBoard:
	var board := GridBoard.new()
	board._in_editor = true
	if as_squares:
		board.shape = GridBoard.Shape.SQUARES
		board.columns = 4
		board.rows = 4
	else:
		board.radius = 2
	var view := GridView3D.new()
	view.name = "View"
	view.default_tile = TILE
	view.tiles = {&"water": OTHER, &"forest": OTHER}
	board.add_child(view)
	tree.root.add_child(board)
	return board


func _view(board: GridBoard) -> GridView3D:
	return board.get_node(^"View") as GridView3D


func test_paint_three_cells() -> void:
	var board := _build()
	var stroke := Stroke.new()
	stroke.begin(board, _view(board), Stroke.Tool.PAINT, &"water")
	check(stroke.is_active(), "a stroke is active after begin")
	check(stroke.touch(Vector2i(0, 0)), "the first cell changes the board")
	check(stroke.touch(Vector2i(1, 0)) and stroke.touch(Vector2i(0, 1)), "so do two more")
	check(board.get_value(Vector2i(1, 0), &"terrain") == &"water", "the board is painted while dragging")
	var result := stroke.finish()
	check(not stroke.is_active() and result["changed"], "finish ends it, and something changed")
	check(result["key"] == &"terrain", "it painted the view's value_key")
	check((result["after"] as Dictionary).size() == 3, "three cells in after: %s" % [result["after"]])
	check((result["before"] as Dictionary).size() == 3, "three cells in before")
	check((result["before"] as Dictionary)[Vector2i(0, 0)] == null, "before: no value there")
	check((result["after"] as Dictionary)[Vector2i(0, 0)] == &"water", "after: water")
	board.free()


func test_repeating_a_cell_does_not_duplicate() -> void:
	var board := _build()
	var stroke := Stroke.new()
	stroke.begin(board, _view(board), Stroke.Tool.PAINT, &"water")
	stroke.touch(Vector2i(0, 0))
	check(not stroke.touch(Vector2i(0, 0)), "the same cell again changes nothing")
	check(not stroke.touch(Vector2i(50, 50)), "a cell off the board changes nothing")
	check(not stroke.touch(CellGrid.NO_CELL), "NO_CELL changes nothing")
	var result := stroke.finish()
	check((result["after"] as Dictionary).size() == 1 and (result["before"] as Dictionary).size() == 1, "counted once")
	board.free()


func test_before_after_and_undo_for_values() -> void:
	var board := _build()
	board.set_value(Vector2i(0, 0), &"terrain", &"forest")
	var snapshot := board.grid.to_dict()
	var stroke := Stroke.new()
	stroke.begin(board, _view(board), Stroke.Tool.PAINT, &"water")
	stroke.touch(Vector2i(0, 0))
	stroke.touch(Vector2i(1, 0))
	var result := stroke.finish()
	check((result["before"] as Dictionary)[Vector2i(0, 0)] == &"forest", "before remembers the old value")
	check((result["before"] as Dictionary)[Vector2i(1, 0)] == null, "and the lack of one")
	check(board.grid.to_dict() != snapshot, "the stroke changed the board")
	board.paint(result["key"], result["before"])
	check(board.grid.to_dict() == snapshot, "applying before leaves everything as it was")
	board.paint(result["key"], result["after"])
	check(board.get_value(Vector2i(0, 0), &"terrain") == &"water", "applying after paints again")
	board.free()


func test_erase_goes_back_to_default() -> void:
	var board := _build()
	board.set_value(Vector2i(0, 0), &"terrain", &"water")
	var stroke := Stroke.new()
	stroke.begin(board, _view(board), Stroke.Tool.ERASE)
	stroke.touch(Vector2i(0, 0))
	check(not stroke.touch(Vector2i(1, 0)), "erasing a cell with no value changes nothing")
	var result := stroke.finish()
	check(board.get_value(Vector2i(0, 0), &"terrain") == null, "the value is gone")
	check((result["before"] as Dictionary)[Vector2i(0, 0)] == &"water", "before has it")
	check((result["after"] as Dictionary)[Vector2i(0, 0)] == null, "after has none")
	board.paint(result["key"], result["before"])
	check(board.get_value(Vector2i(0, 0), &"terrain") == &"water", "undo puts it back")
	board.free()


func test_add_cells_and_undo() -> void:
	var board := _build(true)
	var snapshot := board.grid.to_dict()
	var stroke := Stroke.new()
	stroke.begin(board, _view(board), Stroke.Tool.ADD)
	check(not stroke.touch(Vector2i(1, 1)), "a cell that is there is not added")
	check(stroke.touch(Vector2i(4, 0)) and stroke.touch(Vector2i(5, 0)), "cells next to the board are")
	check(not stroke.touch(Vector2i(4, 0)), "and only once")
	var result := stroke.finish()
	var added: Array[Vector2i] = result["added"]
	check(added == ([Vector2i(4, 0), Vector2i(5, 0)] as Array[Vector2i]), "added: %s" % [added])
	check(board.has_cell(Vector2i(5, 0)) and board.cells().size() == 18, "the board grew")
	var none: Array[Vector2i] = []
	board.set_cells(none, added)
	check(board.grid.to_dict() == snapshot, "undoing the stroke removes what it added")
	board.set_cells(added, none)
	check(board.has_cell(Vector2i(4, 0)), "and doing it again adds them")
	board.free()


func test_remove_cells_and_undo_with_values() -> void:
	var board := _build(true)
	board.set_value(Vector2i(1, 1), &"terrain", &"water")
	board.set_value(Vector2i(1, 1), &"owner", 2)
	board.set_value(Vector2i(2, 1), &"terrain", &"forest")
	var snapshot := board.grid.to_dict()
	var stroke := Stroke.new()
	stroke.begin(board, _view(board), Stroke.Tool.REMOVE)
	check(stroke.touch(Vector2i(1, 1)) and stroke.touch(Vector2i(2, 1)), "two cells go")
	check(not stroke.touch(Vector2i(1, 1)) and not stroke.touch(Vector2i(40, 40)), "gone or never there: nothing")
	var result := stroke.finish()
	var removed: Array[Vector2i] = result["removed"]
	check(removed.size() == 2 and not board.has_cell(Vector2i(1, 1)) and board.cells().size() == 14, "cells removed")
	var values: Dictionary = result["removed_values"]
	check(values[Vector2i(1, 1)] == {&"terrain": &"water", &"owner": 2}, "all their values are kept: %s" % [values])
	var none: Array[Vector2i] = []
	board.set_cells(removed, none, values)
	check(board.grid.to_dict() == snapshot, "undoing restores the cells and every value")
	board.free()


func test_a_board_without_layout_gets_one() -> void:
	var board := _build()
	check(board.layout == null, "no layout at first")
	var stroke := Stroke.new()
	stroke.begin(board, _view(board), Stroke.Tool.PAINT, &"water")
	check(board.layout != null, "begin made a layout from the board's shape")
	stroke.touch(Vector2i(0, 0))
	stroke.touch(Vector2i(1, 0))
	var result := stroke.finish()
	var layout: GridLayout = result["layout"]
	check(layout != null and layout == board.layout, "finish reports it")
	check(layout.get_value(Vector2i(1, 0), &"terrain") == &"water", "what was painted is in it")
	check(layout.make_grid().to_dict() == board.grid.to_dict(), "the layout and the live board agree")
	check(layout.cells.size() == 19, "it has the board's 19 cells")
	board.free()


func test_a_stroke_that_changes_nothing_takes_its_layout_back() -> void:
	var board := _build()
	var stroke := Stroke.new()
	stroke.begin(board, _view(board), Stroke.Tool.PAINT, &"water")
	stroke.touch(Vector2i(50, 50))
	var result := stroke.finish()
	check(not result["changed"] and result["layout"] == null, "nothing changed, no layout reported")
	check(board.layout == null, "and the board has none again")
	board.free()


func test_a_board_with_a_layout_keeps_it() -> void:
	var board := _build()
	var layout := GridLayout.from_grid(board.grid)
	board.layout = layout
	var stroke := Stroke.new()
	stroke.begin(board, _view(board), Stroke.Tool.PAINT, &"water")
	stroke.touch(Vector2i(0, 0))
	var result := stroke.finish()
	check(result["layout"] == null and board.layout == layout, "the layout stays and is not new")
	check(layout.get_value(Vector2i(0, 0), &"terrain") == &"water", "the stroke wrote it")
	board.paint(result["key"], result["before"])
	check(layout.get_value(Vector2i(0, 0), &"terrain") == null, "and undo took it back out")
	board.free()


func test_undo_redo_order_with_a_new_layout() -> void:
	# The plugin records one action: do = assign the layout, then paint; undo = unpaint, then take the layout away.
	# UndoRedo runs undo methods in the order they were added (the editor's history wraps the same object).
	var board := _build()
	var snapshot := board.grid.to_dict()
	var stroke := Stroke.new()
	stroke.begin(board, _view(board), Stroke.Tool.PAINT, &"water")
	stroke.touch(Vector2i(0, 0))
	var result := stroke.finish()
	var layout: GridLayout = result["layout"]
	var history := UndoRedo.new()
	history.create_action("Paint grid cells")
	history.add_do_property(board, &"layout", layout)
	history.add_do_method(board.paint.bind(result["key"], result["after"]))
	history.add_undo_method(board.paint.bind(result["key"], result["before"]))
	history.add_undo_property(board, &"layout", null)
	history.commit_action(false)
	var painted := board.grid.to_dict()
	history.undo()
	check(board.layout == null and board.grid.to_dict() == snapshot, "undo: no layout, the board as it was")
	check(layout.get_value(Vector2i(0, 0), &"terrain") == null, "the layout was unpainted before it left")
	history.redo()
	check(board.layout == layout and board.grid.to_dict() == painted, "redo: the layout and the paint again")
	history.free()
	board.free()


func test_raise_and_lower_a_step_per_stroke() -> void:
	var board := _build()
	board.height_key = &"level"
	board.set_value(Vector2i(1, 0), &"level", 1.5)
	board.set_value(Vector2i(0, 0), &"terrain", &"forest")
	var snapshot := board.grid.to_dict()
	var stroke := Stroke.new()
	stroke.begin(board, _view(board), Stroke.Tool.RAISE, 1.0)
	check(stroke.touch(Vector2i(0, 0)) and stroke.touch(Vector2i(1, 0)), "two cells go up")
	check(not stroke.touch(Vector2i(0, 0)), "a cell goes up once per stroke")
	check(not stroke.touch(Vector2i(50, 50)), "a cell off the board does not")
	var raised: Variant = board.get_value(Vector2i(0, 0), &"level")
	check(raised == 1 and typeof(raised) == TYPE_INT, "no height + 1 = 1, written as an int: %s" % [raised])
	check(board.get_value(Vector2i(1, 0), &"level") == 2.5, "1.5 + 1 = 2.5")
	check(board.cell_to_position(Vector2i(1, 0)).y == 2.5, "and the board places it there while dragging")
	var result := stroke.finish()
	check(result["changed"] and result["key"] == &"level", "it wrote the board's height_key, not the view's key")
	check(result["height_key"] == &"", "the board had a height key: none to report")
	check(result["before"] == {Vector2i(0, 0): null, Vector2i(1, 0): 1.5}, "before: %s" % [result["before"]])
	check(result["after"] == {Vector2i(0, 0): 1, Vector2i(1, 0): 2.5}, "after: %s" % [result["after"]])
	check(board.get_value(Vector2i(0, 0), &"terrain") == &"forest", "the terrain is untouched")
	stroke.begin(board, _view(board), Stroke.Tool.LOWER, 0.1)
	stroke.touch(Vector2i(0, 0))
	var lowered := stroke.finish()
	check(board.get_value(Vector2i(0, 0), &"level") == 0.9, "a stroke of Lower by 0.1: 0.9")
	for i in 9:
		stroke.begin(board, _view(board), Stroke.Tool.LOWER, 0.1)
		stroke.touch(Vector2i(0, 0))
		stroke.finish()
	var ground: Variant = board.get_value(Vector2i(0, 0), &"level")
	check(ground == 0 and typeof(ground) == TYPE_INT, "nine more land on 0, with no drift: %s" % [ground])
	board.paint(lowered["key"], {Vector2i(0, 0): 1})
	board.paint(result["key"], result["before"])
	check(board.grid.to_dict() == snapshot, "applying before undoes the heights")
	board.free()


func test_set_height() -> void:
	var board := _build(true)
	board.height_key = &"height"
	board.set_value(Vector2i(1, 1), &"height", 2.0)
	board.set_value(Vector2i(2, 1), &"height", "tall")
	var stroke := Stroke.new()
	stroke.begin(board, _view(board), Stroke.Tool.SET_HEIGHT, 2.0)
	check(stroke.touch(Vector2i(0, 0)), "a cell gets the height")
	check(not stroke.touch(Vector2i(0, 0)), "the same cell again changes nothing")
	check(not stroke.touch(Vector2i(1, 1)), "nor a cell that is at that height already")
	check(stroke.touch(Vector2i(2, 1)), "a value that is not a number is replaced")
	var result := stroke.finish()
	check(result["after"] == {Vector2i(0, 0): 2, Vector2i(2, 1): 2}, "after: %s" % [result["after"]])
	check((result["before"] as Dictionary)[Vector2i(2, 1)] == "tall", "before keeps what was there")
	stroke.begin(board, _view(board), Stroke.Tool.SET_HEIGHT, 0.0)
	check(not stroke.touch(Vector2i(3, 3)), "height 0 on a cell with no height changes nothing")
	check(stroke.touch(Vector2i(0, 0)), "on a raised cell it does")
	check(not stroke.finish()["before"].has(Vector2i(3, 3)), "and only that one is reported")
	stroke.begin(board, _view(board), Stroke.Tool.SET_HEIGHT, -1.25)
	stroke.touch(Vector2i(0, 0))
	stroke.finish()
	check(board.get_value(Vector2i(0, 0), &"height") == -1.25, "a height can be negative and a fraction")
	board.free()


func test_the_first_height_stroke_gives_the_board_a_height_key() -> void:
	var board := _build()
	var snapshot := board.grid.to_dict()
	var stroke := Stroke.new()
	stroke.begin(board, _view(board), Stroke.Tool.RAISE, 2.0)
	check(board.height_key == &"height", "begin gave the board the default key")
	stroke.touch(Vector2i(1, 0))
	var result := stroke.finish()
	check(result["height_key"] == &"height" and result["layout"] == board.layout, "finish reports the key and layout")
	check(board.layout.get_value(Vector2i(1, 0), &"height") == 2, "the height is saved in the layout")
	check(board.cell_to_position(Vector2i(1, 0)).y == 2.0, "and the cell stands there")
	board.paint(result["key"], result["before"])
	check(board.grid.to_dict() == snapshot and not board.layout.cells[Vector2i(1, 0)].has(&"height"), "undone")
	board.free()


func test_a_height_stroke_that_changes_nothing_takes_its_key_back() -> void:
	var board := _build()
	var stroke := Stroke.new()
	stroke.begin(board, _view(board), Stroke.Tool.SET_HEIGHT, 0.0)
	stroke.touch(Vector2i(0, 0))
	var result := stroke.finish()
	check(not result["changed"] and result["height_key"] == &"", "nothing changed, no key reported")
	check(board.height_key == &"" and board.layout == null, "the board has no height key and no layout again")
	board.free()
