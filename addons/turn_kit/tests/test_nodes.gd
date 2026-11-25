extends "res://addons/turn_kit/tests/turn_test.gd"

## TurnClock and TurnSeat in a tree: seats from the children, inspector values, seat signals, use_cycle, phases, turn
## time, warnings.


func _build(names: Array[String]) -> TurnClock:
	var clock := TurnClock.new()
	clock.autostart = false
	for name in names:
		var seat := TurnSeat.new()
		seat.name = name
		seat.display_name = name
		clock.add_child(seat)
	tree.root.add_child(clock)
	return clock


func test_seats_are_children() -> void:
	var clock := _build(["A", "B", "C"])
	clock.actions_per_turn = 2
	clock.start()
	check(clock.turn_cycle.seats == 3, "one seat per TurnSeat child")
	check(clock.current_seat == 0 and clock.actions_left == 2, "inspector actions: %d" % clock.actions_left)
	check(clock.current_seat_node().display_name == "A", "the current seat node")
	check((clock.get_node(^"B") as TurnSeat).index() == 1, "a seat's index is its place")
	check(clock.spend_action() and clock.actions_left == 1, "spend goes to the cycle")
	clock.end_turn()
	check((clock.get_node(^"B") as TurnSeat).is_current(), "B plays")
	clock.free()


func test_seat_signals() -> void:
	var clock := _build(["A", "B"])
	var heard: Array[String] = []
	var b := clock.get_node(^"B") as TurnSeat
	b.turn_started.connect(func() -> void: heard.append("B start"))
	b.turn_ended.connect(func() -> void: heard.append("B end"))
	clock.turn_started.connect(func(seat: int) -> void: heard.append("clock %d" % seat))
	clock.start()
	clock.end_turn()
	clock.end_turn()
	var expected: Array[String] = ["clock 0", "clock 1", "B start", "B end", "clock 0"]
	check(heard == expected, "clock and seat signals: %s" % [heard])
	clock.free()


func test_inactive_seat_node() -> void:
	var clock := _build(["A", "B", "C"])
	(clock.get_node(^"B") as TurnSeat).active = false
	clock.start()
	clock.end_turn()
	check(clock.current_seat == 2, "a seat with active off is skipped")
	(clock.get_node(^"B") as TurnSeat).active = true
	clock.end_turn()
	clock.end_turn()
	check(clock.current_seat == 1, "back on: it plays the next round")
	clock.free()


func test_autostart() -> void:
	var clock := TurnClock.new()
	var seat := TurnSeat.new()
	clock.add_child(seat)
	var started: Array[int] = []
	clock.turn_started.connect(func(s: int) -> void: started.append(s))
	tree.root.add_child(clock)
	check(started.is_empty(), "autostart waits until the scene is ready")
	await tree.process_frame
	check(started == ([0] as Array[int]), "then the first turn starts")
	clock.free()


func test_use_cycle() -> void:
	var clock := _build(["A", "B"])
	var rules := TurnCycle.new(2, 5)
	clock.use_cycle(rules)
	var heard: Array[int] = []
	clock.turn_started.connect(func(s: int) -> void: heard.append(s))
	rules.start(1)
	check(clock.current_seat == 1 and clock.actions_left == 5, "the clock shows the rules' cycle")
	check(heard == ([1] as Array[int]), "and relays its signals")
	clock.actions_per_turn = 2
	check(rules.actions_per_turn == 5, "the inspector does not touch a cycle it does not own")
	clock.use_own_cycle()
	rules.end_turn()
	check(heard == ([1] as Array[int]), "back to its own cycle: the old one is not heard")
	clock.free()


func test_warnings() -> void:
	var empty := TurnClock.new()
	check(empty._get_configuration_warnings().size() == 1, "no seats: a warning")
	empty.first_seat = 3
	check(empty._get_configuration_warnings().size() == 2, "first_seat past the seats: another")
	empty.free()
	var clock := _build(["A"])
	check(clock._get_configuration_warnings().is_empty(), "one seat: no warnings")
	var loose := TurnSeat.new()
	check(loose._get_configuration_warnings().size() == 1, "a seat outside a clock warns")
	check(loose.index() == -1 and not loose.is_current(), "and has no index")
	loose.free()
	clock.free()


func test_use_cycle_keeps_a_started_cycle() -> void:
	var rules := TurnCycle.new(2, 3)
	rules.start()
	rules.end_turn()
	rules.end_turn()
	rules.end_turn()
	rules.spend_action()
	var saved := TurnCycle.from_dict(rules.to_dict())
	var clock := TurnClock.new()
	for name: String in ["A", "B"]:
		var seat := TurnSeat.new()
		seat.name = name
		clock.add_child(seat)
	(clock.get_node(^"A") as TurnSeat).active = false
	clock.use_cycle(saved)
	tree.root.add_child(clock)
	await tree.process_frame
	await tree.process_frame
	check(
		saved.round_number == 2 and saved.current_seat == 1,
		"autostart leaves a shown cycle alone: %s" % [saved.to_dict()]
	)
	check(saved.actions_left == 2, "with its actions: %d" % saved.actions_left)
	check(saved.is_seat_active(0), "TurnSeat.active does not touch the rules' seats")
	(clock.get_node(^"B") as TurnSeat).active = false
	check(saved.is_seat_active(1), "not even when it changes")
	clock.start()
	check(saved.round_number == 2 and saved.current_seat == 1, "start() does not restart a started cycle")
	var fresh := TurnCycle.new(2, 4)
	clock.use_cycle(fresh)
	clock.start()
	check(fresh.is_started and fresh.actions_left == 4, "start() starts a shown cycle that has not started")
	clock.free()


func test_rebuilt() -> void:
	var clock := _build(["A", "B"])
	var count := [0]
	clock.rebuilt.connect(func() -> void: count[0] += 1)
	clock.use_cycle(TurnCycle.new(2))
	check(count[0] == 1, "use_cycle emits rebuilt")
	clock.use_own_cycle()
	check(count[0] == 2, "use_own_cycle too")
	clock.start()
	check(count[0] == 3, "and start, which builds the own cycle again")
	clock.free()


func test_inspector_values_reach_the_own_cycle() -> void:
	var clock := TurnClock.new()
	clock.actions_per_turn = 2
	clock.first_seat_rotates = true
	clock.phases = [&"draw", &"play"]
	clock.turn_seconds = 7.5
	clock.timeout_ends_turn = false
	for name in ["A", "B"]:
		clock.add_child(TurnSeat.new())
	var cycle := clock.turn_cycle
	check(cycle.actions_per_turn == 2 and cycle.first_seat_rotates, "actions and rotation")
	check(cycle.phases == ([&"draw", &"play"] as Array[StringName]), "phases")
	check(cycle.turn_seconds == 7.5 and not cycle.timeout_ends_turn, "time")
	clock.turn_seconds = 3.0
	clock.timeout_ends_turn = true
	clock.first_seat_rotates = false
	clock.phases = [&"x"]
	check(cycle.turn_seconds == 3.0 and cycle.timeout_ends_turn and not cycle.first_seat_rotates, "live values")
	check(cycle.phases == ([&"x"] as Array[StringName]), "live phases")
	clock.phases.append(&"y")
	check(cycle.phases.size() == 1, "the cycle keeps its own copy of the phases")
	clock.free()
	var plain := TurnClock.new()
	check(plain.actions_per_turn == 1, "the default is 1 action")
	plain.free()


func test_use_cycle_is_not_touched_by_the_new_values() -> void:
	var clock := _build(["A", "B"])
	var rules := TurnCycle.new(2, 1)
	rules.phases = [&"a"]
	rules.turn_seconds = 9.0
	clock.use_cycle(rules)
	clock.phases = [&"x", &"y"]
	clock.turn_seconds = 1.0
	clock.first_seat_rotates = true
	clock.timeout_ends_turn = false
	check(rules.phases == ([&"a"] as Array[StringName]) and rules.turn_seconds == 9.0, "phases and time stay")
	check(not rules.first_seat_rotates and rules.timeout_ends_turn, "rotation and timeout stay")
	rules.start()
	clock.start()
	check(rules.round_number == 1 and rules.current_phase == &"a", "start() does not restart it")
	clock.use_own_cycle()
	check(
		clock.turn_cycle.phases == ([&"x", &"y"] as Array[StringName]) and clock.turn_cycle.turn_seconds == 1.0, "own"
	)
	clock.free()


func test_phase_and_time_signals_are_relayed() -> void:
	var clock := _build(["A", "B"])
	clock.phases = [&"draw", &"play"]
	clock.turn_seconds = 4.0
	clock.advance_time = false
	var heard: Array[String] = []
	clock.phase_started.connect(func(phase: StringName) -> void: heard.append("+%s" % phase))
	clock.phase_ended.connect(func(phase: StringName) -> void: heard.append("-%s" % phase))
	clock.turn_timed_out.connect(func(seat: int) -> void: heard.append("timeout %d" % seat))
	clock.start()
	check(clock.current_phase == &"draw" and clock.time_left == 4.0, "state on the clock")
	check(clock.next_phase() and clock.current_phase == &"play", "next_phase goes to the cycle")
	clock.tick(4.0)
	var expected: Array[String] = ["+draw", "-draw", "+play", "timeout 0", "-play", "+draw"]
	check(heard == expected, "relayed in order: %s" % [heard])
	check(clock.current_seat == 1, "and the turn passed")
	clock.free()


func test_set_round_order_on_the_clock() -> void:
	var clock := _build(["A", "B", "C"])
	clock.start()
	clock.set_round_order([2, 1])
	clock.end_turn()
	clock.end_turn()
	clock.end_turn()
	check(clock.current_seat == 2 and clock.turn_cycle.round_order() == ([2, 1] as Array[int]), "the order applies")
	clock.free()


func test_process_ticks_only_with_advance_time() -> void:
	var clock := _build(["A", "B"])
	clock.turn_seconds = 10.0
	clock.start()
	check(not Engine.is_editor_hint(), "this is not the editor")
	clock._process(0.5)
	check(is_equal_approx(clock.time_left, 9.5), "_process advances the time: %f" % clock.time_left)
	clock.advance_time = false
	check(not clock.is_processing(), "advance_time off: no processing")
	clock._process(0.5)
	check(is_equal_approx(clock.time_left, 9.5), "and a stray _process does nothing")
	clock.advance_time = true
	check(clock.is_processing(), "advance_time on: processing")
	clock.tick(1.0)
	check(is_equal_approx(clock.time_left, 8.5), "tick() works either way")
	clock._process(8.5)
	check(clock.current_seat == 1, "the time ran out: the turn passed")
	clock.free()


func test_process_time_passes_by_frames() -> void:
	var clock := _build(["A", "B"])
	clock.turn_seconds = 100.0
	clock.start()
	await tree.process_frame
	await tree.process_frame
	check(clock.time_left < 100.0, "frames advance the time: %f" % clock.time_left)
	var shown := TurnCycle.new(2, 1)
	shown.turn_seconds = 100.0
	shown.start()
	clock.use_cycle(shown)
	await tree.process_frame
	check(shown.time_left < 100.0, "a shown cycle is advanced too")
	clock.advance_time = false
	var left := shown.time_left
	await tree.process_frame
	check(shown.time_left == left, "advance_time off: the clock leaves the time to you")
	clock.free()


func test_phase_warnings() -> void:
	var clock := _build(["A"])
	clock.phases = [&"draw", &"play"]
	check(clock._get_configuration_warnings().is_empty(), "good phases: no warning")
	clock.phases = [&"draw", &"draw"]
	check(clock._get_configuration_warnings().size() == 1, "a repeated phase warns")
	clock.phases = [&"draw", &""]
	check(clock._get_configuration_warnings().size() == 1, "an empty phase warns")
	clock.free()
