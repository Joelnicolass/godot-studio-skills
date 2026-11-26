extends "res://addons/bot_kit/tests/bot_test.gd"

## The three examples, played headless from start to end.

const MINIMAL := "res://addons/bot_kit/examples/minimal_3d/minimal_3d.tscn"
const ARENA := "res://addons/bot_kit/examples/arena_3d/arena_3d.tscn"
const TURN_BASED := "res://addons/bot_kit/examples/turn_based/turn_based.tscn"


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


func _key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	tree.root.push_input(event)


## Every turn until the house is built (at most 200): the ids it chose.
func _play(scene: Node) -> Array[StringName]:
	var villager := scene.get_node(^"%Villager")
	var turns: Array[StringName] = []
	var record := func(choice: BotChoice) -> void: turns.append(choice.id)
	villager.connect(&"acted", record)
	for i in 200:
		if villager.call(&"is_done"):
			break
		scene.call(&"turn")
	villager.disconnect(&"acted", record)
	return turns


func test_turn_based_the_villager_builds_its_house() -> void:
	var scene := (load(TURN_BASED) as PackedScene).instantiate()
	root.add_child(scene)
	var villager := scene.get_node(^"%Villager")
	var brain := scene.get_node(^"%BotBrain") as BotBrain
	check(brain._get_configuration_warnings().is_empty(), "its brain has no warnings")
	_key(KEY_SPACE)
	check(int(villager.get(&"turns")) == 1 and brain.current.id == &"Gather", "Space: one turn, it gathers first")
	check(brain.last_choices.size() == 3, "it weighed its three options")
	var turns := _play(scene)
	check(villager.call(&"is_done"), "the house is built (%d turns)" % villager.get(&"turns"))
	check(turns.has(&"Gather") and turns.has(&"Build") and turns.has(&"Rest"), "it gathered, built and rested")
	check(int(villager.get(&"energy")) >= 0 and int(villager.get(&"wood")) >= 0, "never below 0 energy or wood")
	_key(KEY_N)
	check(near(brain.noise, 0.3), "N: noise")
	_key(KEY_R)
	var noisy := _play(scene)
	_key(KEY_R)
	check(int(villager.get(&"turns")) == 0 and brain.current == null, "R: the first turn again")
	check(_play(scene) == noisy, "the same seed plays the same turns, noise and all")
	_key(KEY_R)
	_key(KEY_A)
	check(brain.auto_think, "A: turns on their own")
	await tree.create_timer(1.0).timeout
	check(int(villager.get(&"turns")) >= 2, "it took turns on its own (%d)" % villager.get(&"turns"))
	await tree.process_frame
	check(not (scene.get_node(^"%Help") as Label).text.is_empty(), "the screen says the keys")
