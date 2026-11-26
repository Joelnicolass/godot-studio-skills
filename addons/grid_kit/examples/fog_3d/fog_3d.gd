extends Node3D

## GridKit's fog of war: two players, a scout each, on the map of the minimal example. Each player sees `sight` steps
## around their scout; what they saw before stays explored (darker), the rest is hidden. Click a cell you see: your
## scout goes there. **Switch player** draws the other player's fog; the rival scout shows only where you see it.

## How many steps around a scout its player sees.
@export_range(0, 6) var sight := 2
## Where each player's scout starts: player 0 first.
@export var starts: Array[Vector2i] = [Vector2i(-3, 0), Vector2i(3, 0)]
@export var board: GridBoard
@export var view: GridView3D
@export var fog: GridFog
## The marker of each player's scout, player 0 first.
@export var scout_markers: Array[GridCursor] = []

var player := 0
var scouts: Array[Vector2i] = []


func _ready() -> void:
	view.cell_clicked.connect(_on_cell_clicked)
	%Switch.pressed.connect(_on_switch_pressed)
	%Reset.pressed.connect(_on_reset_pressed)
	_on_reset_pressed()


func _on_cell_clicked(cell: Vector2i) -> void:
	if not fog.sees(player, cell):
		%Log.text = "You cannot see %s: move closer." % [cell]
		return
	scouts[player] = cell
	fog.see_around(player, [cell] as Array[Vector2i], sight)
	%Log.text = "Player %d's scout went to %s." % [player + 1, cell]
	_show()


func _on_switch_pressed() -> void:
	player = 1 - player
	fog.shown_observer = player
	%Log.text = "Player %d's turn." % [player + 1]
	_show()


func _on_reset_pressed() -> void:
	fog.clear()
	scouts = starts.duplicate()
	for seat in scouts.size():
		fog.see_around(seat, [scouts[seat]] as Array[Vector2i], sight)
	%Log.text = "Click a cell you see to move your scout."
	_show()


# The own scout always shows; the rival's only where this player sees it.
func _show() -> void:
	for seat in scout_markers.size():
		var cell := scouts[seat]
		if seat == player or fog.sees(player, cell):
			scout_markers[seat].highlight([cell] as Array[Vector2i])
		else:
			scout_markers[seat].clear()
	var seen := fog.visible_cells(player).size()
	var explored := fog.explored_cells(player).size()
	%Counts.text = (
		"Player %d sees %d cells, explored %d, %d hidden"
		% [player + 1, seen, explored, board.cells().size() - seen - explored]
	)
