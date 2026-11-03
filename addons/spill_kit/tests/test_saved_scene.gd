extends "res://addons/spill_kit/tests/spill_test.gd"

## A scene saved after it spilled, and loaded again: its values come back, and nothing the kit drew
## or the wound was saved (Godot sets a node's own properties before its script runs, so the kit
## never sets a value of yours in _init()).

const PATH := "user://spillkit_saved_scene.tscn"


func test_a_saved_scene_keeps_its_values_and_nothing_drawn() -> void:
	var level := Node3D.new()
	level.name = "Level"
	root.add_child(level)
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(10, 0.2, 10)
	shape.shape = box_shape
	shape.position = Vector3(0, -0.1, 0)
	floor_body.add_child(shape)
	level.add_child(floor_body)
	var pool := SpillPool3D.new()
	pool.name = "Pool"
	pool.floor_mask = 5
	pool.marks_per_type = 32
	level.add_child(pool)
	var type := new_type({"color": Color.DARK_GREEN})
	var source := SpillSource3D.new()
	source.name = "Spill"
	source.type = type
	source.heavy_from = 0.3
	source.every_s = 0.5
	source.position = Vector3(0, 1, 0)
	level.add_child(source)
	for node: Node in [floor_body, shape, pool, source]:
		node.owner = level
	await physics()
	source.hit(50, 100)
	source.die()
	check(pool.mark_count(type) == 3 and pool.puddles_of(type).size() == 1, "it spilled before saving")
	var packed := PackedScene.new()
	check(packed.pack(level) == OK, "packed")
	check(ResourceSaver.save(packed, PATH) == OK, "saved")
	var text := FileAccess.get_file_as_string(PATH)
	for word in ["CPUParticles3D", "MultiMesh", "MeshInstance3D", "wound"]:
		check(not text.contains(word), "nothing drawn and no wound in the file (%s)" % word)
	level.queue_free()
	await tree.process_frame
	var again := (ResourceLoader.load(PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()
	root.add_child(again)
	var loaded_pool := again.get_node(^"Pool") as SpillPool3D
	var loaded := again.get_node(^"Spill") as SpillSource3D
	check(loaded_pool.floor_mask == 5 and loaded_pool.marks_per_type == 32, "the pool's values")
	check(near(loaded.heavy_from, 0.3) and near(loaded.every_s, 0.5), "the source's values")
	check(loaded.type != null and loaded.type.color == Color.DARK_GREEN, "its type")
	check(loaded.wound == Vector4.ZERO, "a fresh wound")
	check(loaded_pool.mark_count(loaded.type) == 0, "a clean floor")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
