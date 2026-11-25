extends Node3D

## A board of squares, 8 x 8, with two tiles in a checker pattern. Click a cell: the cells within 2 steps light up
## (white) and so does the path from the cell you clicked before (yellow).

var _last_clicked := CellGrid.NO_CELL

@onready var board: GridBoard = $Board
@onready var view: GridView3D = $Board/View
@onready var reach: GridCursor = $Board/View/Reach
@onready var route: GridCursor = $Board/View/Route


func _ready() -> void:
	for cell in board.cells():
		board.set_value(cell, &"terrain", &"light" if (cell.x + cell.y) % 2 == 0 else &"dark")
	view.cell_clicked.connect(_on_cell_clicked)


func _on_cell_clicked(cell: Vector2i) -> void:
	reach.highlight(board.cells_in_range(cell, 2))
	if _last_clicked == CellGrid.NO_CELL:
		route.clear()
	else:
		route.highlight(board.find_path(_last_clicked, cell))
	_last_clicked = cell
