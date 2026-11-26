extends Node2D

## MpKit's turn-based example: three in a row for two seats, with no pawns. A click sends a move with
## `MpOrders.submit`; the server judges it (your turn, a free cell) and every peer applies the moves it took, in order.
## A player who comes back gets every move again and sees the same board. Solo, one person plays both seats.
## Click a cell to play. When the game is over, Again (on the server) starts another one.

const Rules := preload("res://addons/mp_kit/examples/turns_2d/rules.gd")
const MARKS := ["", "X", "O"]

var rules := Rules.new()
var _note := ""

@onready var orders: MpOrders = %Orders
@onready var grid: GridContainer = %Grid
@onready var status: Label = %Status
@onready var again: Button = %Again


func _ready() -> void:
	orders.judge = _judge
	orders.state_hash = rules.hash_value
	orders.began.connect(_on_began)
	orders.applied.connect(_on_applied)
	orders.rejected.connect(_on_rejected)
	for i in grid.get_child_count():
		(grid.get_child(i) as Button).pressed.connect(play.bind(i))
	again.pressed.connect(start_game)
	if MpKit.is_authority():
		start_game()
	_show()


## The server (or solo): a new game; who starts is drawn here and travels with the start.
func start_game() -> void:
	if MpKit.is_authority():
		orders.begin({"first": randi_range(1, 2)})


## This screen's move. Solo, it plays for whoever's turn it is (both seats on one screen).
func play(cell: int) -> void:
	if MpKit.is_networked():
		orders.submit(&"place", [cell])
	else:
		orders.submit_as(rules.turn, &"place", [cell])


func _judge(slot: int, move: StringName, args: Array) -> String:
	if move != &"place" or args.size() != 1 or typeof(args[0]) != TYPE_INT:
		return "Unknown move."
	return rules.reason_against(slot, args[0])


func _on_began(start: Dictionary) -> void:
	rules.reset(int(start.get("first", 1)))
	_note = ""
	_show()


func _on_applied(_seq: int, slot: int, _move: StringName, args: Array) -> void:
	rules.place(slot, args[0])
	_note = ""
	if not orders.is_replaying():
		_show()


func _on_rejected(_move: StringName, _args: Array, reason: String) -> void:
	_note = reason
	_show()


func _show() -> void:
	for i in grid.get_child_count():
		(grid.get_child(i) as Button).text = MARKS[rules.cells[i]]
	var me := Mp.me()
	var line := ""
	if rules.winner == Rules.DRAW:
		line = "A draw."
	elif rules.winner != 0:
		line = "%s wins." % MARKS[rules.winner]
	elif not MpKit.is_networked():
		line = "%s to play." % MARKS[rules.turn]
	elif rules.turn == me:
		line = "Your turn (%s)." % MARKS[me]
	else:
		line = "%s to play. You are %s." % [MARKS[rules.turn], MARKS[me] if me in [1, 2] else "watching"]
	status.text = line + ("\n" + _note if not _note.is_empty() else "")
	again.visible = rules.winner != 0 and MpKit.is_authority()
