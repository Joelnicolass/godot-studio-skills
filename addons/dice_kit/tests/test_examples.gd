extends "res://addons/dice_kit/tests/dice_test.gd"

## The minimal example plays as a person would: roll 1, 2 or 3 dice, read the label once they settle, type a seed and
## see the same rolls come back.


func test_minimal_runs() -> void:
	var scene := (load("res://addons/dice_kit/examples/minimal/minimal.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	var roller := scene.get_node(^"%Roller") as DiceRoller
	var tray := scene.get_node(^"%Tray") as DiceTray3D
	var seed_box := scene.get_node(^"%Seed") as SpinBox
	var result := scene.get_node(^"%Result") as Label
	check(roller.die != null and roller.die.sides() == 6, "a custom die of 6 faces in the inspector")
	check(roller._get_configuration_warnings().is_empty(), "the roller has no warnings")
	check(tray.dice_shown() == 3, "3 dice at rest before the first roll")
	_press(scene, ^"%Roll2")
	check(result.text == "Rolling..." and tray.is_tumbling(), "the dice tumble: %s" % result.text)
	await _settle(tray)
	var roll := roller.last_roll
	check(roll.size() == 2 and tray.dice_shown() == 2, "2 dice on the table")
	check(result.text.begins_with("Sum %d · %d hit" % [roll.sum(), roll.count(&"hit")]), "the label: %s" % result.text)
	check(result.text.contains("crit!") == roll.has(&"crit"), "crit! only when a crit came up")
	check(tray.face_on_top(1) == roll.faces[1], "the tray shows what came up")
	seed_box.value = 7
	var first := await _roll_three(scene, tray, roller)
	check(first == ([5, 1, 4] as Array[int]), "seed 7 rolls crit, hit, blank: %s" % [first])
	check(result.text == "Sum 3 · 1 hit · crit!", "and the label reads it: %s" % result.text)
	var second := await _roll_three(scene, tray, roller)
	seed_box.value = 8
	seed_box.value = 7
	check(await _roll_three(scene, tray, roller) == first, "seed 7 again: the same first roll %s" % [first])
	check(await _roll_three(scene, tray, roller) == second, "and the same second roll %s" % [second])
	_press(scene, ^"%Roll1")
	await _settle(tray)
	check(roller.last_roll.size() == 1 and tray.dice_shown() == 1, "Roll 1 rolls one die")
	scene.queue_free()
	await tree.process_frame


func _roll_three(scene: Node, tray: DiceTray3D, roller: DiceRoller) -> Array[int]:
	_press(scene, ^"%Roll3")
	await _settle(tray)
	return roller.last_roll.indices


func _press(scene: Node, path: NodePath) -> void:
	(scene.get_node(path) as Button).pressed.emit()


func _settle(tray: DiceTray3D) -> void:
	var start := Time.get_ticks_msec()
	while tray.is_tumbling() and Time.get_ticks_msec() - start < 5000:
		await tree.process_frame
