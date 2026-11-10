extends "res://addons/bot_kit/tests/bot_test.gd"

## Both examples, played headless from start to end.

const MINIMAL := "res://addons/bot_kit/examples/minimal_3d/minimal_3d.tscn"
const ARENA := "res://addons/bot_kit/examples/arena_3d/arena_3d.tscn"


func _seconds(seconds: float) -> void:
	for i in int(seconds * 60.0):
		await tree.physics_frame


func test_minimal_the_robot_hunts_you() -> void:
	var scene := (load(MINIMAL) as PackedScene).instantiate()
	root.add_child(scene)
	var robot := scene.get_node(^"Robot") as Node3D
	var bot := robot.get_node(^"Bot3D") as Bot3D
	var start := robot.global_position
	check(bot.head == robot.get_node(^"Head"), "its head turns to look")
	await _seconds(12.0)
	check(bot.body == robot, "its body is its parent")
	check(robot.global_position.distance_to(start) > 2.0, "the robot walked")
	check(int(scene.get(&"hits")) > 0, "and hit you (%d times)" % int(scene.get(&"hits")))
	bot.show_in_game = true
	await _seconds(0.5)
	var drawn := false
	for child in bot.get_children(true):
		drawn = drawn or child is BotDebug
	check(drawn, "F draws what it thinks")
	check(bot.get_child_count() == 0, "a drawing it never saves (an internal child)")


func test_arena_bots_fight_take_pickups_and_come_back() -> void:
	var scene := (load(ARENA) as PackedScene).instantiate()
	root.add_child(scene)
	var fighters: Array[Node] = scene.call(&"fighters")
	check(fighters.size() == 4, "four fighters")
	var modes := {}
	var weapons := {}
	var deaths := [0]
	for fighter in fighters:
		fighter.connect(&"died", func(_who: Node, _by: Node) -> void: deaths[0] += 1)
	for i in 60 * 60:
		await tree.physics_frame
		if i % 10 != 0:
			continue
		for fighter in fighters:
			var bot := fighter.get_node(^"Bot3D") as Bot3D
			modes[bot.mode] = true
			weapons[fighter.get(&"weapon_name")] = true
	check(modes.has(Bot3D.FIGHT) and modes.has(Bot3D.ROAM), "they fight and roam (%s)" % [modes.keys()])
	check(modes.has(&"Flee"), "hurt, they flee to health (the game's BotMode)")
	check(weapons.has(&"rifle") and weapons.has(&"grenade"), "both weapons used (%s)" % [weapons.keys()])
	check(deaths[0] >= 1, "somebody died (%d)" % deaths[0])
	await _seconds(3.5)
	var alive := 0
	for fighter in fighters:
		alive += 0 if fighter.get(&"dead") else 1
	check(alive >= 3, "and the dead come back (%d alive)" % alive)
