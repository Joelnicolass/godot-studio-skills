extends Node2D

## MpKit's card example: high card for three seats, with no pawns. Each seat's hand is its own (MpSeatState: only the
## server and that seat see it). Each card played is a move (MpOrders) the server judges and every peer applies. A seat
## nobody plays gets a bot (MpSeatBots). A player who comes back gets its hand and every move again.
## Click a card of your hand to play it.

const Rules := preload("res://addons/mp_kit/examples/cards_2d/rules.gd")

var rules := Rules.new()
var _note := ""
## The server's deck: only it deals.
var _rng := RandomNumberGenerator.new()

@onready var orders: MpOrders = %Orders
@onready var seat_state: MpSeatState = %SeatState
@onready var hand_box: HBoxContainer = %Hand
@onready var table_label: Label = %Table
@onready var status: Label = %Status


func _ready() -> void:
	orders.judge = _judge
	orders.state_hash = rules.hash_value
	orders.began.connect(_on_began)
	orders.applied.connect(_on_applied)
	orders.rejected.connect(_on_rejected)
	seat_state.watch(&"hand", func(_hand: Variant) -> void: _show())
	if MpKit.is_authority():
		_rng.randomize()
		orders.begin({"first": 1})
		_deal()
	_show()


## This screen's seat plays `card`.
func play(card: int) -> void:
	orders.submit(&"play", [card])


func _judge(slot: int, move: StringName, args: Array) -> String:
	if move != &"play" or args.size() != 1 or typeof(args[0]) != TYPE_INT:
		return "Unknown move."
	return rules.reason_against(slot, args[0], seat_state.value_of(slot, &"hand", []))


func _on_began(start: Dictionary) -> void:
	rules.reset(int(start.get("first", 1)))
	_show()


func _on_applied(_seq: int, slot: int, _move: StringName, args: Array) -> void:
	var round_over := rules.play(slot, args[0])
	if MpKit.is_authority():
		var hand: Array = (seat_state.value_of(slot, &"hand", []) as Array).duplicate()
		hand.erase(args[0])
		seat_state.set_value(slot, &"hand", hand)
		if round_over:
			_deal()
	_note = ""
	if not orders.is_replaying():
		_show()


func _on_rejected(_move: StringName, _args: Array, reason: String) -> void:
	_note = reason
	_show()


## Server: shuffles nine cards and gives each seat three. Only that seat sees its hand.
func _deal() -> void:
	var deck: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9]
	for i in range(deck.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var card := deck[i]
		deck[i] = deck[j]
		deck[j] = card
	for slot in range(1, Rules.SEATS + 1):
		var hand := deck.slice((slot - 1) * Rules.HAND, slot * Rules.HAND)
		hand.sort()
		seat_state.set_value(slot, &"hand", hand)


func _show() -> void:
	var me := Mp.me()
	for child in hand_box.get_children():
		child.queue_free()
	for card: int in seat_state.get_value(&"hand", []):
		var button := Button.new()
		button.text = str(card)
		button.custom_minimum_size = Vector2(64, 88)
		button.pressed.connect(play.bind(card))
		hand_box.add_child(button)
	var cards := PackedStringArray()
	for slot in range(1, Rules.SEATS + 1):
		var shown: Variant = rules.table.get(slot, rules.last_trick.get(slot, "-") if rules.table.is_empty() else "-")
		cards.append("P%d %s (%d)" % [slot, shown, rules.tricks[slot]])
	table_label.text = "   ".join(cards)
	var line := "Your turn: play a card." if rules.turn == me else "P%d to play." % rules.turn
	status.text = "You are P%d. %s%s" % [me, line, "\n" + _note if not _note.is_empty() else ""]
