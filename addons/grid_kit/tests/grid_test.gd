extends RefCounted

## Base of every GridKit test file: `check(cond, what)` records one result. The runner calls each `test_*` method.

var fails: int = 0
var passes: int = 0
var tree: SceneTree


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		fails += 1
		print("  FAIL %s" % what)


## A board of hexes with a view (`View`, tiles plain and water) and a cursor (`Cursor`), in the tree. `radius` 0: 7 × 7.
func build_board(radius: int) -> GridBoard:
	var board := GridBoard.new()
	board.radius = radius
	add_view(board)
	tree.root.add_child(board)
	return board


## The same with squares, `columns` × `rows`.
func build_square_board(columns: int, rows: int) -> GridBoard:
	var board := GridBoard.new()
	board.shape = GridBoard.Shape.SQUARES
	board.columns = columns
	board.rows = rows
	add_view(board)
	tree.root.add_child(board)
	return board


func add_view(board: GridBoard) -> void:
	var view := GridView3D.new()
	view.name = "View"
	view.default_tile = preload("res://addons/grid_kit/examples/minimal_3d/tiles/plain.tscn")
	view.tiles = {&"water": preload("res://addons/grid_kit/examples/minimal_3d/tiles/water.tscn")}
	board.add_child(view)
	var cursor := GridCursor.new()
	cursor.name = "Cursor"
	view.add_child(cursor)
