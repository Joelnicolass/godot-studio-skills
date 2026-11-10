extends "res://addons/bot_kit/tests/bot_test.gd"

## The weapon that suits the distance, the game's own rules on it, and holding fire when none fits.

const World := preload("res://addons/bot_kit/tests/bot_test_world.gd")


func _weapon(name: StringName, min_m: float, max_m: float, score := 1.0) -> BotWeapon:
	var weapon := BotWeapon.new()
	weapon.name = name
	weapon.min_m = min_m
	weapon.max_m = max_m
	weapon.score = score
	return weapon


## A bot with `weapons` that stands, against a standing enemy `distance` m ahead.
func _setup(weapons: Array[BotWeapon], distance: float) -> Array:
	World.arena(root, 60.0)
	var me := World.character(root, Vector3.ZERO)
	me.set(&"walks", false)
	var bot := World.bot_of(me)
	var level := BotDifficulty.new()
	level.reaction_s = 0.0
	level.aim_error_deg = 0.0
	bot.difficulty = level
	bot.weapons = weapons
	var enemy := World.character(root, Vector3(0, 0, -distance), false)
	return [me, bot, enemy]


func test_picks_by_distance_and_score() -> void:
	var shotgun := _weapon(&"shotgun", 0.0, 8.0, 3.0)
	var rifle := _weapon(&"rifle", 0.0, 60.0, 1.0)
	var setup := _setup([shotgun, rifle], 20.0)
	var bot: Bot3D = setup[1]
	var enemy: Node3D = setup[2]
	var picked: Array = []
	bot.weapon_changed.connect(func(weapon: BotWeapon) -> void: picked.append(weapon.name))
	await physics(30)
	check(bot.weapon == rifle, "at 20 m the rifle")
	enemy.position = Vector3(0, 0, -5)
	await physics(30)
	check(bot.weapon == shotgun, "at 5 m the shotgun scores more")
	check(picked == [&"rifle", &"shotgun"], "weapon_changed once per switch (%s)" % [picked])


func test_chance_and_the_games_score() -> void:
	var mine := _weapon(&"mine", 0.0, 30.0, 5.0)
	mine.chance = 0.0
	var rifle := _weapon(&"rifle", 0.0, 60.0, 1.0)
	var setup := _setup([mine, rifle], 10.0)
	var bot: Bot3D = setup[1]
	await physics(60)
	check(bot.weapon == rifle, "chance 0: never switched to")
	var hot := [true]
	bot.weapon_score = func(weapon: BotWeapon, _distance: float, score: float) -> float:
		return 0.0 if weapon == rifle and hot[0] else score
	await physics(30)
	check(not bot.input.is_action_pressed(&"fire"), "its only weapon too hot: it holds fire")
	check(bot.mode == Bot3D.FIGHT, "but keeps fighting")
	hot[0] = false
	await physics(30)
	check(bot.input.is_action_pressed(&"fire"), "cooled, it fires again")


func test_fire_within_and_its_own_distance() -> void:
	var hammer := _weapon(&"hammer", 0.0, 12.0)
	hammer.fire_within_m = 2.0
	hammer.keep_m = 0.8
	var setup := _setup([hammer], 9.0)
	var me: CharacterBody3D = setup[0]
	var bot: Bot3D = setup[1]
	await physics(30)
	check(bot.weapon == hammer and not bot.input.is_action_pressed(&"fire"), "at 9 m it holds the hammer, no swing")
	me.set(&"walks", true)
	var swung_at := -1.0
	for i in 300:
		await tree.physics_frame
		if bot.input.is_action_pressed(&"fire"):
			swung_at = bot.flat_distance_to(setup[2].global_position)
			break
	check(swung_at >= 0.0 and swung_at <= 2.05, "it walked in and swung within 2 m (%.2f)" % swung_at)
