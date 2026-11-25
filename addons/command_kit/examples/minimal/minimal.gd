extends Control

## Two players take turns putting stones on a 5 × 5 board. Every click is a PlaceStone command run by the bus: an
## occupied cell is rejected with its reason. Undo takes back the last stone; Replay clears the board and plays the
## log again, one stone at a time.

const PlaceStone := preload("res://addons/command_kit/examples/minimal/place_stone.gd")
const SIZE := 5
const MARKS: Array[String] = ["X", "O"]

## Seconds between two stones while replaying (0: all at once).
@export_range(0.0, 2.0, 0.05) var replay_step := 0.25

var state := {}
var _replaying := false

@onready var bus: CommandBus = %Commands
@onready var board: GridContainer = %Board
@onready var status: Label = %Status
@onready var undo_button: Button = %Undo
@onready var replay_button: Button = %Replay


func _ready() -> void:
	state = _new_state()
	bus.context = state
	board.columns = SIZE
	for row in SIZE:
		for column in SIZE:
			var button := Button.new()
			button.custom_minimum_size = Vector2(56, 56)
			button.pressed.connect(_on_cell_pressed.bind(Vector2i(column, row)))
			board.add_child(button)
	bus.executed.connect(func(_c: GameCommand) -> void: _refresh(""))
	bus.undone.connect(func(_c: GameCommand) -> void: _refresh("Undone"))
	bus.rejected.connect(func(_c: GameCommand, why: StringName) -> void: _refresh("Rejected: %s" % why))
	undo_button.pressed.connect(func() -> void: bus.undo())
	replay_button.pressed.connect(_replay)
	_refresh("")


func _on_cell_pressed(cell: Vector2i) -> void:
	if _replaying:
		return
	var command: GameCommand = PlaceStone.new()
	command.set(&"cell", cell)
	command.seat = int(state["turn"])
	bus.run(command)


func _replay() -> void:
	if _replaying:
		return
	_replaying = true
	replay_button.disabled = true
	var saved := bus.entries()
	bus.clear()
	state.assign(_new_state())
	_refresh("Replaying %d stones" % saved.size())
	for entry in saved:
		if replay_step > 0.0:
			await get_tree().create_timer(replay_step).timeout
		bus.replay([entry])
	_replaying = false
	replay_button.disabled = false
	_refresh("Replayed %d stones" % saved.size())


func _new_state() -> Dictionary:
	return {"stones": {}, "turn": 0}


func _refresh(note: String) -> void:
	var stones: Dictionary = state["stones"]
	for i in board.get_child_count():
		var cell := Vector2i(i % SIZE, i / SIZE)
		(board.get_child(i) as Button).text = MARKS[int(stones[cell])] if stones.has(cell) else ""
	var line := "%s to play · %d in the log" % [MARKS[int(state["turn"])], bus.size()]
	status.text = line if note == "" else "%s · %s" % [note, line]
	undo_button.disabled = _replaying or not bus.can_undo()
