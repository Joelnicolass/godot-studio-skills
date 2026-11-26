extends Node

## A bot in a seat nobody plays (the world's MpSeatBots puts it there, on the server): on its seat's turn it waits a
## moment and plays a card of its hand, which it reads from the seat's own values (MpSeatState) like the player would.

## Its seat: MpSeatBots sets it before adding the bot.
var slot := 0
## How long it thinks before it plays.
var think_s := 0.4

var _wait_s := 0.0


func _process(delta: float) -> void:
	var orders := MpOrders.of(self)
	var seats := MpSeatState.of(self)
	var world := orders.get_parent() if orders else null  # the world: the Orders node's parent
	if world == null or seats == null or int(world.get(&"rules").get(&"turn")) != slot:
		_wait_s = 0.0
		return
	_wait_s += delta
	if _wait_s < think_s:
		return
	_wait_s = 0.0
	var hand: Array = seats.value_of(slot, &"hand", [])
	if not hand.is_empty():
		orders.submit_as(slot, &"play", [hand.max()])
