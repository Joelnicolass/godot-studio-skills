extends "res://addons/dice_kit/tests/dice_test.gd"

## DiceTray3D: the roller's dice at rest, a roll that tumbles and settles face up, what each die shows on top, the
## same tumble for the same roll with no random numbers drawn, rows, a mesh of its own, following the roller without
## polling, restyling and errors.


func _tray(roller: DiceRoller = null, tumble := 0.15) -> DiceTray3D:
	var tray := DiceTray3D.new()
	tray.tumble_time = tumble
	tray.roller = roller
	tree.root.add_child(tray)
	return tray


func _roller(count := 3, die: DieData = null) -> DiceRoller:
	var roller := DiceRoller.new()
	roller.die = die if die != null else DieData.numbered(6)
	roller.count = count
	roller.rng_seed = 5
	tree.root.add_child(roller)
	return roller


func test_rest() -> void:
	var roller := _roller(3)
	var tray := _tray(roller)
	check(tray.dice_shown() == 3 and tray.shown_roll == null, "the roller's count dice at rest")
	check(tray.face_on_top(0).value == 1 and tray.face_on_top(2).value == 1, "first face up")
	check(not tray.is_tumbling() and tray.face_on_top(3) == null, "not tumbling; out of range is null")
	var lonely := _tray()
	check(lonely.dice_shown() == 0, "no roller: an empty table")
	tray.free()
	lonely.free()
	roller.free()


func test_roller_roll_tumbles_and_settles() -> void:
	var roller := _roller(3)
	var tray := _tray(roller)
	var settled: Array[DiceRoll] = []
	tray.settled.connect(func(roll: DiceRoll) -> void: settled.append(roll))
	var roll := roller.roll(2)
	check(tray.is_tumbling() and tray.shown_roll == roll and tray.dice_shown() == 2, "a roll from the roller tumbles")
	await _wait(tray)
	check(settled == ([roll] as Array[DiceRoll]), "settled once, with the roll")
	check(tray.face_on_top(0) == roll.faces[0] and tray.face_on_top(1) == roll.faces[1], "the faces that came up")
	var dice := _dice(tray)
	var at_rest := true
	for die in dice:
		at_rest = at_rest and die.basis.is_equal_approx(Basis.IDENTITY) and is_equal_approx(die.position.y, 0.3)
	check(at_rest, "flat, face up, on the tray's plane")
	check(is_equal_approx(dice[1].position.x - dice[0].position.x, tray.spacing), "spacing apart")
	check(is_equal_approx(dice[0].position.x + dice[1].position.x, 0.0), "centered on the tray")
	tray.free()
	roller.free()


func test_land_at_once() -> void:
	var tray := _tray(null, 0.0)
	var heard := [0]
	tray.settled.connect(func(_roll: DiceRoll) -> void: heard[0] += 1)
	var d6 := DieData.numbered(6)
	tray.show_roll(DiceRoll.from_indices([d6, d6, d6, d6] as Array[DieData], [5, 0, 2, 3]))
	check(heard[0] == 1 and not tray.is_tumbling(), "tumble_time 0: settled right away")
	check(tray.face_on_top(0).value == 6 and tray.face_on_top(3).value == 4, "showing the roll")
	tray.free()


func test_what_is_on_top() -> void:
	var tray := _tray(null, 0.0)
	var icon := PlaceholderTexture2D.new()
	icon.size = Vector2(32, 32)
	var die := DieData.new()
	var double := DieFace.new(0)
	double.tags = [&"hit", &"hit", &"shield"] as Array[StringName]
	die.faces = [
		DieFace.new(1, &"hit", icon), DieFace.new(0, &"blank"), DieFace.new(2, &"crit"), DieFace.new(5), double
	]
	tray.show_roll(DiceRoll.from_indices([die, die, die, die, die] as Array[DieData], [0, 1, 2, 3, 4]))
	var tops := _tops(tray)
	check(tops[0] is Sprite3D and (tops[0] as Sprite3D).texture == icon, "a face with an icon shows the icon")
	check(tops[1] is Label3D and (tops[1] as Label3D).text == "blank", "a tag worth 0: the tag")
	check(tops[2] is Label3D and (tops[2] as Label3D).text == "2\ncrit", "a value and a tag")
	check(tops[3] is Label3D and (tops[3] as Label3D).text == "5", "a number")
	check(tops[4] is Label3D and (tops[4] as Label3D).text == "hit hit shield", "several tags")
	tray.free()


func test_same_roll_same_tumble() -> void:
	var d6 := DieData.numbered(6)
	var roll := DiceRoll.from_indices([d6, d6, d6] as Array[DieData], [1, 4, 2])
	var left := DiceTray3D.new()
	var right := DiceTray3D.new()
	seed(404)
	var expected := randi()
	seed(404)
	for tray in [left, right] as Array[DiceTray3D]:
		tray.tumble_time = 1.0
		tray.show_roll(roll)
	var same := true
	var moved := false
	for step in 5:
		left._process(0.17)
		right._process(0.17)
		var a := _dice(left)
		var b := _dice(right)
		for index in a.size():
			same = same and a[index].transform.is_equal_approx(b[index].transform)
			moved = moved or not a[index].basis.is_equal_approx(Basis.IDENTITY)
	check(moved, "the dice tumble")
	check(same, "two trays tumble the same roll the same way")
	check(randi() == expected, "the tumble drew no global random number")
	left._process(1.0)
	check(not left.is_tumbling() and left.face_on_top(1).value == 5, "and lands on the roll")
	left.free()
	right.free()


func test_faces_flip_while_tumbling() -> void:
	var d6 := DieData.numbered(6)
	var tray := DiceTray3D.new()
	tray.tumble_time = 1.0
	tray.show_roll(DiceRoll.from_indices([d6] as Array[DieData], [3]))
	var seen: Dictionary[int, bool] = {}
	for step in 10:
		seen[tray.face_on_top(0).value] = true
		tray._process(0.1)
	check(seen.size() > 2, "the top face changes while it tumbles: %s" % [seen.keys()])
	check(tray.face_on_top(0).value == 4, "and ends on the one that came up")
	tray.free()


func test_restyle() -> void:
	var roller := _roller(2)
	var tray := _tray(roller, 0.0)
	tray.show_roll(roller.roll(4))
	check(tray.dice_shown() == 4, "a roll of 4 shows 4 dice")
	tray.die_size = 1.0
	var dice := _dice(tray)
	check(dice.size() == 4 and is_equal_approx(dice[0].position.y, 0.5), "a new size redraws the same dice")
	check(tray.face_on_top(2) == roller.last_roll.faces[2], "with the same faces")
	tray.spacing = 2.0
	check(is_equal_approx(_dice(tray)[1].position.x - _dice(tray)[0].position.x, 2.0), "a new spacing too")
	tray.free()
	roller.free()


func test_follows_the_roller() -> void:
	var roller := _roller(2)
	var tray := _tray(roller, 0.0)
	check(not tray.is_processing(), "at rest it does not run every frame")
	roller.count = 3
	check(tray.dice_shown() == 3, "a new count on the roller shows its dice at rest at once (dice_changed)")
	roller.extra_dice = [DieData.numbered(8)] as Array[DieData]
	check(tray.dice_shown() == 4 and tray.face_on_top(3).value == 1, "an extra die too, first face up")
	roller.die = DieData.numbered(4)
	check(tray.face_on_top(0) == roller.die.faces[0], "a new die too")
	var roll := roller.roll()
	roller.count = 1
	check(tray.shown_roll == roll and tray.dice_shown() == 4, "in the game, a roll on the table stays")
	check(not tray.is_processing(), "and nothing runs after it landed")
	tray.free()
	roller.free()


func test_rows() -> void:
	var tray := _tray(null, 0.0)
	tray.per_row = 3
	var d6 := DieData.numbered(6)
	var pool: Array[DieData] = []
	for slot in 8:
		pool.append(d6)
	tray.show_roll(DiceRoll.from_indices(pool, [0, 1, 2, 3, 4, 5, 0, 1]))
	var dice := _dice(tray)
	check(dice.size() == 8, "8 dice")
	check(is_equal_approx(dice[0].position.z, -tray.spacing) and is_equal_approx(dice[3].position.z, 0.0), "3 rows")
	check(is_equal_approx(dice[6].position.z, tray.spacing), "the last row in front")
	check(is_equal_approx(dice[0].position.x, -tray.spacing) and is_equal_approx(dice[1].position.x, 0.0), "centered")
	check(is_equal_approx(dice[6].position.x, -tray.spacing * 0.5), "a short row is centered too")
	tray.per_row = 8
	check(is_equal_approx(_dice(tray)[7].position.z, 0.0), "one row again")
	tray.free()


func test_die_mesh() -> void:
	var tray := _tray(null, 0.0)
	var d20 := DieData.numbered(20)
	tray.show_roll(DiceRoll.from_indices([d20] as Array[DieData], [19]))
	check(_meshes(tray)[0].mesh is BoxMesh, "no die_mesh: a cube")
	var shape := CylinderMesh.new()
	shape.top_radius = 1.0
	shape.bottom_radius = 1.0
	shape.height = 4.0
	tray.die_mesh = shape
	var mesh := _meshes(tray)[0]
	check(mesh.mesh == shape and is_equal_approx(mesh.scale.x, 0.6 / 4.0), "the mesh, scaled to die_size")
	check(is_equal_approx(_dice(tray)[0].position.y, 0.3), "resting on the tray: half its scaled height")
	check(mesh.material_override is StandardMaterial3D, "a mesh without a material is painted die_color")
	check(tray.face_on_top(0).value == 20 and _tops(tray)[0].position.y > 0.3, "the face drawn above its top")
	shape.material = StandardMaterial3D.new()
	tray.die_mesh = shape
	check(_meshes(tray)[0].material_override == null, "a mesh with its own material keeps it")
	tray.free()


func test_mesh_per_die() -> void:
	var roller := _roller(2)
	var tray := _tray(roller, 0.0)
	var d8 := DieData.numbered(8)
	var prism := PrismMesh.new()
	prism.size = Vector3(1.0, 2.0, 1.0)
	d8.mesh = prism
	roller.extra_dice = [d8] as Array[DieData]
	tray.show_roll(roller.roll())
	var meshes := _meshes(tray)
	check(meshes.size() == 3 and meshes[0].mesh is BoxMesh and meshes[1].mesh is BoxMesh, "2d6 without a mesh: cubes")
	check(meshes[2].mesh == prism and is_equal_approx(meshes[2].scale.x, 0.3), "the d8 keeps its own, scaled")
	check(is_equal_approx(_dice(tray)[2].position.y, 0.3) and is_equal_approx(_dice(tray)[0].position.y, 0.3), "rest")
	var shape := CylinderMesh.new()
	tray.die_mesh = shape
	meshes = _meshes(tray)
	check(meshes[0].mesh == shape and meshes[2].mesh == prism, "die_mesh for the d6, its own for the d8")
	d8.mesh = null
	tray.show_roll(roller.roll())
	check(_meshes(tray)[2].mesh == shape, "a d8 without a mesh takes the tray's again")
	tray.free()
	roller.free()


func test_errors() -> void:
	var roller := _roller(2)
	var tray := _tray(roller)
	tray.show_roll(null)
	tray.show_roll(DiceRoll.new())
	check(tray.dice_shown() == 2 and tray.shown_roll == null, "a null or empty roll changes nothing")
	var holes := DieData.new()
	holes.faces = [null] as Array[DieFace]
	roller.die = holes
	tray.roller = roller
	check(tray.dice_shown() == 0, "a die with no faces to show: an empty table")
	tray.free()
	roller.free()


func test_a_new_roll_replaces() -> void:
	var tray := _tray(null, 1.0)
	var d6 := DieData.numbered(6)
	var heard: Array[DiceRoll] = []
	tray.settled.connect(func(roll: DiceRoll) -> void: heard.append(roll))
	tray.show_roll(DiceRoll.from_indices([d6, d6, d6] as Array[DieData], [0, 1, 2]))
	tray._process(0.3)
	var second := DiceRoll.from_indices([d6] as Array[DieData], [5])
	tray.show_roll(second)
	tray._process(1.0)
	check(heard == ([second] as Array[DiceRoll]) and tray.dice_shown() == 1, "only the new roll settles")
	tray.free()


func _wait(tray: DiceTray3D) -> void:
	var start := Time.get_ticks_msec()
	while tray.is_tumbling() and Time.get_ticks_msec() - start < 5000:
		await tree.process_frame


func _dice(tray: DiceTray3D) -> Array[Node3D]:
	var list: Array[Node3D] = []
	for child in tray.get_children(true):
		if child is Node3D:
			list.append(child as Node3D)
	return list


func _meshes(tray: DiceTray3D) -> Array[MeshInstance3D]:
	var list: Array[MeshInstance3D] = []
	for die in _dice(tray):
		for part in die.get_children():
			if part is MeshInstance3D:
				list.append(part as MeshInstance3D)
	return list


# The visible node on top of each die (its Label3D or its Sprite3D).
func _tops(tray: DiceTray3D) -> Array[Node3D]:
	var list: Array[Node3D] = []
	for die in _dice(tray):
		for part in die.get_children():
			if (part is Label3D or part is Sprite3D) and (part as Node3D).visible:
				list.append(part as Node3D)
	return list
