extends "res://addons/mp_kit/tests/mp_test.gd"

## The custom tunnel between a real server and client (ENet, in this process, each under its own SceneMultiplayer):
## a client that sends faster than custom_limit loses nothing (its messages wait their turn), what the server refuses
## anyway comes back to the client as custom_refused, a client refuses a message too big or with no seat before
## sending it, a peer the server cuts gets nothing more sent to it, and nothing goes to a client that is leaving when
## two leave at once.

const PORT := 7796
const WAIT_MS := 6000


## Catches the engine's errors whose text has `needle` (ENet's "max channels" when something is sent to a peer it is
## already closing).
class Catch:
	extends Logger
	var needle := ""
	var seen: Array[String] = []
	var _lock := Mutex.new()

	func _log_error(
		_function: String,
		_file: String,
		_line: int,
		code: String,
		rationale: String,
		_editor_notify: bool,
		_error_type: int,
		_script_backtraces: Array[ScriptBacktrace],
	) -> void:
		var text := rationale + " " + code
		if needle.is_empty() or text.contains(needle):
			_lock.lock()
			seen.append(text)
			_lock.unlock()

	func take() -> Array[String]:
		_lock.lock()
		var out := seen.duplicate()
		seen.clear()
		_lock.unlock()
		return out


## A server and `clients` client MpKits on `PORT`, each in its own branch with its own SceneMultiplayer; every client
## has its slot. All use custom_limit (`rate` a second, `burst` at once).
func _pair(rate: float, burst: float, clients: int = 1) -> Array:
	var kits: Array = []
	var sides := ["PacingServer"]
	for i in clients:
		sides.append("PacingClient%d" % (i + 1))
	for side: String in sides:
		var branch := Node.new()
		branch.name = side
		tree.root.add_child(branch)
		tree.set_multiplayer(SceneMultiplayer.new(), branch.get_path())
		var kit: Node = load("res://addons/mp_kit/mp_kit.gd").new()
		kit.name = "MpKit"
		branch.add_child(kit)
		kit.configure(PORT, 4)
		kit.custom_limit = MpRateLimit.new(rate, burst)
		kits.append(kit)
	var server: Node = kits[0]
	check(server.host() == OK, "the server listens")
	for client: Node in kits.slice(1):
		check(client.join("127.0.0.1", PORT) == OK, "a client connects")
	await _until(func() -> bool: return kits.slice(1).all(func(c: Node) -> bool: return c.local_slot() > 0))
	for client: Node in kits.slice(1):
		check(client.local_slot() > 0, "a client got its slot (%d)" % client.local_slot())
	return kits


func _until(done: Callable, wait_ms: int = WAIT_MS) -> void:
	var end := Time.get_ticks_msec() + wait_ms
	while not done.call() and Time.get_ticks_msec() < end:
		await tree.process_frame


func _done(kits: Array) -> void:
	for kit: Node in kits:
		kit.leave()
	await tree.process_frame
	for kit: Node in kits:
		var branch := kit.get_parent()
		tree.set_multiplayer(null, branch.get_path())
		branch.free()


func test_a_client_that_sends_too_fast_loses_nothing() -> void:
	var kits: Array = await _pair(200.0, 20.0)
	var server: Node = kits[0]
	var client: Node = kits[1]
	var got: Array = []
	var refused: Array = []
	server.custom_received.connect(
		func(_channel: StringName, data: Dictionary, from_peer: int) -> void:
			if from_peer != 1:
				got.append(int(data["n"]))
	)
	client.custom_refused.connect(func(_c: StringName, _d: Dictionary, reason: String) -> void: refused.append(reason))
	for n in 150:
		client.send_custom(&"orders", {"n": n})
	check(
		client._custom_outbox.size() > 100, "past its turn they wait on the client (%d)" % client._custom_outbox.size()
	)
	await _until(func() -> bool: return got.size() >= 150)
	var in_order := range(150)
	check(got == in_order, "the server got all 150, in order (%d)" % got.size())
	check(refused.is_empty(), "nothing refused (%s)" % [refused])
	await _done(kits)


func test_what_the_server_refuses_comes_back_to_the_client() -> void:
	var kits: Array = await _pair(5.0, 10.0)
	var server: Node = kits[0]
	var client: Node = kits[1]
	var got: Array = []
	var refused: Array = []
	server.custom_received.connect(
		func(_channel: StringName, data: Dictionary, from_peer: int) -> void:
			if from_peer != 1:
				got.append(int(data.get("n", -1)))
	)
	client.custom_refused.connect(
		func(channel: StringName, data: Dictionary, reason: String) -> void: refused.append([channel, data, reason])
	)
	# A client that does not pace itself (an old one, a modified one): straight to the server, 30 at once.
	for n in 30:
		client.rpc_custom_to_server.rpc_id(1, "orders", {"n": n})
	await _until(func() -> bool: return got.size() >= 10 and refused.size() >= 10)
	check(
		got.size() >= 10 and got.size() < 30, "the server took its burst and refused the rest (%d taken)" % got.size()
	)
	check(
		not refused.is_empty() and refused.size() <= 20, "the client heard of a few, not one each (%d)" % refused.size()
	)
	var all_rate := refused.all(func(r: Array) -> bool: return r[0] == &"orders" and r[2] == "rate_limited")
	var none_taken := refused.all(func(r: Array) -> bool: return not got.has(int(r[1]["n"])))
	check(
		all_rate and none_taken, "each says its channel, its data and rate_limited, and was not taken (%s)" % [refused]
	)
	# A server that allows less than the client: refused for its size, with no data back.
	refused.clear()
	await _until(func() -> bool: return false, 500)
	server.custom_max_bytes = 64
	client.send_custom(&"orders", {"n": 99, "pad": "x".repeat(200)})
	await _until(func() -> bool: return not refused.is_empty())
	check(refused == [[&"orders", {}, "too_big"]], "too big for the server: too_big, no data back (%s)" % [refused])
	check(not got.has(99), "and it never reached custom_received")
	await _done(kits)


func test_a_client_refuses_before_sending() -> void:
	var kits: Array = await _pair(2.0, 4.0)
	var server: Node = kits[0]
	var client: Node = kits[1]
	var got: Array = []
	var refused: Array = []
	server.custom_received.connect(
		func(_c: StringName, data: Dictionary, _from: int) -> void: got.append(data.get("n"))
	)
	client.custom_refused.connect(
		func(_channel: StringName, data: Dictionary, reason: String) -> void: refused.append([data.get("n"), reason])
	)
	client.send_custom(&"orders", {"n": -1, "pad": "x".repeat(9000)})
	check(refused.is_empty(), "custom_refused comes on the next frame, not inside send_custom")
	await tree.process_frame
	check(refused == [[-1, "too_big"]], "over custom_max_bytes: refused here, with its data (%s)" % [refused])
	refused.clear()
	# 2 a second with a burst of 4 (2 for the client's own pace): two leave, CUSTOM_OUTBOX_MAX wait, the rest is refused.
	var outbox_max: int = client.CUSTOM_OUTBOX_MAX
	for n in outbox_max + 10:
		client.send_custom(&"orders", {"n": n})
	await tree.process_frame
	var waiting: int = client._custom_outbox.size()
	check(waiting <= outbox_max and waiting >= outbox_max - 2, "at most CUSTOM_OUTBOX_MAX wait (%d)" % waiting)
	var all_rate := refused.all(func(r: Array) -> bool: return r[1] == "rate_limited")
	check(
		refused.size() >= 6 and refused.size() <= 8 and all_rate, "the ones past it: rate_limited (%d)" % refused.size()
	)
	client.leave()
	check(client._custom_outbox.is_empty(), "leave() drops what was waiting")
	refused.clear()
	client.join("127.0.0.1", PORT)
	client.send_custom(&"orders", {"n": -7})
	await tree.process_frame
	check(refused == [[-7, "no_seat"]], "connected, before it has a seat: no_seat (%s)" % [refused])
	check(not got.has(-1) and not got.has(-7), "neither reached the server (%s)" % [got])
	await _done(kits)


func test_a_peer_the_server_cuts_gets_nothing_more() -> void:
	var catch := Catch.new()
	catch.needle = "max channels"
	OS.add_logger(catch)
	var kits: Array = await _pair(30.0, 60.0)
	var server: Node = kits[0]
	var client: Node = kits[1]
	var left: Array = []
	server.peer_left.connect(func(peer_id: int, slot: int) -> void: left.append([peer_id, slot]))
	var peer_id: int = server.multiplayer.get_peers()[0]
	var slot: int = server.slot_for_peer(peer_id)
	server._cut_peer(server.multiplayer.multiplayer_peer, peer_id, "test")
	check(left == [[peer_id, slot]], "peer_left at once, with its slot (%s)" % [left])
	check(not server.multiplayer.get_peers().has(peer_id), "the server stops counting it at once")
	# The server keeps beating and broadcasting while ENet closes that connection.
	var end := Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < end:
		server.broadcast_custom(&"tick", {})
		await tree.process_frame
	await _until(func() -> bool: return not client.is_networked())
	check(not client.is_networked(), "the client hears the connection closed")
	check(left.size() == 1, "peer_left once only, also after ENet closed it (%s)" % [left])
	var errors := catch.take()
	OS.remove_logger(catch)
	check(errors.is_empty(), "nothing sent to the closing connection (%s)" % [errors])
	await _done(kits)


func test_nothing_goes_to_a_client_that_leaves_with_another() -> void:
	var catch := Catch.new()
	catch.needle = "max channels"
	OS.add_logger(catch)
	var kits: Array = await _pair(30.0, 60.0, 2)
	var server: Node = kits[0]
	var left: Array = []
	server.peer_left.connect(func(peer_id: int, _slot: int) -> void: left.append(peer_id))
	# The match ended and both quit in the same frame.
	for client: Node in kits.slice(1):
		client.leave()
	await _until(func() -> bool: return left.size() >= 2)
	check(left.size() == 2, "the server saw both leave (%s)" % [left])
	var errors := catch.take()
	OS.remove_logger(catch)
	check(errors.is_empty(), "and sent nothing to the one still closing (%s)" % [errors])
	await _done(kits)
