extends "res://addons/bot_kit/tests/bot_test.gd"

## The aim's math: angles, leading a walking target, lobbing a throw onto a point.


func test_angles_follow_godots_forward() -> void:
	check(near(BotAim.yaw_of(Vector3.FORWARD), 0.0), "-Z is yaw 0")
	check(near(BotAim.yaw_of(Vector3.LEFT), PI / 2.0), "-X is a quarter turn left")
	check(near(BotAim.pitch_of(Vector3(0, 1, -1)), PI / 4.0), "up and ahead is +45°")
	for yaw: float in [0.0, 1.0, -2.5]:
		for pitch: float in [0.0, 0.4, -0.7]:
			var dir := BotAim.facing(yaw, pitch)
			check(near(BotAim.yaw_of(dir), yaw, 0.001) and near(BotAim.pitch_of(dir), pitch, 0.001), "facing and back (%s, %s)" % [yaw, pitch])
	check(near(BotAim.degrees_off(0.0, 0.0, deg_to_rad(10.0), 0.0), 10.0, 0.01), "degrees off")


func test_turns_the_short_way_round() -> void:
	check(near(BotAim.turn_yaw(3.0, -3.0, 0.1), wrapf(3.1, -PI, PI), 0.001), "across ±PI the short way")
	check(near(BotAim.turn_yaw(0.0, 1.0, 0.25), 0.25), "at most a step")
	check(near(BotAim.turn_yaw(0.0, 0.1, 0.25), 0.1), "never past the goal")


func test_leads_by_the_flight_time() -> void:
	var from := Vector3.ZERO
	var at := Vector3(0, 0, -20)
	var walk := Vector3(3, 5, 0)
	check(BotAim.lead(from, at, walk, 0.0, 1.0) == at, "a hit at once: no lead")
	check(near(BotAim.lead(from, at, walk, 40.0, 1.0), Vector3(1.5, 0, -20)), "half a second of flight, only the flat walk")
	check(near(BotAim.lead(from, at, walk, 10.0, 0.5), Vector3(1.5, 0, -20)), "at most most_s")


## The lob pitch, thrown in a simple simulation, lands on the point.
func test_a_lob_lands_on_its_point() -> void:
	var speed := 14.0
	var gravity := 9.8
	for target: Vector2 in [Vector2(8, 0), Vector2(15, 1.5), Vector2(12, -2)]:
		var pitch := BotAim.lob_pitch(speed, gravity, target.x, target.y)
		var velocity := Vector2(cos(pitch), sin(pitch)) * speed
		var at := Vector2.ZERO
		var dt := 0.001
		while at.x < target.x:
			velocity.y -= gravity * dt
			at += velocity * dt
		check(near(at.y, target.y, 0.05), "lands within 5 cm at %s (pitch %.1f°, %.3f)" % [target, rad_to_deg(pitch), at.y])
	check(near(BotAim.lob_pitch(5.0, 9.8, 30.0, 0.0), BotAim.OUT_OF_REACH_PITCH), "out of reach: the farthest throw")
	check(near(BotAim.lob_pitch(10.0, 0.0, 10.0, 10.0), PI / 4.0), "no gravity: straight at it")
