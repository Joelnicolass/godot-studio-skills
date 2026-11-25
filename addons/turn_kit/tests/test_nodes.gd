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
