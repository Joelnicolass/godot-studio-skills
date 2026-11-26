extends "res://addons/mp_kit/tests/mp_test.gd"

## MpOrders on this machine (solo: the server and the only seat): moves judged, numbered and applied, refused with the
## judge's reason, moves for another seat (a bot), a new match, and a hash that differs from the server's.


func _orders() -> MpOrders:
	var orders := MpOrders.new()
	tree.root.add_child(orders)
	return orders


func test_moves_are_judged_numbered_and_applied() -> void:
	var orders := _orders()
	var log: Array = []
	orders.began.connect(func(start: Dictionary) -> void: log.append("began %s" % start.get("seed")))
	orders.applied.connect(
		func(seq: int, slot: int, move: StringName, args: Array) -> void:
			log.append("%d %d %s %s" % [seq, slot, move, args])
	)
	orders.rejected.connect(
		func(move: StringName, _args: Array, reason: String) -> void: log.append("no %s: %s" % [move, reason])
	)
	orders.judge = func(slot: int, move: StringName, args: Array) -> String:
		if move == &"place" and args.size() == 1 and int(args[0]) < 9:
			return ""
		return "not a cell" if move == &"place" else "unknown move (seat %d)" % slot
	orders.begin({"seed": 7})
	orders.submit(&"place", [4])
	orders.submit(&"place", [12])
	orders.submit(&"fly", [])
	orders.submit_as(2, &"place", [0])
	check(
		log == ["began 7", "1 1 place [4]", "no place: not a cell", "no fly: unknown move (seat 1)", "2 2 place [0]"],
		"in order, refusals only to the seat (%s)" % [log]
	)
	check(orders.last_seq() == 2 and orders.start() == {"seed": 7}, "two moves since the start")
	var moves := orders.moves()
	check(
		moves.size() == 2 and moves[1] == {"slot": 2, "name": &"place", "args": [0]},
		"the moves, to save (%s)" % [moves]
	)
	orders.begin({"seed": 8})
	check(orders.last_seq() == 0 and log[-1] == "began 8", "a new match starts the moves again")
	orders.free()


func test_no_judge_takes_every_move() -> void:
	var orders := _orders()
	var count := [0]
	orders.applied.connect(func(_s: int, _p: int, _m: StringName, _a: Array) -> void: count[0] += 1)
	orders.submit(&"anything", [1, "two", Vector2i(3, 4)])
	check(count[0] == 1 and orders.moves()[0]["args"] == [1, "two", Vector2i(3, 4)], "taken, args as sent")
	orders.free()


func test_a_hash_that_differs_says_desynced_once() -> void:
	var orders := _orders()
	var mine := [10]
	orders.state_hash = func() -> int: return mine[0]
	var seen: Array = []
	orders.desynced.connect(func(seq: int) -> void: seen.append(seq))
	# What a client does with the server's moves (the server's hash rides with each one).
	orders._apply(1, 2, &"place", [1], 10)
	orders._apply(2, 1, &"place", [2], 11)
	orders._apply(3, 2, &"place", [3], 12)
	check(seen == [2], "the first move whose hash differs, once (%s)" % [seen])
	orders._apply(5, 1, &"place", [5], 10)
	check(orders.last_seq() == 3, "a move out of order is not applied")
	orders.free()
