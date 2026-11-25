extends "res://addons/turn_kit/tests/turn_test.gd"

## TurnCycle alone, no tree: actions, turn order, rounds, cycles, the end, inactive seats and to_dict.


func _record(turns: TurnCycle) -> Array[String]:
	var events: Array[String] = []
	turns.turn_started.connect(func(seat: int) -> void: events.append("start %d" % seat))
	turns.action_spent.connect(func(left: int) -> void: events.append("spent %d" % left))
	turns.turn_ended.connect(func(seat: int) -> void: events.append("end %d" % seat))
	turns.round_ended.connect(func(n: int) -> void: events.append("round %d" % n))
	turns.cycle_ended.connect(func(n: int) -> void: events.append("cycle %d" % n))
	turns.finished.connect(func() -> void: events.append("finished"))
	return events


func test_actions() -> void:
	var turns := TurnCycle.new(2, 3)
	check(not turns.spend_action(), "no action before start")
	turns.start()
	check(turns.current_seat == 0 and turns.actions_left == 3, "seat 0 starts with 3 actions")
	check(turns.spend_action(2), "spends 2")
	check(not turns.spend_action(2), "cannot spend 2 with 1 left")
	check(turns.actions_left == 1, "a failed spend changes nothing: %d" % turns.actions_left)
	check(not turns.spend_action(0), "spending 0 is not a spend")
	check(turns.spend_action(), "spends the last one")
	check(turns.current_seat == 0, "the last action does not end the turn")
	check(not turns.spend_action(), "no actions left")


func test_end_turn_with_actions_left() -> void:
	var turns := TurnCycle.new(3, 3)
	var events := _record(turns)
	turns.start()
	turns.spend_action()
	check(turns.end_turn(), "ending with actions left is valid")
	check(turns.current_seat == 1 and turns.actions_left == 3, "seat 1 gets fresh actions")
	turns.end_turn()
	turns.end_turn()
	check(turns.current_seat == 0 and turns.round_number == 2, "after seat 2, round 2 starts at seat 0")
	var expected: Array[String] = [
		"start 0", "spent 2", "end 0", "start 1", "end 1", "start 2", "end 2", "round 1", "start 0"
	]
	check(events == expected, "signals in order: %s" % [events])


func test_cycles_and_finish() -> void:
	var turns := TurnCycle.new(2, 1, 2, 2)
	var events := _record(turns)
	turns.start()
	for i in 8:
		turns.end_turn()
	check(turns.is_finished, "2 cycles of 2 rounds of 2 seats: 8 turns")
	check(turns.current_seat == -1 and turns.actions_left == 0, "no seat after the end")
	check(not turns.end_turn() and not turns.spend_action(), "nothing plays after the end")
	check(events.has("cycle 1") and events[-1] == "finished", "cycle 1 ended and the match finished: %s" % [events])
	check(events.count("round 4") == 1 and not events.has("round 5"), "4 rounds in all")
	check(events[-2] == "cycle 2" and events[-3] == "round 4", "round, then cycle, then finished: %s" % [events])


func test_no_end() -> void:
	var turns := TurnCycle.new(2, 3, 0, 0)
	turns.start()
	for i in 100:
		turns.end_turn()
	check(not turns.is_finished and turns.round_number == 51, "0 = no end: round %d" % turns.round_number)
	check(turns.cycle_number == 1, "rounds_per_cycle 0: the cycle never ends")
	var endless := TurnCycle.new(1, 1, 1, 0)
	endless.start()
	for i in 10:
		endless.end_turn()
	check(not endless.is_finished and endless.cycle_number == 11, "cycles 0: cycles end, the match does not")


func test_first_seat() -> void:
	var turns := TurnCycle.new(3, 1)
	turns.start(2)
	check(turns.round_order() == ([2, 0, 1] as Array[int]), "a round starts at first_seat: %s" % [turns.round_order()])
	turns.first_seat = 1
	turns.end_turn()
	check(turns.current_seat == 0, "a new first_seat waits for the next round")
	turns.end_turn()
	turns.end_turn()
	check(turns.current_seat == 1, "the next round starts at the new first_seat")


func test_inactive_seats() -> void:
	var turns := TurnCycle.new(3, 1)
	turns.set_seat_active(1, false)
	turns.start()
	turns.end_turn()
	check(turns.current_seat == 2, "an inactive seat is skipped")
	turns.set_seat_active(1, true)
	turns.end_turn()
	check(turns.current_seat == 0 and turns.round_number == 2, "back on: plays from the next round")
	turns.end_turn()
	check(turns.current_seat == 1, "seat 1 plays in round 2")
	turns.set_seat_active(2, false)
	turns.end_turn()
	check(turns.current_seat == 0, "a seat made inactive mid-round is skipped too")
	var alone := TurnCycle.new(1, 1)
	alone.start()
	alone.set_seat_active(0, false)
	alone.end_turn()
	check(alone.is_finished, "no active seat: the match ends")


func test_to_dict_round_trip() -> void:
	var turns := TurnCycle.new(3, 3, 2, 3)
	turns.set_seat_active(2, false)
	turns.start(1)
	turns.spend_action()
	turns.end_turn()
	turns.end_turn()
	turns.spend_action(2)
	var copy := TurnCycle.from_dict(turns.to_dict())
	check(copy.to_dict() == turns.to_dict(), "from_dict(to_dict()) is the same state")
	turns.end_turn()
	copy.end_turn()
	check(copy.to_dict() == turns.to_dict(), "and both go on the same way")
	check(copy.current_seat == turns.current_seat and copy.actions_left == 3, "same next turn")


func test_bad_numbers() -> void:
	var turns := TurnCycle.new(3, 1)
	turns.first_seat = -1
	turns.start()
	check(turns.current_seat == 2, "a negative first_seat wraps: -1 is the last seat (%d)" % turns.current_seat)
	turns.first_seat = 7
	turns.end_turn()
	turns.end_turn()
	turns.end_turn()
	check(turns.current_seat == 1, "past the last seat wraps too: 7 of 3 is 1 (%d)" % turns.current_seat)
	turns.seats = 0
	turns.end_turn()
	turns.end_turn()
	turns.end_turn()
	check(turns.is_finished, "no seats left: the match ends, no division by zero")
