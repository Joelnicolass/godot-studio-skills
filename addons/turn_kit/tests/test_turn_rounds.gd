extends "res://addons/turn_kit/tests/turn_test.gd"

## TurnCycle alone: a first seat that rotates and an order of your own for each round.


func _openers(turns: TurnCycle, rounds: int) -> Array[int]:
	var found: Array[int] = []
	for i in rounds:
		found.append(turns.round_first_seat)
		for j in turns.round_order().size():
			turns.end_turn()
	return found


func test_defaults() -> void:
	var turns := TurnCycle.new()
	turns.start()
	check(turns.actions_left == 1 and turns.actions_per_turn == 1, "actions default to 1: %d" % turns.actions_left)
	check(turns.round_first_seat == 0 and turns.current_phase == &"" and turns.phase_index == -1, "no phase, opener 0")
	check(not turns.first_seat_rotates and turns.turn_seconds == 0.0 and turns.time_left == 0.0, "nothing new is on")
	check(TurnCycle.new().round_first_seat == -1, "no opener before start")


func test_first_seat_rotates() -> void:
	var turns := TurnCycle.new(3, 1)
	turns.first_seat_rotates = true
	turns.start()
	check(_openers(turns, 4) == ([0, 1, 2, 0] as Array[int]), "4 rounds open 0, 1, 2, 0")
	check(turns.round_order() == ([1, 2, 0] as Array[int]), "round 5 opens at 1: %s" % [turns.round_order()])
	var off := TurnCycle.new(3, 1)
	off.start()
	check(_openers(off, 3) == ([0, 0, 0] as Array[int]), "without rotation the same seat opens every round")


func test_first_seat_rotates_from_other_start() -> void:
	var turns := TurnCycle.new(3, 1)
	turns.first_seat_rotates = true
	turns.start(2)
	check(_openers(turns, 4) == ([2, 0, 1, 2] as Array[int]), "starts at first_seat 2, then 0, 1, 2")
	turns.start(1)
	check(turns.round_first_seat == 1, "start() begins again at its first seat")


func test_first_seat_rotates_with_inactive() -> void:
	var turns := TurnCycle.new(3, 1)
	turns.first_seat_rotates = true
	turns.set_seat_active(1, false)
	turns.start()
	check(_openers(turns, 4) == ([0, 2, 0, 2] as Array[int]), "an inactive seat is skipped as opener")
	var other := TurnCycle.new(3, 1)
	other.first_seat_rotates = true
	other.start()
	other.end_turn()
	other.set_seat_active(2, false)
	other.end_turn()
	other.end_turn()
	check(other.round_number == 2 and other.round_first_seat == 1, "round 2 opens at 1")
	other.end_turn()
	check(other.round_order() == ([0, 1] as Array[int]) and other.round_first_seat == 0, "2 is out: 1, then 0 opens")


func test_set_round_order() -> void:
	var turns := TurnCycle.new(3, 1)
	turns.start()
	turns.set_round_order([2, 0, 1])
	check(turns.round_order() == ([0, 1, 2] as Array[int]), "the round being played does not change")
	check(turns.custom_round_order() == ([2, 0, 1] as Array[int]), "the order is stored")
	turns.end_turn()
	turns.end_turn()
	turns.end_turn()
	check(turns.round_order() == ([2, 0, 1] as Array[int]) and turns.current_seat == 2, "it counts from the next round")
	check(turns.round_first_seat == 2, "the opener is the first of the order")
	turns.set_round_order([])
	check(turns.custom_round_order().is_empty(), "an empty list clears it")
	for i in 3:
		turns.end_turn()
	check(turns.round_order() == ([0, 1, 2] as Array[int]), "back to the order by seat")


func test_set_round_order_from_round_ended() -> void:
	var turns := TurnCycle.new(3, 1)
	var hook := func(_n: int) -> void: turns.set_round_order([1, 2, 0])
	turns.round_ended.connect(hook)
	turns.start()
	for i in 3:
		turns.end_turn()
	check(turns.round_number == 2 and turns.current_seat == 1, "set in round_ended: the round that starts uses it")
	check(turns.round_order() == ([1, 2, 0] as Array[int]), "whole order: %s" % [turns.round_order()])
	turns.round_ended.disconnect(hook)


func test_set_round_order_partial_and_inactive() -> void:
	var turns := TurnCycle.new(4, 1)
	turns.start()
	turns.set_round_order([3, 1])
	for i in 4:
		turns.end_turn()
	check(turns.round_order() == ([3, 1] as Array[int]), "seats left out do not play")
	turns.end_turn()
	turns.end_turn()
	check(turns.round_number == 3 and turns.round_order() == ([3, 1] as Array[int]), "and it goes on")
	turns.set_seat_active(3, false)
	turns.end_turn()
	turns.end_turn()
	check(turns.round_order() == ([1] as Array[int]), "an inactive seat of the order is skipped")
	turns.first_seat = 2
	turns.end_turn()
	check(turns.round_order() == ([1] as Array[int]), "first_seat does not apply to an order of your own")
	turns.set_seat_active(1, false)
	turns.end_turn()
	check(turns.is_finished, "an order with no active seat ends the match")


func test_set_round_order_invalid() -> void:
	var turns := TurnCycle.new(3, 1)
	turns.set_round_order([1, 0])
	turns.set_round_order([0, 3])
	check(turns.custom_round_order() == ([1, 0] as Array[int]), "a seat that does not exist changes nothing")
	turns.set_round_order([2, 2])
	check(turns.custom_round_order() == ([1, 0] as Array[int]), "a seat listed twice changes nothing")
	turns.set_round_order([-1])
	check(turns.custom_round_order() == ([1, 0] as Array[int]), "a negative seat changes nothing")
	var copy := turns.custom_round_order()
	copy.append(2)
	check(turns.custom_round_order().size() == 2, "custom_round_order() is a copy")
