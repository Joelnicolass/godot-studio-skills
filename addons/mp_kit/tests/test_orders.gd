extends "res://addons/mp_kit/tests/mp_test.gd"

## MpOrders on this machine (solo: the server and the only seat): moves judged, numbered and applied, refused with the
## judge's reason, moves for another seat (a bot), a new match, a hash that differs from the server's, the history a
## client gets (caught_up when it has it all) and a move the tunnel did not take (rejected with its reason).


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


func test_a_client_says_caught_up_after_the_last_part_of_the_history() -> void:
	var orders := _orders()
	var log: Array = []
	orders.began.connect(func(start: Dictionary) -> void: log.append("began %s" % start.get("seed")))
	orders.applied.connect(
		func(seq: int, _slot: int, _move: StringName, _args: Array) -> void:
			log.append("%d%s" % [seq, " replay" if orders.is_replaying() else ""])
	)
	orders.caught_up.connect(func(seq: int) -> void: log.append("caught up %d %s" % [seq, orders.is_replaying()]))
	# What a client gets when it loads late: the history in parts, the first with the start.
	var first := {"k": "history", "from": 1, "start": {"seed": 3}, "o": [[1, 2, "place", [1], null]], "last": false}
	orders._from_server(first)
	check(log == ["began 3", "1 replay"] and orders.is_replaying(), "the first part: not caught up yet (%s)" % [log])
	orders._from_server({"k": "history", "from": 2, "o": [[2, 1, "place", [2], null]], "last": true})
	var all := ["began 3", "1 replay", "2 replay", "caught up 2 false"]
	check(log == all, "the last part: caught_up(2), once (%s)" % [log])
	orders._from_server({"k": "applied", "s": 3, "p": 2, "n": "place", "a": [3], "h": null})
	check(log[-1] == "3", "a move after it is live (%s)" % [log])
	log.clear()
	orders._from_server({"k": "history", "from": 1, "start": {"seed": 4}, "o": [], "last": true})
	check(log == ["began 4", "caught up 0 false"], "a history with no move yet: caught_up(0) (%s)" % [log])
	orders.free()


func test_a_move_the_tunnel_did_not_take_comes_back_rejected() -> void:
	var orders := _orders()
	var seen: Array = []
	orders.rejected.connect(
		func(move: StringName, args: Array, reason: String) -> void: seen.append([move, args, reason])
	)
	var sent := {"k": "submit", "n": "place", "a": [5]}
	orders._on_refused(&"mp_orders", sent, MpKit.CUSTOM_RATE_LIMITED)
	orders._on_refused(&"other_channel", sent, MpKit.CUSTOM_RATE_LIMITED)
	orders._on_refused(&"mp_orders", {}, MpKit.CUSTOM_TOO_BIG)
	check(seen == [[&"place", [5], "rate_limited"]], "only its own channel's move, with the reason (%s)" % [seen])
	orders.free()
