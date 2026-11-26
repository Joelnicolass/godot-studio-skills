extends "res://addons/mp_kit/tests/mp_test.gd"

## The custom tunnel on a server: a broadcast asked for from a custom_received handler goes out right after the one
## being handled (a turn's result, then a bot's move), an echo is dropped, a chain that never ends stops, and a channel
## not in custom_channels sends nothing.

const PORT := 7797


func _offline(channels := PackedStringArray()) -> Node:
	var kit: Node = load("res://addons/mp_kit/mp_kit.gd").new()
	kit.name = "MpKitUnderTest"
	tree.root.add_child(kit)
	kit.configure(PORT, 4, 1, channels)
	return kit


func _server(channels := PackedStringArray()) -> Node:
	var kit := _offline(channels)
	kit.host()
	return kit


func _done(kit: Node) -> void:
	kit.leave()
	kit.free()


func test_a_broadcast_from_a_handler_goes_out_right_after() -> void:
	var kit := _server()
	check(kit.is_server(), "a listen host")
	var seen: Array = []
	kit.custom_received.connect(
		func(channel: StringName, data: Dictionary, _from_peer: int) -> void:
			seen.append("%s %d" % [channel, data["n"]])
			if channel == &"applied" and data["n"] < 3:
				kit.broadcast_custom(&"applied", {"n": data["n"] + 1})
				kit.broadcast_custom(&"log", {"n": data["n"]})
	)
	kit.broadcast_custom(&"applied", {"n": 0})
	check(
		seen == ["applied 0", "applied 1", "log 0", "applied 2", "log 1", "applied 3", "log 2"],
		"each one right after the one being handled, in the order asked (%s)" % [seen]
	)
	seen.clear()
	kit.broadcast_custom(&"applied", {"n": 3})
	check(seen == ["applied 3"], "and the tunnel is free again afterwards (%s)" % [seen])
	_done(kit)


func test_an_echo_is_dropped() -> void:
	var kit := _server()
	var count := [0]
	kit.custom_received.connect(
		func(channel: StringName, data: Dictionary, _from_peer: int) -> void:
			count[0] += 1
			kit.broadcast_custom(channel, data)  # the naive relay: everything it gets, again
	)
	kit.broadcast_custom(&"emote", {"who": 2, "what": "wave"})
	check(count[0] == 1, "the same channel and data from its own emit go out once (%d)" % count[0])
	_done(kit)


func test_a_chain_that_never_ends_stops() -> void:
	var kit := _server()
	var count := [0]
	var forever := func(_channel: StringName, data: Dictionary, _from_peer: int) -> void:
		count[0] += 1
		kit.broadcast_custom(&"tick", {"n": data["n"] + 1})  # never stops by itself
	kit.custom_received.connect(forever)
	# Prints an error on purpose: the chain is cut.
	kit.broadcast_custom(&"tick", {"n": 0})
	check(count[0] == kit.CUSTOM_CHAIN_MAX, "cut at CUSTOM_CHAIN_MAX broadcasts (%d)" % count[0])
	count[0] = 0
	kit.custom_received.disconnect(forever)
	kit.custom_received.connect(func(_c: StringName, _d: Dictionary, _f: int) -> void: count[0] += 1)
	kit.broadcast_custom(&"tick", {"n": 0})
	check(count[0] == 1, "the next broadcast is a fresh one")
	_done(kit)


func test_a_channel_not_allowed_sends_nothing() -> void:
	var kit := _server(PackedStringArray(["order"]))
	var seen: Array = []
	kit.custom_received.connect(func(channel: StringName, _d: Dictionary, _f: int) -> void: seen.append(channel))
	kit.send_custom(&"order", {})
	kit.send_custom(&"chat", {})  # warns once: not in custom_channels
	kit.broadcast_custom(&"chat", {})
	check(seen == [&"order"], "only the allowed channel (%s)" % [seen])
	_done(kit)


func test_the_sender_seat_with_and_without_network() -> void:
	var kit := _offline()
	var seats: Array = []
	kit.custom_received.connect(
		func(_c: StringName, _d: Dictionary, from_peer: int) -> void: seats.append(kit.slot_of_sender(from_peer))
	)
	kit.send_custom(&"order", {})
	check(seats == [1], "solo: my order comes from my seat (%s)" % [seats])
	kit.host()
	kit.send_custom(&"order", {})
	check(seats == [1, 1], "listen host: its own order comes from its seat (%s)" % [seats])
	check(kit.slot_of_sender(4242) == 0, "a peer with no seat: 0")
	_done(kit)
