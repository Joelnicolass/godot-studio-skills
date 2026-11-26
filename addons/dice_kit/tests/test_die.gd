extends "res://addons/dice_kit/tests/dice_test.gd"

## DieFace and DieData alone: faces and their tags, numbered dice, the ready dice, rolling errors, empty slots and live
## changes.


func test_face() -> void:
	var blank := DieFace.new()
	check(blank.value == 0 and blank.tags.is_empty() and blank.icon == null, "a new face is empty")
	var hit := DieFace.new(2, &"hit")
	check(hit.value == 2 and hit.tags == ([&"hit"] as Array[StringName]), "value and one tag from _init")
	var heard := [0]
	hit.changed.connect(func() -> void: heard[0] += 1)
	hit.value = 3
	hit.tags = [&"hit", &"hit", &"shield"] as Array[StringName]
	check(heard[0] == 2, "a face says it changed: %d" % heard[0])
	check(hit.tag == &"hit", "tag reads the first of tags")
	hit.tag = &"crit"
	check(hit.tags == ([&"crit"] as Array[StringName]) and heard[0] == 3, "writing tag leaves only that one")
	hit.tag = &""
	check(hit.tags.is_empty() and hit.tag == &"", "an empty tag: no tags")


func test_a_saved_tag_still_loads() -> void:
	var path := "user://dicekit_old_face.tres"
	var text := (
		'[gd_resource type="Resource" script_class="DieFace" load_steps=2 format=3]\n\n'
		+ '[ext_resource type="Script" path="res://addons/dice_kit/resources/die_face.gd" id="1_face"]\n\n'
		+ '[resource]\nscript = ExtResource("1_face")\nvalue = 2\ntag = &"crit"\n'
	)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	var face := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as DieFace
	check(face != null and face.tags == ([&"crit"] as Array[StringName]), "a face saved with tag loads into tags")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var example := load("res://addons/dice_kit/examples/minimal/attack_die.tres") as DieData
	check(example.faces[5].tags == ([&"crit"] as Array[StringName]), "the example's die uses tags")


func test_numbered() -> void:
	var d6 := DieData.numbered(6)
	check(d6.sides() == 6, "six sides")
	var values: Array[int] = []
	for face in d6.faces:
		values.append(face.value)
	check(values == ([1, 2, 3, 4, 5, 6] as Array[int]), "faces worth 1 to 6: %s" % [values])
	check(DieData.numbered(0).sides() == 0, "no sides is an error and an empty die")


func test_ready_dice() -> void:
	for sides: int in [4, 6, 8, 10, 12, 20]:
		var path := "res://addons/dice_kit/dice/d%d.tres" % sides
		var die := load(path) as DieData
		check(die != null and die.sides() == sides, "%s loads with %d faces" % [path.get_file(), sides])
		if die == null:
			continue
		var ok := true
		for index in die.faces.size():
			ok = ok and die.faces[index].value == index + 1 and die.faces[index].tag == &""
		check(ok and die.mesh == null, "%s: faces 1 to %d, in order, no mesh of its own" % [path.get_file(), sides])


func test_roll() -> void:
	var rng := _rng(5)
	var roll := DieData.numbered(6).roll(4, rng)
	check(roll.size() == 4, "four dice")
	var in_range := true
	for value in roll.values():
		in_range = in_range and value >= 1 and value <= 6
	check(in_range, "every value is a face of the die: %s" % [roll.values()])


func test_roll_errors() -> void:
	var d6 := DieData.numbered(6)
	var rng := _rng(5)
	var state := rng.state
	check(d6.roll(0, rng).size() == 0, "n under 1: an empty roll")
	check(d6.roll(2, null).size() == 0, "no rng: an empty roll")
	check(DieData.new().roll(2, rng).size() == 0, "no faces: an empty roll")
	check(rng.state == state, "a roll that fails draws nothing")


func test_an_empty_slot_cannot_roll() -> void:
	var die := DieData.new()
	die.faces = [DieFace.new(1), null, DieFace.new(3)] as Array[DieFace]
	check(not die.can_roll() and not DieData.new().can_roll(), "an empty slot, or no faces: it cannot roll")
	check(DieData.numbered(6).can_roll(), "a full die can")
	var rng := _rng(11)
	var state := rng.state
	check(die.roll(3, rng).size() == 0, "an empty slot: an error and an empty roll")
	check(DiceRoll.of([DieData.numbered(6), die], rng).size() == 0, "also among other dice")
	check(rng.state == state, "and nothing drawn")


func test_changed_live() -> void:
	var die := DieData.numbered(2)
	var heard := [0]
	die.changed.connect(func() -> void: heard[0] += 1)
	var first := die.faces[0]
	first.value = 10
	check(heard[0] == 1, "a face inside changed: the die says so")
	die.faces = [DieFace.new(1)] as Array[DieFace]
	check(heard[0] == 2, "a new list too")
	first.value = 11
	check(heard[0] == 2 and first.changed.get_connections().is_empty(), "a face that left the list is not heard")
	die.mesh = PrismMesh.new()
	check(heard[0] == 3, "a new mesh too")
	var twice := DieFace.new(4)
	die.faces = [twice, twice] as Array[DieFace]
	check(twice.changed.get_connections().size() == 1, "a face listed twice is heard once")


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng
