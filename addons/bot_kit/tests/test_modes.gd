extends "res://addons/bot_kit/tests/bot_test.gd"

## The bot does what wants it most: fight with an enemy in sight, roam otherwise, or one of its BotMode children.

const World := preload("res://addons/bot_kit/tests/bot_test_world.gd")
const TestMode := preload("res://addons/bot_kit/tests/bot_test_mode.gd")


func _mode(bot: Bot3D, name: String, want: float) -> BotMode:
	var mode := TestMode.new()
	mode.name = name
	mode.set(&"want", want)
	bot.add_child(mode)
	return mode


func test_fight_and_roam() -> void:
	World.arena(root)
	var me := World.character(root, Vector3.ZERO)
	var bot := World.bot_of(me)
	var modes: Array = []
	bot.mode_changed.connect(func(mode: StringName) -> void: modes.append(mode))
	await physics(20)
	check(bot.mode == Bot3D.ROAM, "nobody in sight: it roams")
	var enemy := World.character(root, Vector3(0, 0, -6), false)
	await physics(20)
	check(bot.mode == Bot3D.FIGHT, "an enemy in sight: it fights")
	enemy.queue_free()
	await physics(20)
	check(modes == [Bot3D.ROAM, Bot3D.FIGHT, Bot3D.ROAM], "mode_changed each time (%s)" % [modes])


func test_a_mode_that_wants_more_takes_over() -> void:
	World.arena(root)
	var me := World.character(root, Vector3.ZERO)
	var bot := World.bot_of(me)
	var flee := _mode(bot, "Flee", 0.0)
	World.character(root, Vector3(0, 0, -6), false)
	await physics(20)
	check(bot.mode == Bot3D.FIGHT, "fighting")
	flee.set(&"want", 2.0)
	await physics(20)
	check(bot.mode == &"Flee", "a mode that wants 2 beats the fight's 1")
	check(flee.get(&"entered") == 1 and flee.get(&"ticks") > 5, "entered once, ticked every frame")
	check(not bot.input.is_action_pressed(&"fire"), "the fight's trigger was let go")
	flee.set(&"want", 0.0)
	await physics(20)
	check(bot.mode == Bot3D.FIGHT and flee.get(&"exited") == 1, "wanting 0, it hands back to the fight")


func test_ties_keep_and_disabled_modes_never_run() -> void:
	World.arena(root)
	var me := World.character(root, Vector3.ZERO)
	var bot := World.bot_of(me)
	var guard := _mode(bot, "Guard", 0.5)
	var off := _mode(bot, "Off", 9.0)
	off.enabled = false
	await physics(20)
	check(bot.mode == &"Guard", "the mode that wants most, a disabled one aside")
	var other := _mode(bot, "Other", 0.5)
	await physics(20)
	check(bot.mode == &"Guard", "a tie keeps what it does")
	check(other.get(&"entered") == 0 and guard.get(&"ticks") > 0, "the other never ran")


func test_a_mode_walks_with_the_bots_helpers() -> void:
	var region := World.arena(root, 30.0)
	var me := World.character(root, Vector3.ZERO)
	var bot := World.bot_of(me)
	var go := _mode(bot, "Go", 5.0)
	go.set(&"point", Vector3(-8, 0, 6))
	await World.bake(tree, region)
	for i in 300:
		await tree.physics_frame
		if go.get(&"arrived"):
			break
	check(go.get(&"arrived") == true, "walk_to took it there")
	check(Vector2(me.global_position.x + 8.0, me.global_position.z - 6.0).length() < 1.0, "it is there (%s)" % me.global_position)
