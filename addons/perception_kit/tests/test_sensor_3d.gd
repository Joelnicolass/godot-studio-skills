extends "res://addons/perception_kit/tests/perception_test.gd"

## PerceptionSensor3D in a physics world: the view, the lose radius, walls, near awareness, the
## bodies, noises, memory, sides, visibility and reach, the radius rule of a game's own, off.

var perceived: Array[PerceptionStimulus] = []
var forgotten: Array[PerceptionStimulus] = []


## A sensor at `at` looking along -Z, every physics frame, with a short memory.
func _sensor(at := Vector3.ZERO) -> PerceptionSensor3D:
	var sensor := PerceptionSensor3D.new()
	sensor.sense_hz = 60.0
	sensor.memory_s = 0.3
	root.add_child(sensor)
	sensor.global_position = at
	perceived.clear()
	forgotten.clear()
	sensor.perceived.connect(func(stimulus: PerceptionStimulus) -> void: perceived.append(stimulus))
	sensor.forgotten.connect(func(stimulus: PerceptionStimulus) -> void: forgotten.append(stimulus))
	return sensor


func _target(at: Vector3) -> PerceptionTarget3D:
	var target := PerceptionTarget3D.new()
	root.add_child(target)
	target.global_position = at
	return target


func _wall(at: Vector3, size := Vector3(4, 4, 0.5), layer := 1) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = layer
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	wall.add_child(shape)
	root.add_child(wall)
	wall.global_position = at
	return wall


func test_sees_in_view() -> void:
	var sensor := _sensor()
	var target := _target(Vector3(2, 0, -10))
	await physics(4)
	check(sensor.sees(target) and sensor.sees_any() and sensor.is_aware(), "it sees a target in front, inside its radius")
	check(perceived.size() == 1 and perceived[0].kind == PerceptionStimulus.SIGHT and perceived[0].target == target, "perceived once, as sight, with its target")
	var expected := 1.0 - Vector3(2, 0, -10).length() / 20.0
	check(near(perceived[0].strength, expected, 0.01) and near(perceived[0].position, target.global_position), "its strength by distance, out of the lose radius (%.2f), and its position" % perceived[0].strength)
	check(sensor.latest() == perceived[0] and sensor.stimulus_of(target) == perceived[0], "latest() and stimulus_of() give it")
	await physics(10)
	check(perceived.size() == 1 and sensor.sees(target), "while it keeps seeing it, perceived is not emitted again")


func test_angle_and_radius() -> void:
	var sensor := _sensor()
	var side := _target(Vector3(8, 0, -2))
	var far := _target(Vector3(0, 0, -16))
	await physics(4)
	check(not sensor.sees(side), "76° off a 120° view: not seen")
	check(not sensor.sees(far), "16 m away, past the 15 m sight radius: not seen")
	sensor.view_angle_deg = 170.0
	await physics(3)
	check(sensor.sees(side), "with a 170° view it is")
	check(perceived.size() == 1, "only that one")


func test_lose_radius_keeps_it() -> void:
	var sensor := _sensor()
	var target := _target(Vector3(0, 0, -18))
	await physics(4)
	check(not sensor.sees(target), "18 m, between the sight (15) and lose (20) radius: a new one is not seen")
	target.global_position = Vector3(0, 0, -10)
	await physics(3)
	check(sensor.sees(target), "it comes within 15 m: seen")
	target.global_position = Vector3(0, 0, -18)
	await physics(3)
	check(sensor.sees(target) and perceived.size() == 1, "back at 18 m: still seen, until the lose radius")
	target.global_position = Vector3(0, 0, -22)
	await physics(3)
	check(not sensor.sees(target) and sensor.is_aware(), "past 20 m: no longer seen, still remembered")
	check(not sensor.sees_any() and sensor.stimulus_of(target).position == Vector3(0, 0, -18), "remembered where it was last seen")


func test_walls_hide() -> void:
	var sensor := _sensor()
	var wall := _wall(Vector3(0, 0, -5))
	var target := _target(Vector3(0, 0, -10))
	await physics(4)
	check(not sensor.sees(target) and perceived.is_empty(), "a wall between: not seen")
	wall.free()
	await physics(3)
	check(sensor.sees(target) and perceived.size() == 1, "the wall gone: perceived")
	var glass := _wall(Vector3(0, 0, -5), Vector3(4, 4, 0.5), 4)
	await physics(3)
	check(sensor.sees(target), "a body on a layer outside occlusion_mask does not hide it")
	sensor.occlusion_mask = 4
	await physics(3)
	check(not sensor.sees(target), "with that layer in the mask, it does")
	glass.free()


func test_near_all_around() -> void:
	var sensor := _sensor()
	var behind := _target(Vector3(0.5, 0, 2))
	var farther := _target(Vector3(0, 0, 4))
	await physics(4)
	check(sensor.sees(behind), "2 m behind, inside the 2.5 m near radius: noticed")
	check(not sensor.sees(farther), "4 m behind: not")
	check(near(sensor.stimulus_of(behind).strength, 1.0), "near is full strength")
	_wall(Vector3(0, 0, 1.0), Vector3(4, 4, 0.2))
	await physics(3)
	check(not sensor.sees(behind), "a wall hides a near one too")


func test_own_bodies_never_hide() -> void:
	var guard := _wall(Vector3.ZERO, Vector3(1, 2, 1))
	var sensor := PerceptionSensor3D.new()
	sensor.sense_hz = 60.0
	guard.add_child(sensor)
	var crate := _wall(Vector3(0, 0, -10), Vector3(1, 1, 1))
	var target := PerceptionTarget3D.new()
	crate.add_child(target)
	await physics(4)
	check(sensor.body == guard and target.body == crate, "each takes the body above it")
	check(sensor.sees(target), "the sensor's own body and the target's do not hide it")
	sensor.body = null
	target.body = null
	await physics(3)
	check(not sensor.sees(target), "without them, its own crate hides it")


func test_eye_height() -> void:
	var sensor := _sensor()
	sensor.eye_height_m = 1.6
	var low := _wall(Vector3(0, 0.5, -5), Vector3(4, 1, 0.5))
	var head := _target(Vector3(0, 1.6, -10))
	await physics(4)
	check(near(sensor.eye_position(), Vector3(0, 1.6, 0)), "the eyes 1.6 m above it")
	check(sensor.sees(head), "over a low wall, from the eyes")
	sensor.eye_height_m = 0.2
	await physics(3)
	check(not sensor.sees(head), "with the eyes lower, the wall hides it")
	low.free()


func test_hearing() -> void:
	var sensor := _sensor()
	check(sensor.hear(Vector3(0, 0, 8), 10.0, 3), "a noise 8 m away heard up to 10 m: heard (behind it too)")
	check(perceived.size() == 1 and perceived[0].kind == PerceptionStimulus.HEARING and perceived[0].key == 3, "perceived as hearing, by its source")
	check(perceived[0].position == Vector3(0, 0, 8) and near(perceived[0].strength, 0.2) and perceived[0].target == null, "where it was, its strength (0.2), no target")
	check(sensor.hear(Vector3(1, 0, 8), 10.0, 3) and perceived.size() == 2 and perceived[1] == perceived[0], "every noise is perceived; the same source stays one memory")
	check(not sensor.hear(Vector3(0, 0, 12), 10.0, 4) and perceived.size() == 2, "12 m away: not heard")
	sensor.hearing_scale = 1.5
	check(sensor.hear(Vector3(0, 0, 12), 10.0, 4), "keener (1.5): heard")
	sensor.hearing_scale = 0.0
	check(not sensor.hear(Vector3(0, 0, 1), 10.0, 5), "deaf: nothing")
	check(sensor.is_aware() and not sensor.sees_any(), "aware, seeing nothing")


func test_memory_forgets() -> void:
	var sensor := _sensor()
	var target := _target(Vector3(0, 0, -10))
	await physics(3)
	check(perceived.size() == 1, "seen")
	target.global_position = Vector3(0, 0, -30)
	await physics(4)
	target.global_position = Vector3(0, 0, -9)
	await physics(3)
	check(perceived.size() == 1 and forgotten.is_empty(), "lost and seen again before its memory ends: not perceived again")
	target.global_position = Vector3(0, 0, -30)
	await physics(40)
	check(forgotten.size() == 1 and forgotten[0].target == target, "past memory_s it is forgotten")
	check(forgotten[0].position == Vector3(0, 0, -9), "with where it was last seen")
	check(not sensor.is_aware() and sensor.latest() == null, "nothing left")
	target.global_position = Vector3(0, 0, -9)
	await physics(3)
	check(perceived.size() == 2, "seen once forgotten: perceived again")


func test_freed_target() -> void:
	var sensor := _sensor()
	var target := _target(Vector3(0, 0, -6))
	await physics(3)
	target.free()
	await physics(40)
	check(forgotten.size() == 1 and forgotten[0].target == null, "a freed target is forgotten in time, with no target")


func test_sides_are_layers() -> void:
	var sensor := _sensor()
	sensor.collision_mask = 1 << 3
	var foe := _target(Vector3(0, 0, -6))
	foe.collision_layer = 1 << 3
	var friend := _target(Vector3(1, 0, -6))
	await physics(4)
	check(sensor.sees(foe) and not sensor.sees(friend), "it sees the targets on its mask's layers only")


func test_visibility_and_scales() -> void:
	var sensor := _sensor()
	var target := _target(Vector3(0, 0, -10))
	target.visibility = 0.5
	await physics(4)
	check(not sensor.sees(target), "half visible: 7.5 m, so 10 m away is not seen")
	target.visibility = 1.0
	sensor.sight_scale = 0.5
	await physics(3)
	check(not sensor.sees(target), "sight_scale 0.5 (night): not seen")
	sensor.sight_scale = 1.0
	await physics(3)
	check(sensor.sees(target), "full sight: seen")
	var lamp := _target(Vector3(4, 0, -30))
	lamp.kind = &"light"
	await physics(3)
	check(not sensor.sees(lamp), "a light 30 m away, no reach for it: not seen")
	sensor.reach_by_kind = {&"light": 2.5}
	await physics(3)
	check(sensor.sees(lamp) and sensor.stimulus_of(lamp).kind == &"light", "reach_by_kind light 2.5: seen, as light")
	check(sensor.reach_m() >= 50.0, "its reach grows with it (%.1f)" % sensor.reach_m())


func test_radius_rule_of_the_game() -> void:
	var script := GDScript.new()
	script.source_code = "extends PerceptionSensor3D\n\nfunc _sight_radius(target: PerceptionTarget3D, _seen: bool, radius: float) -> float:\n\treturn 0.0 if target.name == &\"Hidden\" else radius\n"
	check(script.reload() == OK, "a sensor of the game's own compiles")
	var sensor := script.new() as PerceptionSensor3D
	sensor.sense_hz = 60.0
	root.add_child(sensor)
	var hidden := _target(Vector3(0, 0, -5))
	hidden.name = &"Hidden"
	var shown := _target(Vector3(1, 0, -5))
	await physics(4)
	check(not sensor.sees(hidden) and sensor.sees(shown), "its _sight_radius() decides per target")


func test_sense_and_off() -> void:
	var sensor := _sensor()
	sensor.sense(&"alarm", Vector3(3, 0, 3), 0.7, 9)
	check(perceived.size() == 1 and perceived[0].kind == &"alarm" and near(perceived[0].strength, 0.7), "sense(): a kind of the game's own")
	var target := _target(Vector3(0, 0, -5))
	await physics(3)
	check(sensor.sees(target), "seen")
	sensor.enabled = false
	check(not sensor.is_aware() and forgotten.is_empty(), "off: it forgets everything, without signals")
	await physics(3)
	check(not sensor.sees(target) and not sensor.hear(Vector3.ZERO, 10.0), "off: it sees and hears nothing")
	sensor.enabled = true
	await physics(4)
	check(sensor.sees(target), "on again: it sees")
	target.enabled = false
	await physics(3)
	check(not sensor.sees(target) and sensor.is_aware(), "a target turned off is not seen (still remembered)")


func test_own_sphere() -> void:
	var sensor := _sensor()
	sensor.eye_height_m = 1.5
	var sphere := (sensor.get_child(0, true) as CollisionShape3D).shape as SphereShape3D
	check(near(sphere.radius, 21.5), "its sphere: the lose radius plus the eyes' height (%.1f)" % sphere.radius)
	check(sensor.get_child_count() == 0, "internal: not a child of the scene")
	var scene := PackedScene.new()
	check(scene.pack(sensor) == OK, "packed")
	var copy := scene.instantiate()
	check(copy.get_child_count(true) == 0, "a packed sensor has no saved shape (its own is made in the tree)")
	copy.free()
	sensor.lose_radius_m = 10.0
	check(sensor._get_configuration_warnings().size() == 1, "lose under sight: a warning")
	sensor.show_in_game = true
	check(sensor.get_child_count(true) == 1, "headless, show_in_game draws nothing")


func test_each_at_its_own_moment() -> void:
	var a := PerceptionSensor3D.new()
	var b := PerceptionSensor3D.new()
	root.add_child(a)
	root.add_child(b)
	var wait_a: float = a.get(&"_wait")
	var wait_b: float = b.get(&"_wait")
	check(not near(wait_a, wait_b, 0.001) and wait_a < 0.2 and wait_b < 0.2, "two sensors look at different moments of their 0.2 s (%.3f, %.3f)" % [wait_a, wait_b])
