extends "res://addons/bot_kit/tests/bot_test.gd"

## Turned off or freed, a bot lets go of every key; with turn_body off it only writes where it looks.

const World := preload("res://addons/bot_kit/tests/bot_test_world.gd")


func test_off_lets_go_and_forgets() -> void:
	World.arena(root)
	var me := World.character(root, Vector3.ZERO)
	var bot := World.bot_of(me)
	var level := BotDifficulty.new()
	level.reaction_s = 0.0
	level.aim_error_deg = 0.0
	bot.difficulty = level
	World.character(root, Vector3(0, 0, -6), false)
	await physics(40)
	check(not bot.input.held().is_empty(), "fighting, it holds keys")
	var released: Array = []
	bot.input.released.connect(func(action: StringName) -> void: released.append(action))
	bot.enabled = false
	check(bot.input.held().is_empty() and not released.is_empty(), "off: every key let go, with signals")
	check(bot.target == null and bot.mode == StringName(), "and its enemy forgotten")
	await physics(30)
	check(bot.input.held().is_empty(), "off, it presses nothing")
	bot.enabled = true
	await physics(30)
	check(bot.target != null and bot.mode == Bot3D.FIGHT, "on again, it fights again")


func test_freed_it_lets_go_of_a_forwarded_input() -> void:
	World.arena(root)
	var me := World.character(root, Vector3.ZERO)
	var bot := World.bot_of(me)
	var forwarded := BotInput.new()
	bot.input.pressed.connect(forwarded.press)
	bot.input.released.connect(forwarded.release)
	World.character(root, Vector3(0, 0, -6), false)
	await physics(40)
	check(not forwarded.held().is_empty(), "the forwarded input has its keys")
	bot.queue_free()
	await physics(2)
	check(forwarded.held().is_empty(), "freed (a person took the seat), it let go of them")


func test_turn_body_off_writes_values_only() -> void:
	World.arena(root)
	var me := World.character(root, Vector3.ZERO)
	var bot := World.bot_of(me)
	bot.turn_body = false
	me.set(&"walks", false)
	World.character(root, Vector3(6, 0, 0), false)
	await physics(60)
	check(near(me.global_rotation.y, 0.0), "its body was not turned")
	var yaw := float(bot.input.get_value(&"yaw", 0.0))
	check(yaw < -0.5, "it wrote the yaw toward the enemy on its right (%.2f)" % yaw)
