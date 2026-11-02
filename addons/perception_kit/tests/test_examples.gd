extends "res://addons/perception_kit/tests/perception_test.gd"

## The examples play: the guard sees you only out of the wall's shadow and turns to you, hears
## your noise, forgets you; the 2D one the same; in the yard a noise sends a guard searching and
## home again, your lamp is seen from afar where the shade hides you, and night shortens sight.


func _press(scene: Node, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	scene.call(&"_unhandled_input", event)


func _key(scene: Node, key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	scene.call(&"_unhandled_input", event)


func test_minimal_3d() -> void:
	var scene := (load("res://addons/perception_kit/examples/minimal_3d/minimal_3d.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var sensor := scene.get_node(^"Guard/Head/Sensor") as PerceptionSensor3D
	var player := scene.get_node(^"Player") as CharacterBody3D
	var head := scene.get_node(^"Guard/Head") as Node3D
	sensor.memory_s = 0.3
	await physics(12)
	check(sensor.body == scene.get_node(^"Guard") and not sensor.is_aware(), "behind the wall you are not seen")
	player.global_position = Vector3(-4, 0.9, -7)
	await physics(30)
	check(sensor.sees_any(), "out of the wall's shadow: seen")
	var yaw := atan2(4.0, 7.0)
	check(near(head.rotation.y, yaw, 0.05), "the head turned toward you (%.2f, %.2f)" % [head.rotation.y, yaw])
	check((scene.get_node(^"Label") as Label).text.contains("sees you"), "the label says so")
	player.global_position = Vector3(3, 0.9, -9)
	await physics(40)
	check(not sensor.is_aware(), "back behind the wall, forgotten")
	_press(scene, &"ui_accept")
	check(sensor.latest() != null and sensor.latest().kind == PerceptionStimulus.HEARING, "Space: your noise is heard")


func test_minimal_2d() -> void:
	var scene := (load("res://addons/perception_kit/examples/minimal_2d/minimal_2d.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var sensor := scene.get_node(^"Guard/Sensor") as PerceptionSensor2D
	var player := scene.get_node(^"Player") as CharacterBody2D
	sensor.memory_s = 0.3
	await physics(12)
	check(not sensor.is_aware(), "behind the wall you are not seen")
	player.global_position = Vector2(520, 420)
	await physics(30)
	check(sensor.sees_any(), "out in the open: seen")
	var guard := scene.get_node(^"Guard") as Node2D
	check(near(guard.rotation, (Vector2(520, 420) - guard.global_position).angle(), 0.05), "the guard turned toward you")
	_press(scene, &"ui_accept")
	check(sensor.latest().kind == PerceptionStimulus.HEARING or sensor.sees_any(), "Space: a noise")


func _yard() -> Node:
	var scene := (load("res://addons/perception_kit/examples/guards_3d/guards_3d.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	for guard: Node in scene.get(&"guards"):
		(guard.get(&"sensor") as PerceptionSensor3D).memory_s = 0.6
	return scene


func test_guards_noise() -> void:
	var scene := _yard()
	var guards: Array[CharacterBody3D] = scene.get(&"guards")
	var first := guards[0]
	await physics(10)
	check(first.call(&"state_name") == "WATCH" and guards[1].call(&"state_name") == "WATCH", "both guards watch")
	# A noise near the first guard, where it cannot see.
	var home := first.global_position
	scene.call(&"make_noise", Vector3(-14, 0.9, -4))
	await physics(20)
	check(first.call(&"state_name") == "SEARCH", "a noise: it goes to search (%s)" % first.call(&"state_name"))
	check(first.global_position.distance_to(home) > 0.3, "and walks toward it")
	check(guards[1].call(&"state_name") == "WATCH", "the other one, too far, does not hear it")
	await physics(40)
	check(first.call(&"state_name") in ["HOME", "WATCH"], "forgotten: it walks back home (%s)" % first.call(&"state_name"))


func test_guards_look_at_night() -> void:
	var scene := _yard()
	var first := (scene.get(&"guards") as Array[CharacterBody3D])[0]
	var sensor := first.get(&"sensor") as PerceptionSensor3D
	scene.call(&"set_night", true)
	(scene.get_node(^"Player") as Node3D).global_position = Vector3(-6, 0.9, -6)
	await physics(10)
	check(not sensor.sees_any(), "at night, 8.5 m away is out of its sight (7 m)")
	scene.call(&"set_night", false)
	await physics(20)
	check(sensor.sees_any() and first.call(&"state_name") == "LOOK", "by day it sees you and looks at you")


func test_guards_lamp_in_shade() -> void:
	var scene := _yard()
	var sensor := (scene.get(&"guards") as Array[CharacterBody3D])[0].get(&"sensor") as PerceptionSensor3D
	(scene.get_node(^"Player") as Node3D).global_position = Vector3(10, 0.9, 6)
	await physics(10)
	var target := scene.get_node(^"Player/Target") as PerceptionTarget3D
	var lamp := scene.get_node(^"Player/Lamp") as PerceptionTarget3D
	check(near(target.visibility, 0.3), "in the shade your visibility drops")
	check(not sensor.sees(target) and not sensor.sees(lamp), "28 m away in the shade: unseen")
	_key(scene, KEY_L)
	check(lamp.enabled, "L lights the lamp")
	# The watching guard sweeps its head; within a sweep it faces the lamp.
	var frames := 0
	while not sensor.sees(lamp) and frames < 300:
		await tree.physics_frame
		frames += 1
	check(sensor.sees(lamp) and sensor.stimulus_of(lamp).kind == &"light", "your lamp is seen from there, as light (%d frames)" % frames)
	check(not sensor.sees(target), "and you still are not")
