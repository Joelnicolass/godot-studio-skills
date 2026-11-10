extends "res://addons/bot_kit/tests/bot_test.gd"

## A fight: it turns at a person's speed, reacts before its first shot, fires inside its cone in bursts or by its
## weapon's trigger, keeps its distance and steps sideways.

const World := preload("res://addons/bot_kit/tests/bot_test_world.gd")


## A bot facing away from a standing enemy 8 m ahead of it... behind it.
func _duel(enemy_at := Vector3(0, 0, 8)) -> Array:
	World.arena(root, 40.0)
	var me := World.character(root, Vector3.ZERO)
	var bot := World.bot_of(me)
	var enemy := World.character(root, enemy_at, false)
	return [me, bot, enemy]


func test_turns_at_its_speed_then_reacts_then_fires() -> void:
	var duel := _duel()
	var me: CharacterBody3D = duel[0]
	var bot: Bot3D = duel[1]
	me.set(&"walks", false)
	var level := BotDifficulty.new()
	level.aim_error_deg = 0.0
	level.reaction_s = 0.5
	level.turn_deg_s = 90.0
	level.burst_s = 10.0
	bot.difficulty = level
	await physics(2)
	var yaw_before := me.global_rotation.y
	var most_step := 0.0
	var first_shot_s := -1.0
	var seen_at_s := -1.0
	for i in 150:
		var yaw := me.global_rotation.y
		await tree.physics_frame
		most_step = maxf(most_step, absf(angle_difference(yaw, me.global_rotation.y)))
		if bot.target != null and seen_at_s < 0.0:
			seen_at_s = i / 60.0
		if bot.input.is_action_pressed(&"fire") and first_shot_s < 0.0:
			first_shot_s = i / 60.0
	check(bot.target != null, "it sees the enemy behind it")
	check(most_step <= deg_to_rad(90.0) / 60.0 + 0.0001, "at most 90°/s (%.2f° a frame)" % rad_to_deg(most_step))
	check(absf(angle_difference(yaw_before, me.global_rotation.y)) > deg_to_rad(170.0), "it turned round")
	check(first_shot_s >= seen_at_s + 0.5 - 0.02, "no shot before its reaction (seen %.2f s, shot %.2f s)" % [seen_at_s, first_shot_s])
	check(first_shot_s >= seen_at_s + 2.0 - 0.1, "nor before it faces the enemy (180° at 90°/s)")
	check(bot.mode == Bot3D.FIGHT, "it fights")


func test_bursts_and_pauses() -> void:
	var duel := _duel(Vector3(0, 0, -8))
	var bot: Bot3D = duel[1]
	(duel[0] as Node).set(&"walks", false)
	var level := BotDifficulty.new()
	level.aim_error_deg = 0.0
	level.reaction_s = 0.0
	level.burst_s = 0.5
	level.burst_pause_s = 0.5
	bot.difficulty = level
	var held := 0
	var presses := 0
	var was := false
	for i in 240:
		await tree.physics_frame
		var now := bot.input.is_action_pressed(&"fire")
		held += 1 if now else 0
		presses += 1 if now and not was else 0
		was = now
	check(presses >= 3, "it fires in bursts (%d)" % presses)
	check(held > 60 and held < 180, "about half the time (%d of 240 frames)" % held)


func test_holds_fire_out_of_its_cone() -> void:
	var duel := _duel(Vector3(0, 0, -8))
	var bot: Bot3D = duel[1]
	(duel[0] as Node).set(&"walks", false)
	var level := BotDifficulty.new()
	level.aim_error_deg = 30.0
	level.fire_cone_deg = 0.5
	level.reaction_s = 0.0
	bot.difficulty = level
	var fired := 0
	for i in 120:
		await tree.physics_frame
		fired += 1 if bot.input.is_action_pressed(&"fire") else 0
	check(fired < 12, "an aim error far over its cone keeps its finger off (%d frames)" % fired)


func test_tap_and_charge_triggers() -> void:
	var duel := _duel(Vector3(0, 0, -8))
	var bot: Bot3D = duel[1]
	(duel[0] as Node).set(&"walks", false)
	var level := BotDifficulty.new()
	level.aim_error_deg = 0.0
	level.reaction_s = 0.0
	bot.difficulty = level
	var pistol := BotWeapon.new()
	pistol.trigger = BotWeapon.Trigger.TAP
	pistol.tap_every_s = 0.25
	bot.weapons = [pistol]
	var me: Node = duel[0]
	for i in 120:
		await tree.physics_frame
	var presses: int = me.get(&"shots")
	check(presses >= 6 and presses <= 9, "TAP: one press every 0.25 s (%d in 2 s)" % presses)
	check(me.get(&"fired_frames") == presses, "each press lasts one frame")
	var bow := BotWeapon.new()
	bow.trigger = BotWeapon.Trigger.CHARGE
	bow.charge_s = 0.5
	bow.fire_action = &"alt_fire"
	bot.weapons = [bow]
	var releases := 0
	var longest := 0
	var run := 0
	for i in 180:
		await tree.physics_frame
		if bot.input.is_action_pressed(&"alt_fire"):
			run += 1
		elif run > 0:
			releases += 1
			longest = maxi(longest, run)
			run = 0
	check(not bot.input.is_action_pressed(&"fire"), "the pistol's action was let go on the switch")
	check(releases >= 2, "CHARGE: held, then let go (%d)" % releases)
	check(longest >= 10 and longest <= 32, "held 40 to 100 %% of 0.5 s (%d frames)" % longest)


func test_keeps_its_distance_and_steps_sideways() -> void:
	var duel := _duel(Vector3(0, 0, -20))
	await World.bake(tree, root.get_node(^"Navigation") as NavigationRegion3D)
	var me: CharacterBody3D = duel[0]
	var bot: Bot3D = duel[1]
	var level := BotDifficulty.new()
	level.keep_m = 8.0
	level.reaction_s = 10.0
	bot.difficulty = level
	var start := me.global_position
	for i in 240:
		await tree.physics_frame
	var distance := Vector2(me.global_position.x, me.global_position.z - -20.0).length()
	check(distance < 13.0 and distance > 4.0, "it walked in to about 8 m (%.1f m)" % distance)
	check(absf(me.global_position.x - start.x) > 0.3 or me.jumps > 0, "it stepped sideways (x %.2f)" % me.global_position.x)
	var close := World.character(root, me.global_position + Vector3(0, 0, -2), false)
	close.set(&"walks", false)
	await physics(30)
	var away := me.global_position.distance_to(close.global_position)
	for i in 60:
		await tree.physics_frame
	check(me.global_position.distance_to(close.global_position) > away, "too close, it backs off")


func test_a_throw_aims_over_the_target() -> void:
	var duel := _duel(Vector3(0, 0, -12))
	var bot: Bot3D = duel[1]
	(duel[0] as Node).set(&"walks", false)
	var level := BotDifficulty.new()
	level.aim_error_deg = 0.0
	level.reaction_s = 0.0
	level.turn_deg_s = 720.0
	bot.difficulty = level
	var grenade := BotWeapon.new()
	grenade.projectile_speed_m_s = 14.0
	grenade.gravity_m_s2 = 9.8
	grenade.aim_height_m = 0.3
	bot.weapons = [grenade]
	var pitched := 0.0
	var fired := false
	for i in 60:
		await tree.physics_frame
		pitched = float(bot.input.get_value(&"pitch", 0.0))
		fired = fired or bot.input.is_action_pressed(&"fire")
	var expected := BotAim.lob_pitch(14.0, 9.8, 12.0, 0.3 - 1.6)
	check(near(pitched, expected, 0.02), "it looks up the lob's pitch (%.1f°, wants %.1f°)" % [rad_to_deg(pitched), rad_to_deg(expected)])
	check(fired, "and throws, though its aim is far over the straight line")
