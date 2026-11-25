@tool
class_name TurnSeat
extends Node

## One player of its parent `TurnClock`: the seat number is its place among the clock's `TurnSeat` children (the first
## is 0). Listen to its own signals when a piece of the game cares only about one player (a bot, a player's HUD).

## It is this seat's turn now.
signal turn_started
## This seat's turn is over.
signal turn_ended

## The name a HUD shows.
@export var display_name := ""
## For the game: a bot plays this seat. TurnKit only stores it.
@export var is_bot := false
## Off: the clock skips this seat (eliminated, disconnected). It plays again from the next round once back on.
@export var active := true:
	set(value):
		active = value
		var clock := get_parent() as TurnClock
		if clock != null and is_inside_tree():
			clock.set_seat_active(index(), value)


## This seat's number in the clock (-1 when its parent is not a `TurnClock`).
func index() -> int:
	var clock := get_parent() as TurnClock
	return clock.seat_nodes().find(self) if clock != null else -1


## True while it is this seat's turn.
func is_current() -> bool:
	var clock := get_parent() as TurnClock
	return clock != null and clock.current_seat == index() and index() >= 0


func _get_configuration_warnings() -> PackedStringArray:
	if not get_parent() is TurnClock:
		return PackedStringArray(["TurnSeat is a player of its parent: make it a child of a TurnClock."])
	return PackedStringArray()
