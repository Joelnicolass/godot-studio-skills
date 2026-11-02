extends "res://addons/perception_kit/tests/perception_test.gd"

## PerceptionSensor2D in a 2D physics world: the view (aimed by rotation), the lose radius, walls,
## near awareness, noises, memory, sides and visibility.

var perceived: Array[PerceptionStimulus] = []
var forgotten: Array[PerceptionStimulus] = []


func _sensor(at := Vector2.ZERO) -> PerceptionSensor2D:
	var sensor := PerceptionSensor2D.new()
	sensor.sense_hz = 60.0
	sensor.memory_s = 0.3
	root.add_child(sensor)
	sensor.global_position = at
	perceived.clear()
	forgotten.clear()
	sensor.perceived.connect(func(stimulus: PerceptionStimulus) -> void: perceived.append(stimulus))
	sensor.forgotten.connect(func(stimulus: PerceptionStimulus) -> void: forgotten.append(stimulus))
	return sensor


func _target(at: Vector2) -> PerceptionTarget2D:
	var target := PerceptionTarget2D.new()
	root.add_child(target)
	target.global_position = at
	return target


func _wall(at: Vector2, size := Vector2(20, 200)) -> StaticBody2D:
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box
	wall.add_child(shape)
	root.add_child(wall)
	wall.global_position = at
	return wall


func test_sees_in_view() -> void:
	var sensor := _sensor()
	var target := _target(Vector2(200, 40))
	var behind := _target(Vector2(-200, 0))
	await physics(4)
	check(sensor.sees(target) and not sensor.sees(behind), "it sees in front (+X), not behind")
	check(perceived.size() == 1 and perceived[0].position_2d == Vector2(200, 40), "perceived once, where it is (position_2d)")
	sensor.rotation = PI
	await physics(3)
	check(sensor.sees(behind) and not sensor.sees(target), "turned around, the other way")


func test_lose_radius_and_memory() -> void:
	var sensor := _sensor()
	var target := _target(Vector2(380, 0))
	await physics(4)
	check(not sensor.sees(target), "380 px, between sight (320) and lose (420): a new one is not seen")
	target.global_position = Vector2(300, 0)
	await physics(3)
	target.global_position = Vector2(380, 0)
	await physics(3)
	check(sensor.sees(target), "seen, and kept at 380 px")
	target.global_position = Vector2(500, 0)
	await physics(40)
	check(forgotten.size() == 1 and forgotten[0].position_2d == Vector2(380, 0), "past lose and past memory_s: forgotten, where it was last")


func test_walls_and_near() -> void:
	var sensor := _sensor()
	_wall(Vector2(100, 0))
	var hidden := _target(Vector2(200, 0))
	var close := _target(Vector2(-30, 10))
	await physics(4)
	check(not sensor.sees(hidden), "a wall hides it")
	check(sensor.sees(close), "30 px behind, inside the 48 px near radius: noticed")


func test_hearing_and_sides() -> void:
	var sensor := _sensor()
	check(sensor.hear(Vector2(0, 150), 200.0, 2) and perceived[0].kind == PerceptionStimulus.HEARING, "a noise within its radius: heard")
	check(not sensor.hear(Vector2(0, 250), 200.0, 2), "past it: not")
	sensor.collision_mask = 1 << 4
	var friend := _target(Vector2(100, 0))
	var foe := _target(Vector2(100, 20))
	foe.collision_layer = 1 << 4
	await physics(4)
	check(sensor.sees(foe) and not sensor.sees(friend), "it sees its mask's layers only")
	foe.global_position = Vector2(200, 0)
	foe.visibility = 0.25
	await physics(3)
	check(not sensor.sees(foe), "a quarter visible, 200 px away: no longer seen (its lose radius is 105 px)")


func test_own_circle() -> void:
	var sensor := _sensor()
	var circle := (sensor.get_child(0, true) as CollisionShape2D).shape as CircleShape2D
	check(near(circle.radius, 420.0) and sensor.get_child_count() == 0, "its internal circle: the lose radius")
	sensor.reach_by_kind = {&"light": 2.0}
	check(near(circle.radius, 840.0) and near(sensor.reach_px(), 840.0), "a farther kind grows it")
