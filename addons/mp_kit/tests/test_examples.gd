extends "res://addons/mp_kit/tests/mp_test.gd"

## The minimal example (examples/minimal_2d) stays what the setup wizard writes: the wizard's player script, a
## predicted MpActor with its saved MpSync, an MpInput, and an MpWorld whose player and seats match game.tres.
## Played over the network by mpkit_lab/run/minimal.sh. The bots example (examples/bots_2d), played solo here: its flow waits
## for the host and takes late players, and a bot walks every free seat with the player's own movement. The sports example
## (examples/sports_2d), its saved sync and a solo run: a slide, a dribble, a kick and a goal; over the network by
## mpkit_lab/run/sports.sh.

const DIR := "res://addons/mp_kit/examples/minimal_2d"


func test_minimal_2d_is_the_wizard_game() -> void:
	var templates := load("res://addons/mp_kit/editor/mp_setup_templates.gd") as GDScript
	var script_text := FileAccess.get_file_as_string(DIR.path_join("player.gd"))
	check(script_text == templates.call(&"player_script", false), "player.gd is the wizard's 2D player script")
	var game := load(DIR.path_join("game.tres")) as Resource
	check(game.get(&"boot_scene") == DIR.path_join("boot.tscn"), "game.tres names its boot scene")
	check(game.get(&"world_scene") == DIR.path_join("world.tscn"), "and its world")
	var player := (load(DIR.path_join("player.tscn")) as PackedScene).instantiate()
	var actor := player.get_node(^"MpActor")
	check(actor.get(&"predict") == true and actor.get_node_or_null(^"MpSync") != null, "a predicted MpActor with its saved MpSync")
	check(player.get_node_or_null(^"MpInput") != null, "an MpInput")
	player.free()
	var world := (load(DIR.path_join("world.tscn")) as PackedScene).instantiate()
	var mp_world := world.get_node(^"MpWorld")
	var spawns := (mp_world.get(&"player_scene") as PackedScene).resource_path
	check(spawns == DIR.path_join("player.tscn"), "the MpWorld spawns that player (%s)" % spawns)
	check(mp_world.get(&"seats") == game.get(&"max_players"), "one seat per player")
	world.free()


func test_bots_2d_fills_the_free_seats() -> void:
	const BOTS := "res://addons/mp_kit/examples/bots_2d"
	var boot := (load(BOTS.path_join("boot.tscn")) as PackedScene).instantiate()
	var flow := boot.get_node(^"Flow")
	check(flow.get(&"start_on_timeout") == false and flow.get(&"late_join") == true and flow.get(&"host_can_start") == true,
		"its flow waits for the host, who may start it, and takes late players")
	boot.free()
	var game := load(BOTS.path_join("game.tres")) as Resource
	var world := (load(BOTS.path_join("world.tscn")) as PackedScene).instantiate()
	check(world.get_node(^"MpWorld").get(&"seats") == game.get(&"max_players"), "one seat per player (%d)" % int(game.get(&"max_players")))
	tree.root.add_child(world)
	await tree.physics_frame
	var actors := world.get_node(^"MpWorld/Actors")
	var starts := {}
	for slot in range(2, 5):
		var pawn := actors.get_node_or_null("Pawn_%d" % slot) as Node2D
		check(pawn != null and pawn.has_node(^"Bot"), "seat %d, nobody's in solo, has a pawn with a bot" % slot)
		if pawn:
			starts[slot] = pawn.global_position
	check(actors.get_node_or_null(^"Pawn_1") != null and not actors.get_node(^"Pawn_1").has_node(^"Bot"), "this player's seat has no bot")
	for i in 60:
		await tree.physics_frame
	var walked := 0
	for slot in starts.keys():
		var pawn := actors.get_node("Pawn_%d" % slot) as Node2D
		if pawn.global_position.distance_to(starts[slot]) > 40.0:
			walked += 1
	check(walked == starts.size(), "every bot walked with the player's mp_move (%d of %d)" % [walked, starts.size()])
	world.free()


func test_sports_2d_is_saved_for_prediction() -> void:
	const SPORTS := "res://addons/mp_kit/examples/sports_2d"
	var game := load(SPORTS.path_join("game.tres")) as Resource
	check(game.get(&"max_players") == 4, "two against two")
	var boot := (load(SPORTS.path_join("boot.tscn")) as PackedScene).instantiate()
	check(boot.get_node(^"Flow").get(&"start_seats") == 0, "its flow waits for every seat (the default)")
	boot.free()
	for scene: String in ["player.tscn", "ball.tscn"]:
		var node := (load(SPORTS.path_join(scene)) as PackedScene).instantiate()
		var actor := node.get_node(^"MpActor") as MpActor
		var sync := actor.get_node(^"MpSync") as MultiplayerSynchronizer
		var saved := MpSyncBuilder.matches(sync.replication_config, actor.sync_entries(), MpActorSync.spawn_only(actor), MpActorSync.always(actor))
		check(saved, "%s's saved MpSync is what this kit sends" % scene)
		if scene == "player.tscn":
			check(actor.predict and actor.sync_extra.has("slide_ticks") and actor.sync_extra.has("facing"), "the player predicts, with its slide in sync_extra")
			check(sync.replication_config.property_get_replication_mode(^".:slide_ticks") == SceneReplicationConfig.REPLICATION_MODE_ALWAYS, "which rides with the pose")
		else:
			check(not actor.predict and actor.smoothing == MpActor.Smoothing.BUFFERED, "the ball is the server's, drawn buffered")
		node.free()


func test_sports_2d_solo_slide_dribble_and_goal() -> void:
	const SPORTS := "res://addons/mp_kit/examples/sports_2d"
	var pitch := (load(SPORTS.path_join("pitch.tscn")) as PackedScene).instantiate()
	tree.root.add_child(pitch)
	await tree.physics_frame
	await tree.physics_frame
	var player := pitch.get_node_or_null(^"MpWorld/Actors/Pawn_1") as CharacterBody2D
	var ball := pitch.get_node(^"Ball") as Node2D
	check(player != null, "this player's seat has its pawn")
	if player == null:
		pitch.free()
		return
	Input.action_press(&"ui_select")
	await tree.physics_frame
	await tree.physics_frame
	Input.action_release(&"ui_select")
	check(int(player.get(&"slide_ticks")) > 0 and player.velocity.length() > 400.0, "Space slides (%.0f px/s)" % player.velocity.length())
	for i in 60:
		await tree.physics_frame
	Input.action_press(&"ui_right")
	var held_at := -1
	for i in 240:
		await tree.physics_frame
		if int(ball.get(&"holder")) == 1:
			held_at = i
			break
	check(held_at >= 0, "running into the ball takes it")
	for i in 20:
		await tree.physics_frame
	check(ball.position.distance_to(player.position) < 30.0, "and it stays at the feet while it runs")
	var state := MpState.of(pitch)
	Input.action_press(&"ui_accept")
	await tree.physics_frame
	await tree.physics_frame
	Input.action_release(&"ui_accept")
	Input.action_release(&"ui_right")
	check(int(ball.get(&"holder")) == 0, "Enter kicks it")
	var scored := false
	for i in 120:
		await tree.physics_frame
		if int(state.get_value(&"home", 0)) == 1:
			scored = true
			break
	check(scored, "into the right goal: home scores")
	await tree.physics_frame
	check(ball.position.distance_to(Vector2(480, 270)) < 1.0 and player.position.distance_to(Vector2(220, 270)) < 1.0, "and a kickoff puts everybody back")
	pitch.free()
