extends "res://addons/bot_kit/tests/bot_test.gd"

## Who the bot sees: the nearest enemy of its group within its sight and with a clear line.

const World := preload("res://addons/bot_kit/tests/bot_test_world.gd")


func _stand_still(body: Node) -> void:
	body.set(&"walks", false)


func test_sees_the_nearest_with_a_clear_line() -> void:
	World.arena(root, 40.0, [[Vector3(0, 1.5, -6), Vector3(4, 3, 0.5)]])
	var me := World.character(root, Vector3(0, 0, 0))
	var bot := World.bot_of(me)
	bot.random_seed = 3
	_stand_still(me)
	var hidden := World.character(root, Vector3(0, 0, -9), false)
	var far := World.character(root, Vector3(8, 0, -8), false)
	await physics(4)
	await _thinks(bot)
	check(bot.target == far, "the one behind the wall is hidden; the far one is seen")
	var near_one := World.character(root, Vector3(-3, 0, 2), false)
	await physics(2)
	await _thinks(bot)
	check(bot.target == near_one, "a nearer one takes over")
	near_one.hide()
	await _thinks(bot)
	check(bot.target == far, "a hidden node is not seen")
	var short := BotDifficulty.new()
	short.sight_m = 15.0
	bot.difficulty = short
	far.position = Vector3(16, 0, 0)
	near_one.queue_free()
	await physics(2)
	await _thinks(bot)
	check(bot.target == null, "out of its difficulty's sight (15 m): none")
	check(hidden != null, "the hidden one stays hidden")


func test_its_own_body_and_its_enemys_never_block() -> void:
	World.arena(root)
	var me := World.character(root, Vector3.ZERO)
	var bot := World.bot_of(me)
	bot.sight_mask = 1 | 2
	_stand_still(me)
	var other := World.character(root, Vector3(0, 0, -6), false)
	await physics(4)
	await _thinks(bot)
	check(bot.target == other, "with characters in the mask, its own capsule and the enemy's do not block")
	var wall := World.character(root, Vector3(0, 0, -3), false)
	wall.remove_from_group(&"bot_target")
	await physics(2)
	await _thinks(bot)
	check(bot.target == null, "a third character in between does")


func test_is_enemy_and_choose_target() -> void:
	World.arena(root)
	var me := World.character(root, Vector3.ZERO)
	var bot := World.bot_of(me)
	_stand_still(me)
	var friend := World.character(root, Vector3(0, 0, -4), false)
	var foe := World.character(root, Vector3(0, 0, -8), false)
	friend.set_meta(&"team", 1)
	foe.set_meta(&"team", 2)
	bot.is_enemy = func(node: Node3D) -> bool: return node.get_meta(&"team", 0) != 1
	await physics(4)
	await _thinks(bot)
	check(bot.target == foe, "is_enemy skips the friend")
	var picked: Array[Node3D] = [friend]
	bot.choose_target = func() -> Node3D: return picked[0]
	await _thinks(bot)
	check(bot.target == friend, "choose_target replaces its sight")
	picked[0] = null
	await _thinks(bot)
	check(bot.target == null, "and may choose nobody")


func test_target_changed_and_a_freed_enemy() -> void:
	World.arena(root)
	var me := World.character(root, Vector3.ZERO)
	var bot := World.bot_of(me)
	_stand_still(me)
	var seen: Array = []
	bot.target_changed.connect(func(node: Node3D) -> void: seen.append(node))
	var other := World.character(root, Vector3(0, 0, -5), false)
	await physics(4)
	await _thinks(bot)
	check(seen == [other], "target_changed once for the new enemy")
	other.queue_free()
	await physics(2)
	check(bot.target == null and seen.size() == 2 and seen[1] == null, "a freed enemy is dropped at once, with null")


## A few thinks (its think_s is 0.2 s).
func _thinks(bot: Bot3D, count := 2) -> void:
	for i in count:
		await physics(int(ceil(bot.think_s * Engine.physics_ticks_per_second)) + 1)
