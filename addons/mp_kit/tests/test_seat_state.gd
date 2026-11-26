extends "res://addons/mp_kit/tests/mp_test.gd"

## MpSeatState on this machine (solo: the server and seat 1): values per seat, this seat's changes and watches, the
## other seats' kept on the server only for itself, add, clear_seat; and MpSeatBots: a bot in every seat but the
## player's.


func _state() -> MpSeatState:
	var state := MpSeatState.new()
	tree.root.add_child(state)
	return state


func test_values_belong_to_a_seat() -> void:
	var state := _state()
	var seen: Array = []
	state.changed.connect(func(key: StringName, value: Variant) -> void: seen.append([key, value]))
	var watched: Array = []
	var handle := state.watch(&"hand", func(value: Variant) -> void: watched.append(value), [])
	check(watched == [[]], "a watch gets the current value at once (the default)")
	state.set_value(1, &"hand", [3, 7])
	state.set_value(2, &"hand", [1, 9])
	check(state.get_value(&"hand") == [3, 7] and state.values() == {&"hand": [3, 7]}, "this seat's own values")
	check(state.value_of(2, &"hand") == [1, 9], "the server knows every seat's")
	check(seen == [[&"hand", [3, 7]]], "changed only for this seat (%s)" % [seen])
	check(watched == [[], [3, 7]], "and the watch too (%s)" % [watched])
	state.set_value(1, &"hand", [3, 7])
	check(seen.size() == 1, "the same value again changes nothing")
	state.add(1, &"ammo", 5)
	state.add(1, &"ammo", 2)
	check(state.get_value(&"ammo") == 7, "add sums from 0")
	state.unwatch(handle)
	state.clear_seat(1)
	check(state.values().is_empty() and seen.back() == [&"ammo", null], "clear_seat removes every value (null)")
	check(watched.size() == 2, "an unwatched watch hears nothing more")
	check(MpSeatState.of(state) == state, "MpSeatState.of finds it")
	state.free()


func test_seat_bots_fill_the_other_seats_solo() -> void:
	var world := (load("res://addons/mp_kit/examples/cards_2d/world.tscn") as PackedScene).instantiate()
	tree.root.add_child(world)
	await tree.process_frame
	await tree.process_frame
	var bots := world.get_node(^"SeatBots") as MpSeatBots
	check(bots.bot_of(1) == null, "no bot in the player's seat")
	check(bots.bot_of(2) != null and bots.bot_of(3) != null, "a bot in each other seat")
	check(
		bots.bot_of(2).get(&"slot") == 2 and bots.bot_of(2).get_parent() == bots,
		"with its slot, under SeatBots (no pawns)"
	)
	var removed: Array = []
	bots.bot_removed.connect(func(slot: int) -> void: removed.append(slot))
	bots.remove(3)
	check(removed == [3] and bots.bot_of(3) == null, "remove takes a bot off its seat")
	world.free()
