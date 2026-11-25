extends "res://addons/turn_kit/tests/turn_test.gd"

## TurnClock and TurnSeat in a tree: seats from the children, inspector values, seat signals, use_cycle, warnings.


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
