extends "res://addons/turn_kit/tests/turn_test.gd"

## TurnCycle alone: phases, the time of a turn and to_dict / from_dict with all of it.


func _record(turns: TurnCycle) -> Array[String]:
	var events: Array[String] = []
	turns.turn_started.connect(func(seat: int) -> void: events.append("start %d" % seat))
	turns.action_spent.connect(func(left: int) -> void: events.append("spent %d" % left))
	turns.turn_ended.connect(func(seat: int) -> void: events.append("end %d" % seat))
	turns.round_ended.connect(func(n: int) -> void: events.append("round %d" % n))
	turns.cycle_ended.connect(func(n: int) -> void: events.append("cycle %d" % n))
	turns.finished.connect(func() -> void: events.append("finished"))
	return events


func _record_all(turns: TurnCycle) -> Array[String]:
	var events := _record(turns)
	turns.phase_started.connect(func(phase: StringName) -> void: events.append("phase+ %s" % phase))
	turns.phase_ended.connect(func(phase: StringName) -> void: events.append("phase- %s" % phase))
	turns.turn_timed_out.connect(func(seat: int) -> void: events.append("timeout %d" % seat))
	return events


func test_phases_signal_order() -> void:
	var turns := TurnCycle.new(2, 1, 1, 1)
	turns.phases = [&"draw", &"play"]
	var events := _record_all(turns)
	turns.start()
	check(turns.current_phase == &"draw" and turns.phase_index == 0, "a turn starts in the first phase")
	check(turns.next_phase() and turns.current_phase == &"play" and turns.phase_index == 1, "next phase")
	check(turns.next_phase(), "the last phase closes the turn")
	check(turns.current_seat == 1 and turns.current_phase == &"draw", "the next turn starts in the first phase")
	turns.end_turn()
	var expected: Array[String] = [
		"start 0",
		"phase+ draw",
		"phase- draw",
		"phase+ play",
		"phase- play",
		"end 0",
		"start 1",
		"phase+ draw",
		"phase- draw",
		"end 1",
		"round 1",
		"cycle 1",
		"finished"
	]
	check(events == expected, "signals in order: %s" % [events])
	check(turns.current_phase == &"" and turns.phase_index == -1, "no phase after the end")
	check(not turns.next_phase(), "no next phase after the end")


func test_phases_round_change() -> void:
	var turns := TurnCycle.new(2, 1)
	turns.phases = [&"a", &"b"]
	var events := _record_all(turns)
	turns.start()
	turns.end_turn()
	events.clear()
	turns.end_turn()
	var expected: Array[String] = ["phase- a", "end 1", "round 1", "start 0", "phase+ a"]
	check(events == expected, "end_turn from any phase, then the next turn: %s" % [events])


func test_next_phase_without_phases() -> void:
	var turns := TurnCycle.new(2, 1)
	check(not turns.next_phase(), "no turn in play: false")
	var events := _record_all(turns)
	turns.start()
	check(turns.next_phase() and turns.current_seat == 1, "without phases it is end_turn()")
	var expected: Array[String] = ["start 0", "end 0", "start 1"]
	check(events == expected, "and no phase signal: %s" % [events])


func test_phases_change_counts_from_next_turn() -> void:
	var turns := TurnCycle.new(2, 1)
	turns.phases = [&"a", &"b"]
	turns.start()
	turns.phases = [&"x"]
	check(turns.current_phase == &"a", "the turn in play keeps its phase")
	check(turns.next_phase() and turns.current_phase == &"b", "and its own list")
	turns.next_phase()
	check(turns.current_seat == 1 and turns.current_phase == &"x", "the next turn uses the new list")
	turns.phases = []
	turns.next_phase()
	check(turns.current_seat == 0 and turns.current_phase == &"" and turns.phase_index == -1, "no phases again")
	var plain := TurnCycle.new(2, 2)
	plain.start()
	plain.phases = [&"a"]
	check(plain.current_phase == &"" and plain.next_phase() and plain.current_seat == 1, "phases added mid-turn wait")
	check(plain.current_phase == &"a", "and start at the next turn")


func test_actions_belong_to_the_turn() -> void:
	var turns := TurnCycle.new(2, 2)
	turns.phases = [&"a", &"b"]
	turns.start()
	turns.spend_action()
	turns.next_phase()
	check(turns.actions_left == 1, "an action spent in a phase stays spent in the next")
	check(turns.spend_action() and not turns.spend_action(), "the turn has 2 in all")


func test_time_tick() -> void:
	var turns := TurnCycle.new(2, 1)
	turns.turn_seconds = 10.0
	turns.tick(5.0)
	check(turns.time_left == 0.0, "no tick before start")
	turns.start()
	check(turns.time_left == 10.0, "the turn loads its time")
	turns.tick(4.0)
	check(is_equal_approx(turns.time_left, 6.0) and turns.current_seat == 0, "a partial tick")
	turns.tick(0.0)
	turns.tick(-3.0)
	check(is_equal_approx(turns.time_left, 6.0), "a delta <= 0 does nothing")
	var events := _record_all(turns)
	turns.tick(6.0)
	check(
		events == (["timeout 0", "end 0", "start 1"] as Array[String]), "exactly 0: timeout, end, next: %s" % [events]
	)
	check(turns.current_seat == 1 and turns.time_left == 10.0, "the next turn loads its time again")


func test_time_overshoot_and_once() -> void:
	var turns := TurnCycle.new(2, 1)
	turns.turn_seconds = 10.0
	turns.start()
	turns.tick(25.0)
	check(turns.current_seat == 1 and turns.time_left == 10.0, "the extra delta does not carry over")
	turns.timeout_ends_turn = false
	turns.end_turn()
	var events := _record_all(turns)
	turns.tick(10.0)
	turns.tick(5.0)
	turns.tick(5.0)
	check(events == (["timeout 0"] as Array[String]), "one timeout per turn: %s" % [events])
	check(turns.current_seat == 0 and turns.time_left == 0.0, "without timeout_ends_turn the turn stays")
	check(turns.spend_action(), "and can still play")
	turns.end_turn()
	turns.tick(10.0)
	check(events.count("timeout 1") == 1 and turns.current_seat == 1, "the next turn times out again")


func test_time_off_and_finished() -> void:
	var turns := TurnCycle.new(1, 1, 1, 1)
	turns.start()
	var events := _record_all(turns)
	turns.tick(100.0)
	check(events.is_empty() and turns.time_left == 0.0, "turn_seconds 0: no time")
	turns.turn_seconds = 5.0
	turns.tick(100.0)
	check(events.is_empty(), "a change waits for the next turn")
	turns.end_turn()
	check(turns.is_finished and turns.time_left == 0.0, "finished: no time left")
	events.clear()
	turns.tick(100.0)
	check(events.is_empty(), "no tick after the end")


func test_time_change_mid_turn() -> void:
	var turns := TurnCycle.new(2, 1)
	turns.turn_seconds = 10.0
	turns.start()
	turns.turn_seconds = 0.0
	turns.tick(20.0)
	check(turns.current_seat == 0 and turns.time_left == 10.0, "turn_seconds 0 stops the clock")


func test_time_with_phases() -> void:
	var turns := TurnCycle.new(2, 1)
	turns.phases = [&"a", &"b"]
	turns.turn_seconds = 3.0
	turns.start()
	turns.next_phase()
	turns.tick(1.0)
	check(is_equal_approx(turns.time_left, 2.0) and turns.current_phase == &"b", "time belongs to the turn")
	var events := _record_all(turns)
	turns.tick(2.0)
	check(events.slice(0, 3) == (["timeout 0", "phase- b", "end 0"] as Array[String]), "timeout ends it: %s" % [events])


func test_timeout_listener_ends_the_turn() -> void:
	var turns := TurnCycle.new(3, 1)
	turns.turn_seconds = 2.0
	turns.timeout_ends_turn = true
	var hook := func(_seat: int) -> void: turns.end_turn()
	turns.turn_timed_out.connect(hook)
	turns.start()
	turns.tick(2.0)
	check(turns.current_seat == 1, "a listener that ends the turn: the cycle does not end a second one")
	turns.turn_timed_out.disconnect(hook)


func test_to_dict_all_state_round_trip() -> void:
	var turns := TurnCycle.new(3, 2, 2, 3)
	turns.first_seat_rotates = true
	turns.phases = [&"draw", &"play", &"end"]
	turns.turn_seconds = 8.0
	turns.set_seat_active(2, false)
	turns.start()
	turns.set_round_order([1, 0, 2])
	turns.spend_action()
	turns.next_phase()
	turns.tick(2.5)
	var copy := TurnCycle.from_dict(turns.to_dict())
	check(copy.to_dict() == turns.to_dict(), "mid-turn, mid-phase, time running: the same state")
	check(copy.current_phase == &"play" and is_equal_approx(copy.time_left, 5.5), "phase and time come back")
	check(copy.custom_round_order() == ([1, 0, 2] as Array[int]), "and the order of your own")
	var a: Array[String] = []
	var b: Array[String] = []
	turns.phase_started.connect(func(phase: StringName) -> void: a.append(str(phase)))
	copy.phase_started.connect(func(phase: StringName) -> void: b.append(str(phase)))
	for step in 30:
		match step % 4:
			0:
				turns.tick(1.5)
				copy.tick(1.5)
			1:
				turns.next_phase()
				copy.next_phase()
			2:
				turns.spend_action()
				copy.spend_action()
			3:
				turns.end_turn()
				copy.end_turn()
		check(copy.to_dict() == turns.to_dict(), "step %d: both give the same state" % step)
	check(a == b and not a.is_empty(), "and the same signals")


func test_to_dict_timed_out_round_trip() -> void:
	var turns := TurnCycle.new(2, 1)
	turns.turn_seconds = 4.0
	turns.timeout_ends_turn = false
	turns.start()
	turns.tick(4.0)
	var copy := TurnCycle.from_dict(turns.to_dict())
	var heard: Array[int] = []
	copy.turn_timed_out.connect(func(seat: int) -> void: heard.append(seat))
	copy.tick(1.0)
	check(heard.is_empty() and not copy.timeout_ends_turn, "a timeout already given is not given twice")


func test_from_dict_0_2() -> void:
	var old := {
		"seats": 3,
		"actions_per_turn": 3,
		"rounds_per_cycle": 2,
		"cycles": 0,
		"first_seat": 0,
		"current_seat": 1,
		"actions_left": 2,
		"round_number": 1,
		"cycle_number": 1,
		"rounds_in_cycle": 0,
		"is_started": true,
		"is_finished": false,
		"inactive": [],
		"order": [0, 1, 2],
		"index": 1,
	}
	var turns := TurnCycle.from_dict(old)
	check(turns.current_seat == 1 and turns.actions_left == 2 and turns.actions_per_turn == 3, "the old state loads")
	check(turns.current_phase == &"" and turns.phase_index == -1 and turns.time_left == 0.0, "nothing new is on")
	check(turns.round_first_seat == 0 and not turns.first_seat_rotates, "the opener is read from the order")
	turns.end_turn()
	turns.tick(5.0)
	turns.end_turn()
	check(turns.round_number == 2 and turns.current_seat == 0, "and it plays on")
	check(TurnCycle.from_dict({}).actions_per_turn == 1, "an empty dict has the new default")


func test_phase_signals_come_in_pairs() -> void:
	var turns := TurnCycle.new(2, 1)
	turns.phases = [&"a", &"b"]
	var events := _record_all(turns)
	var hook := func(seat: int) -> void:
		if seat == 1:
			turns.end_turn()
	turns.turn_started.connect(hook)
	turns.start()
	turns.end_turn()
	var expected: Array[String] = [
		"start 0", "phase+ a", "phase- a", "end 0", "start 1", "end 1", "round 1", "start 0", "phase+ a"
	]
	check(events == expected, "a turn closed from turn_started has no phase signals: %s" % [events])
	var open: Dictionary[String, bool] = {}
	var balanced := true
	for event in events:
		if event.begins_with("phase+ "):
			open[event.substr(7)] = true
		elif event.begins_with("phase- "):
			balanced = balanced and open.has(event.substr(7))
			open.erase(event.substr(7))
	check(balanced, "every phase_ended has its phase_started before")
	turns.turn_started.disconnect(hook)
	var copy := TurnCycle.from_dict(turns.to_dict())
	check(copy.to_dict() == turns.to_dict(), "the open phase survives to_dict")
