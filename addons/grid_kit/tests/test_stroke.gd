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
