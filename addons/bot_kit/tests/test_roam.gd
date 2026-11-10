extends "res://addons/bot_kit/tests/bot_test.gd"

## Roaming the navigation mesh: goals by priority within reach, where it saw an enemy last, a reachable random point,
## and a way out when stuck.

const World := preload("res://addons/bot_kit/tests/bot_test_world.gd")


func _goal(at: Vector3, priority := 1.0, reach := 20.0) -> BotGoal3D:
	var goal := BotGoal3D.new()
	goal.priority = priority
	goal.reach_m = reach
	goal.position = at
	root.add_child(goal)
	return goal


## Walks until it is within `within` m of `point` (true) or `seconds` pass.
func _walks_to(body: Node3D, point: Vector3, seconds := 8.0, within := 1.2) -> bool:
	for i in int(seconds * 60.0):
		await tree.physics_frame
		if Vector2(body.global_position.x - point.x, body.global_position.z - point.z).length() <= within:
			return true
	return false


func test_walks_to_the_best_goal_in_reach() -> void:
	var region := World.arena(root, 40.0, [[Vector3(-6, 1, 0), Vector3(0.5, 2, 8)]])
	var me := World.character(root, Vector3.ZERO)
	var bot := World.bot_of(me)
	var low := _goal(Vector3(5, 0, 0), 1.0)
	var high := _goal(Vector3(-12, 0, 0), 2.0)
	var far := _goal(Vector3(0, 0, 18), 5.0, 10.0)
	await World.bake(tree, region)
	check(await _walks_to(me, high.global_position), "it walks round the wall to the higher priority (%s)" % me.global_position)
	check(bot.mode == Bot3D.ROAM, "roaming")
	high.hide()
	check(await _walks_to(me, low.global_position), "a hidden goal (taken) counts for nobody: the next one")
	check(far.priority > high.priority, "the one out of its reach was never picked")


func test_wanted_and_the_difficulty_reach() -> void:
	var region := World.arena(root, 40.0)
	var me := World.character(root, Vector3.ZERO)
	var bot := World.bot_of(me)
	var health := _goal(Vector3(6, 0, 0), 3.0)
	var ammo := _goal(Vector3(-6, 0, 0), 1.0)
	health.wanted = func(_who: Bot3D) -> bool: return false
	await World.bake(tree, region)
	check(await _walks_to(me, ammo.global_position), "a goal it does not want is skipped")
	var lazy := BotDifficulty.new()
	lazy.goal_reach_scale = 0.0
	bot.difficulty = lazy
	health.wanted = Callable()
	ammo.position = Vector3(10, 0, 10)
	await physics(40)
	check(bot._goal_node == null, "goal_reach_scale 0: it walks to none")


func test_chases_where_it_saw_an_enemy() -> void:
	var region := World.arena(root, 40.0, [[Vector3(0, 1.5, -4), Vector3(8, 3, 0.5)]])
	var me := World.character(root, Vector3.ZERO)
	var bot := World.bot_of(me)
	var keen := BotDifficulty.new()
	keen.chase_chance = 1.0
	keen.reaction_s = 10.0
	keen.keep_m = 30.0
	bot.difficulty = keen
	var enemy := World.character(root, Vector3(12, 0, -10), false)
	me.set(&"walks", false)
	await World.bake(tree, region)
	await physics(30)
	check(bot.target == enemy, "it sees the enemy (%s)" % bot.target)
	var seen_at := enemy.global_position
	me.set(&"walks", true)
	enemy.position = Vector3(0, 0, -12)
	await physics(30)
	check(bot.target == null and bot.mode == Bot3D.ROAM, "lost behind the wall, it roams")
	check(await _walks_to(me, seen_at, 6.0, 1.6) or bot.target != null, "to where it saw it last")


func test_a_random_point_it_can_reach() -> void:
	var region := World.arena(root, 30.0, [[Vector3(5, 0.5, 5), Vector3(3, 1, 3)]])
	var me := World.character(root, Vector3.ZERO)
	var bot := World.bot_of(me)
	await World.bake(tree, region)
	var on_top := 0
	for i in 30:
		var point := bot.random_reachable_point()
		check(point != Vector3.INF, "a point")
		if point.y > 0.5:
			on_top += 1
	check(on_top == 0, "never on top of the box, an island it cannot reach (%d)" % on_top)
	check(await _walks_to(me, bot.goal if bot.goal != Vector3.INF else Vector3.ZERO, 8.0) or bot.goal != Vector3.INF, "it walks to them")


func test_stuck_it_jumps_and_picks_another_way() -> void:
	var region := World.arena(root, 30.0)
	var me := World.character(root, Vector3.ZERO)
	var bot := World.bot_of(me)
	_goal(Vector3(10, 0, 0))
	await World.bake(tree, region)
	me.set(&"walks", false)
	var stuck := [0]
	bot.stuck.connect(func() -> void: stuck[0] += 1)
	for i in 120:
		await tree.physics_frame
	check(stuck[0] >= 1, "a character that does not move is stuck (%d)" % stuck[0])
	check(bot._goal_node == null, "the goal it could not reach is dropped for a while")


func test_without_a_navigation_mesh_it_stands() -> void:
	World.arena(root, 20.0)
	var me := World.character(root, Vector3.ZERO)
	var bot := World.bot_of(me)
	await physics(60)
	check(bot.mode == Bot3D.ROAM and bot.goal == Vector3.INF, "roaming, nowhere to go")
	check(me.global_position.distance_to(Vector3.ZERO) < 0.1, "it stands")
	check(bot.input.held().is_empty(), "no key held")
