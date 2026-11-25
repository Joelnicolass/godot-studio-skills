extends Node3D

## GridKit's smallest example: a hexagon board of radius 4 whose map (the shape and four terrains) is the saved layout
## `map.tres`. Click a cell: its neighborhood lights up. Move the pointer: the cell under it is marked.

@onready var board: GridBoard = $Board
@onready var view: GridView3D = $Board/View
@onready var selection: GridCursor = $Board/View/Selection
@onready var hover: GridCursor = $Board/View/Hover


func _ready() -> void:
	view.cell_clicked.connect(_on_cell_clicked)
	view.cell_hovered.connect(_on_cell_hovered)


func _on_cell_clicked(cell: Vector2i) -> void:
	selection.highlight(board.cells_in_range(cell, 1))


func _on_cell_hovered(cell: Vector2i) -> void:
	if cell == CellGrid.NO_CELL:
		hover.clear()
	else:
		hover.highlight([cell] as Array[Vector2i])
