extends "res://addons/mp_kit/tests/mp_test.gd"

## The minimal example (examples/minimal_2d) stays what the setup wizard writes: the wizard's player script, a
## predicted MpActor with its saved MpSync, an MpInput, and an MpWorld whose player and seats match game.tres.
## Played over the network by mpkit_lab/run/minimal.sh.

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
