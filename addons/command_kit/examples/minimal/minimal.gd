extends Control

## Only the screen. A click asks `Commands` to place a stone and `rejected` says why not; Undo takes the last stone
## back; Replay clears the board and plays the history again, one stone at a time. The rules are in stones.gd.

const Stones := preload("res://addons/command_kit/examples/minimal/stones.gd")
const MARKS: Array[String] = ["X", "O"]

## Seconds between two stones while replaying (0: all at once).
@export_range(0.0, 2.0, 0.05) var replay_step := 0.25

var _replaying := false

@onready var game: Stones = %Stones
@onready var commands: GameCommands = %Commands
@onready var board: GridContainer = %Board
@onready var status: Label = %Status
@onready var undo_button: Button = %Undo
@onready var replay_button: Button = %Replay


func _ready() -> void:
	board.columns = Stones.SIZE
	for row in Stones.SIZE:
		for column in Stones.SIZE:
			var button := Button.new()
			button.custom_minimum_size = Vector2(56, 56)
			button.pressed.connect(_on_cell_pressed.bind(Vector2i(column, row)))
			board.add_child(button)
	commands.done.connect(func(_seat: int, _command: StringName, _args: Array) -> void: _refresh(""))
	commands.undone.connect(func(_seat: int, _command: StringName, _args: Array) -> void: _refresh("Undone"))
	commands.rejected.connect(
		func(_seat: int, _command: StringName, _args: Array, reason: String) -> void: _refresh("Rejected: %s" % reason)
	)
	undo_button.pressed.connect(func() -> void: commands.undo())
	replay_button.pressed.connect(_replay)
	_refresh("")


func _on_cell_pressed(cell: Vector2i) -> void:
	if not _replaying:
		commands.run(game.turn, &"place", [cell])


func _replay() -> void:
	if _replaying:
		return
	_replaying = true
	replay_button.disabled = true
	var saved := commands.history()
	commands.clear()
	game.reset()
	_refresh("Replaying %d stones" % saved.size())
	for entry in saved:
		if replay_step > 0.0:
			await get_tree().create_timer(replay_step).timeout
		commands.replay([entry])
	_replaying = false
	replay_button.disabled = false
	_refresh("Replayed %d stones" % saved.size())


func _refresh(note: String) -> void:
	for i in board.get_child_count():
		var cell := Vector2i(i % Stones.SIZE, i / Stones.SIZE)
		(board.get_child(i) as Button).text = MARKS[game.stones[cell]] if game.stones.has(cell) else ""
	var line := "%s to play · %d in the history" % [MARKS[game.turn], commands.size()]
	status.text = line if note == "" else "%s · %s" % [note, line]
	undo_button.disabled = _replaying or not commands.can_undo()
