extends RefCounted

## Base of every SpillKit test file: `check(cond, what)` records one result; `near(a, b)` compares
## floats and vectors. The runner calls each `test_*` method with `tree` set and frees `root` after.

var fails: int = 0
var passes: int = 0
var tree: SceneTree
## A node the test builds its scene under (added to the tree by the runner, freed after).
var root: Node


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		fails += 1
		print("  FAIL %s" % what)


func near(a: Variant, b: Variant, epsilon := 0.0001) -> bool:
	if a is float or a is int:
		return absf(float(a) - float(b)) <= epsilon
	if a is Vector2 or a is Vector3:
		return a.is_equal_approx(b) or (a - b).length() <= epsilon
	return a == b


## Waits for `frames` physics frames (colliders added to the tree are in the space after one).
func physics(frames := 2) -> void:
	for i in frames:
		await tree.physics_frame


## Waits [param seconds] of real time (the rules count real time between hits).
func wait_s(seconds: float) -> void:
	await tree.create_timer(seconds).timeout


## A static box whose top is centred on [param top], on [param layer] (1: the floor).
func box(top: Vector3, size := Vector3(20, 0.2, 20), layer := 1, turn := Basis.IDENTITY) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	body.transform = Transform3D(turn, top - turn * Vector3(0, size.y * 0.5, 0))
	root.add_child(body)
	return body


## A pool in the test's world.
func new_pool() -> SpillPool3D:
	var pool := SpillPool3D.new()
	root.add_child(pool)
	return pool


## A type with the kit's defaults, and any of its values changed by [param values].
func new_type(values := {}) -> SpillType:
	var type := SpillType.new()
	for key: String in values:
		type.set(key, values[key])
	return type


## A body (on layer 2, out of the floor) at [param feet] with a source at its chest, 1.2 m up.
func new_body(type: SpillType, feet := Vector3.ZERO) -> SpillSource3D:
	var body := CharacterBody3D.new()
	body.collision_layer = 2
	body.position = feet
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	shape.shape = capsule
	shape.position = Vector3(0, 1, 0)
	body.add_child(shape)
	var source := SpillSource3D.new()
	source.type = type
	source.position = Vector3(0, 1.2, 0)
	body.add_child(source)
	root.add_child(body)
	return source


## The kit's sprays of [param pool] in the air now.
func flying(pool: SpillPool3D) -> Array[CPUParticles3D]:
	var out: Array[CPUParticles3D] = []
	for child in pool.get_children(true):
		if child is CPUParticles3D and (child as CPUParticles3D).visible:
			out.append(child)
	return out
