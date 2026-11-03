extends "res://addons/spill_kit/tests/spill_test.gd"

## The examples, played with their own methods.

const MINIMAL := "res://addons/spill_kit/examples/minimal_3d/minimal_3d.tscn"
const SUBSTANCES := "res://addons/spill_kit/examples/substances_3d/substances_3d.tscn"


func test_minimal_3d() -> void:
	var scene: Node = (load(MINIMAL) as PackedScene).instantiate()
	root.add_child(scene)
	await physics()
	var spill: SpillSource3D = scene.get(&"spill")
	var pool := spill.current_pool()
	check(pool != null and pool.get_parent() == scene, "the scene's own pool")
	var blood := spill.type
	check(blood.resource_name == "Blood", "the blood type")
	scene.call(&"strike", 20.0)
	check(pool.sprays_played(blood) == 1 and pool.mark_count(blood) == 1, "a click: a spray and a mark")
	scene.call(&"strike", 50.0)
	check(SpillWound.is_heavy(spill.wound) and pool.mark_count(blood) == 4, "a right click: heavy, 3 more marks")
	scene.call(&"strike", 100.0)
	check(pool.puddles_of(blood).size() == 1, "dead: a puddle")
	check((scene.get(&"label") as Label).text.begins_with("HP 0"), "the label shows the HP")
	scene.call(&"reset")
	check(pool.mark_count(blood) == 0 and pool.puddles_of(blood).is_empty(), "R: a clean floor")


func test_substances_3d() -> void:
	var scene: Node = (load(SUBSTANCES) as PackedScene).instantiate()
	root.add_child(scene)
	await physics()
	var spills: Array = scene.get(&"spills")
	check(spills.size() == 6, "six dummies")
	var pool := (spills[0] as SpillSource3D).current_pool()
	var names: Array[String] = []
	for spill: SpillSource3D in spills:
		names.append(spill.type.resource_name)
	check(names == ["Blood", "Oil", "Slime", "Mercury", "Paint", "Ink"], "in the order of the keys (%s)" % [names])
	scene.call(&"strike_all", 50.0)
	for spill: SpillSource3D in spills:
		check(pool.sprays_played(spill.type) == 1, "%s sprays" % spill.type.resource_name)
		check(pool.mark_count(spill.type) == 3, "%s leaves its 3 heavy marks" % spill.type.resource_name)
	scene.call(&"kill_all")
	for spill: SpillSource3D in spills:
		check(pool.puddles_of(spill.type).size() == 1, "%s pools" % spill.type.resource_name)
	var slime: SpillSource3D = spills[2]
	var by_curb := pool.puddles_of(slime.type)
	if by_curb.size() == 1:
		# Its puddle starts small and grows; the side it grows to is the one that fit.
		await wait_s(slime.type.puddle_grow_s + 0.2)
		by_curb = pool.puddles_of(slime.type)
		check(by_curb[0].basis.x.length() < slime.type.puddle_size_m, "the slime's puddle shrank to stay off the curb (%.2f)" % by_curb[0].basis.x.length())
	var mercury: SpillSource3D = spills[3]
	var on_slope := pool.puddles_of(mercury.type)
	if on_slope.size() == 1:
		var ramp := Basis(Vector3.RIGHT, deg_to_rad(12))
		check(near(on_slope[0].basis.y.normalized(), ramp.y, 0.01), "the mercury's puddle lies along the ramp")
	var paint: SpillSource3D = spills[4]
	var marks := _marks_material(pool, paint.type)
	check(marks is ORMMaterial3D and (marks as ORMMaterial3D).normal_texture == paint.type.mark_normal_texture, "the paint's marks draw with its own normal and ORM textures")
	var ink: SpillSource3D = spills[5]
	check(_marks_material(pool, ink.type) is ShaderMaterial, "the ink draws with its own shader")
	scene.call(&"set_lamp", true)
	scene.call(&"set_night", true)
	check((scene.get(&"lamp") as SpotLight3D).visible, "L: the lamp")
	check((scene.get(&"label") as Label).text.contains("night"), "N: night")
	scene.call(&"reset")
	check(pool.mark_count(paint.type) == 0, "R: a clean floor")


func test_a_click_hits_the_dummy_under_the_mouse() -> void:
	var scene: Node = (load(SUBSTANCES) as PackedScene).instantiate()
	root.add_child(scene)
	await physics()
	var spills: Array = scene.get(&"spills")
	var camera: Camera3D = scene.get(&"camera")
	var oil: SpillSource3D = spills[1]
	var screen := camera.unproject_position(oil.global_position)
	check(scene.call(&"_dummy_at", screen) == 1, "the oil dummy is under its own chest")
	check(scene.call(&"_dummy_at", Vector2(2, 2)) == -1, "the sky is no dummy")


# The material the marks of [param type] draw with.
func _marks_material(pool: SpillPool3D, type: SpillType) -> Material:
	pool.prepare(type)
	return pool.material_of(type, SpillShapes.Shape.MARK)
