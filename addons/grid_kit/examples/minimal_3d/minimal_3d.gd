extends Node3D

## GridKit's smallest example: a hexagon board of radius 4 with four terrains. Click a cell: its neighborhood lights up.
## Move the pointer: the cell under it is marked.

@onready var board: GridBoard = $Board
@onready var view: GridView3D = $Board/View
@onready var selection: GridCursor = $Board/View/Selection
@onready var hover: GridCursor = $Board/View/Hover


func _ready() -> void:
	for cell in board.cells():
		board.set_value(cell, &"terrain", _terrain_for(cell))
	view.cell_clicked.connect(_on_cell_clicked)
	view.cell_hovered.connect(_on_cell_hovered)


func _on_cell_clicked(cell: Vector2i) -> void:
	selection.highlight(board.cells_in_range(cell, 1))


func _on_cell_hovered(cell: Vector2i) -> void:
	if cell == HexGrid.NO_CELL:
		hover.clear()
	else:
		hover.highlight([cell] as Array[Vector2i])


## A fixed map, so every run looks the same: water on the rim, mountains and forest by pattern.
func _terrain_for(cell: Vector2i) -> StringName:
	if board.distance(cell, Vector2i.ZERO) == board.radius:
		return &"water"
	var pattern := posmod(cell.x * 7 + cell.y * 13, 9)
	if pattern == 0:
		return &"mountain"
	if pattern < 3:
		return &"forest"
	return &"plain"
