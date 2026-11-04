extends "res://addons/mp_kit/tests/mp_test.gd"

## MpKit's routed calls (input frames, to_server), solo, no network: each MpInput and MpActor takes its key as it enters the
## tree and gives it back as it leaves, the key is its path, and a frame or a call for a node that is gone (it died:
## MpActor.despawn) is dropped without an error.


func _pawn() -> Node2D:
	var pawn := Node2D.new()
	pawn.name = "RoutePawn"
	var actor := MpActor.new()
	actor.name = "MpActor"
	pawn.add_child(actor)
	var input := MpInput.new()
	input.name = "MpInput"
	pawn.add_child(input)
	tree.root.add_child(pawn)
	return pawn


func test_a_pawn_takes_its_keys_and_gives_them_back() -> void:
	var pawn := _pawn()
	var actor := pawn.get_node("MpActor")
	var input := pawn.get_node("MpInput")
	var actor_key := MpKit.route_key(actor)
	var input_key := MpKit.route_key(input)
	check(actor_key == String(actor.get_path()).hash() and actor_key != input_key, "the key is the node's path (the same on every peer)")
	check(MpKit._route(actor_key) == actor and MpKit._route(input_key) == input, "in the tree: MpKit routes both keys to them")
	pawn.queue_free()
	check(MpKit._route(input_key) == input, "despawned this frame: until the frame ends it is still there and takes its frames")
	await tree.process_frame
	check(not MpKit._routes.has(actor_key) and not MpKit._routes.has(input_key) and MpKit._route(input_key) == null,
		"freed: their keys are gone")


func test_a_late_frame_or_call_for_a_gone_pawn_is_dropped() -> void:
	var pawn := _pawn()
	var actor_key := MpKit.route_key(pawn.get_node("MpActor"))
	var input_key := MpKit.route_key(pawn.get_node("MpInput"))
	pawn.free()
	MpKit.rpc_input_frames(input_key, PackedByteArray([1, 2, 3]))
	MpKit.rpc_actor_call(actor_key, &"recolor", [], 0.0)
	MpKit.rpc_input_slack(input_key, 2)
	MpKit.rpc_input_frames(123456, PackedByteArray())
	check(MpKit._route(input_key) == null and MpKit._route(actor_key) == null, "frames, a to_server call and a slack for a gone pawn (or a key nobody has): dropped, no error")


func test_a_new_pawn_at_the_same_path_takes_the_key() -> void:
	var old := _pawn()
	var key := MpKit.route_key(old.get_node("MpInput"))
	old.free()
	var again := _pawn()
	check(MpKit._route(key) == again.get_node("MpInput"), "the pawn made again with the same name takes the same key")
	again.free()
