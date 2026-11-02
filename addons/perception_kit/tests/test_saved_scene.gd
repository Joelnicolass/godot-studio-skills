extends "res://addons/perception_kit/tests/perception_test.gd"

## A scene saved and loaded again keeps the sides set in it: a sensor's mask and a target's
## layer, whatever they are (Godot loads a node's own properties before its script). What the
## kit sets itself (a sensor is not detectable, a target detects nothing) is neither shown nor
## saved.

const FILE := "user://perceptionkit_saved_scene.tscn"


func _round_trip(scene_root: Node) -> Node:
	for child in scene_root.get_children():
		child.owner = scene_root
	var packed := PackedScene.new()
	packed.pack(scene_root)
	scene_root.free()
	ResourceSaver.save(packed, FILE)
	var loaded := ResourceLoader.load(FILE, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	return loaded.instantiate()


func test_sides_survive_saving_3d() -> void:
	var scene_root := Node3D.new()
	var sensor := PerceptionSensor3D.new()
	sensor.name = &"Sensor"
	sensor.collision_mask = 1 << 7
	var target := PerceptionTarget3D.new()
	target.name = &"Target"
	target.collision_layer = 1 << 7
	var plain := PerceptionTarget3D.new()
	plain.name = &"Plain"
	scene_root.add_child(sensor)
	scene_root.add_child(target)
	scene_root.add_child(plain)
	var copy := _round_trip(scene_root)
	var saved := FileAccess.get_file_as_string(FILE)
	check((copy.get_node(^"Sensor") as PerceptionSensor3D).collision_mask == 1 << 7, "the sensor's mask (layer 8) comes back from the file (%d)" % (copy.get_node(^"Sensor") as PerceptionSensor3D).collision_mask)
	check((copy.get_node(^"Target") as PerceptionTarget3D).collision_layer == 1 << 7, "the target's layer (layer 8) comes back from the file")
	check((copy.get_node(^"Plain") as PerceptionTarget3D).collision_layer == 1, "a target left as it was is on layer 1, like any area")
	check((copy.get_node(^"Sensor") as PerceptionSensor3D).collision_layer == 0 and not (copy.get_node(^"Sensor") as Area3D).monitorable, "a sensor is never detectable")
	check((copy.get_node(^"Target") as PerceptionTarget3D).collision_mask == 0 and not (copy.get_node(^"Target") as Area3D).monitoring, "a target detects nothing")
	check(not saved.contains("monitorable") and not saved.contains("monitoring") and not saved.contains("collision_mask = 0"), "what the kit sets itself is not saved")
	(copy.get_node(^"Target") as Node3D).position = Vector3(0, 0, -5)
	(copy.get_node(^"Plain") as Node3D).position = Vector3(1, 0, -5)
	(copy.get_node(^"Sensor") as PerceptionSensor3D).sense_hz = 60.0
	root.add_child(copy)
	await physics(4)
	var loaded_sensor := copy.get_node(^"Sensor") as PerceptionSensor3D
	check(loaded_sensor.sees(copy.get_node(^"Target")) and not loaded_sensor.sees(copy.get_node(^"Plain")), "loaded, it sees its side only")


func test_sides_survive_saving_2d() -> void:
	var scene_root := Node2D.new()
	var sensor := PerceptionSensor2D.new()
	sensor.name = &"Sensor"
	sensor.collision_mask = 1 << 4
	var target := PerceptionTarget2D.new()
	target.name = &"Target"
	target.collision_layer = 1 << 4
	scene_root.add_child(sensor)
	scene_root.add_child(target)
	var copy := _round_trip(scene_root)
	check((copy.get_node(^"Sensor") as PerceptionSensor2D).collision_mask == 1 << 4, "2D: the sensor's mask comes back from the file")
	check((copy.get_node(^"Target") as PerceptionTarget2D).collision_layer == 1 << 4, "2D: the target's layer comes back from the file")
	check((copy.get_node(^"Sensor") as PerceptionSensor2D).collision_layer == 0 and (copy.get_node(^"Target") as PerceptionTarget2D).collision_mask == 0, "2D: the kit's own values")
	copy.free()


func test_out_of_the_box() -> void:
	var sensor := PerceptionSensor3D.new()
	var target := PerceptionTarget3D.new()
	check(sensor.collision_mask == 1 and target.collision_layer == 1, "out of the box, layer 1 like any area: every sensor sees every target")
	var shown: Array[String] = []
	for property in sensor.get_property_list():
		if property.usage & PROPERTY_USAGE_EDITOR:
			shown.append(property.name)
	check("collision_mask" in shown and not "collision_layer" in shown and not "monitorable" in shown and not "monitoring" in shown, "the sensor's inspector shows its mask only")
	shown.clear()
	for property in target.get_property_list():
		if property.usage & PROPERTY_USAGE_EDITOR:
			shown.append(property.name)
	check("collision_layer" in shown and not "collision_mask" in shown and not "monitorable" in shown and not "monitoring" in shown, "the target's inspector shows its layer only")
	sensor.free()
	target.free()
