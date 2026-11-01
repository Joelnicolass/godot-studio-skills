extends "res://addons/mp_kit/tests/mp_test.gd"

## The pieces around a seat taken late or played by a bot, without the network: a room match's ticket still names its seats
## once it expired (the gate decides, MpMatchAgent.seat_of), the match-start settings that travel to a match on the player's PC
## (MpFlow.fill_match_start, MpLobbyConfig's forwarded fields), and a bot's keys on the server (MpInput.bot_press), which a
## player who takes the seat replaces.


func test_an_expired_ticket_still_names_its_seat() -> void:
	var agent := MpMatchAgent.new()
	agent.auto_start = false
	agent.ticket = {"match_id": "m1", "expires_ms": 1}
	agent._seats = {2: {"sha": MpMatchFiles.sha256("K7P2QX"), "meta": {}, "used": false, "peer": 0}}
	check(agent.seat_of(10, "K7P2QX") == 2, "an expired, never used ticket still names its seat (the gate says match_started)")
	check(agent.seat_of(10, "ZZZZZZ") == 0, "a token of no seat names none")
	agent.finished = true
	check(agent.seat_of(10, "K7P2QX") == 0, "after the match ended no token names a seat")
	agent.free()


func test_the_flow_says_how_a_match_on_this_pc_starts() -> void:
	var flow := MpFlow.new()
	flow.start_on_timeout = false
	flow.late_join = true
	var config := MpLobbyConfig.new()
	flow.fill_match_start(config)
	check(not config.start_on_timeout and config.late_join, "MpFlow's start_on_timeout and late_join go to the match's config")
	for field in ["start_on_timeout", "starter_slot", "late_join"]:
		check(config.agent_fields.has(field), "%s travels to the match process as a flag" % field)
	check(MpLobbyConfig.flag_for("start_on_timeout") == "--start-on-timeout", "the flag of start_on_timeout")
	flow.free()


func _bot_input() -> MpInput:
	var parent := Node2D.new()
	var actor := MpActor.new()
	actor.name = "MpActor"
	actor.owner_slot = 3
	parent.add_child(actor)
	var input := MpInput.new()
	input.name = "MpInput"
	input.actor = actor
	parent.add_child(input)
	tree.root.add_child(parent)
	return input


func test_a_bot_plays_a_seat_nobody_plays() -> void:
	var input := _bot_input()
	check(not input.has_player(), "seat 3 has no player (solo, nobody in it)")
	input.bot_press(&"ui_right", 0.5)
	input.bot_set_value(&"aim", Vector2(4, 2))
	input._advance_remote()
	check(is_equal_approx(input.get_action_strength(&"ui_right"), 128.0 / 255.0), "the bot's key, as a player's would travel")
	check(input.is_action_just_pressed(&"ui_right") and input.get_value(&"aim") == Vector2(4, 2), "just pressed, and its value")
	check(input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down").x > 0.4, "get_vector reads it like a player's")
	input._advance_remote()
	check(input.is_action_pressed(&"ui_right") and not input.is_action_just_pressed(&"ui_right"), "held: pressed, not just pressed")
	input.bot_release(&"ui_right")
	input._advance_remote()
	check(input.is_action_just_released(&"ui_right") and not input.is_action_pressed(&"ui_right"), "released like a player's key")
	input.get_parent().free()


func test_a_player_who_takes_the_seat_replaces_the_bot() -> void:
	var input := _bot_input()
	input.bot_press(&"ui_left")
	input._advance_remote()
	check(input.is_action_pressed(&"ui_left"), "the bot holds ui_left")
	input._follow_owner_peer(9)
	check(not input.is_action_pressed(&"ui_left"), "a player's connection takes the seat: no bot key is held")
	input._follow_owner_peer(0)
	input._advance_remote()
	check(not input.is_action_pressed(&"ui_left"), "the player left: the bot starts with no keys until it presses again")
	input.get_parent().free()
