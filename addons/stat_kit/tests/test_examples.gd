extends "res://addons/stat_kit/tests/stat_test.gd"

## The minimal example plays as a person would: the sword starts equipped, the toggles add and remove one modifier,
## one ring resource is worn on both hands, Bless stacks two modifiers of one source, defense stops at its maximum, and
## Remove blessing takes every blessing modifier away at once.


func test_minimal_runs() -> void:
	var scene := (load("res://addons/stat_kit/examples/minimal/minimal.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	var hero := scene.get_node(^"%Hero") as StatBlock
	var sword := scene.get_node(^"%Sword") as Button
	var shield := scene.get_node(^"%Shield") as Button
	var swamp := scene.get_node(^"%Swamp") as Button
	var left_ring := scene.get_node(^"%LeftRing") as Button
	var right_ring := scene.get_node(^"%RightRing") as Button
	var bless := scene.get_node(^"%Bless") as Button
	var remove_blessing := scene.get_node(^"%RemoveBlessing") as Button
	var values := scene.get_node(^"%Values") as Label
	var log_label := scene.get_node(^"%Log") as Label
	check(hero.start_modifiers.size() == 1 and sword.button_pressed, "the sword starts equipped, from the inspector")
	check(values.text.contains("attack 7: base 5, +2 attack (sword)"), "the card shows it: %s" % values.text)
	check(sword.text == "+2 attack (sword)" and swamp.text == "= 1 moves (swamp)", "the toggles say what they do")
	check(left_ring.text == "+50 % attack (left_ring)", "each ring button names its hand: %s" % left_ring.text)
	check(remove_blessing.disabled, "nothing to remove yet")
	sword.button_pressed = false
	check(hero.value(&"attack") == 5.0 and values.text.contains("attack 5: base 5\n"), "unequipped: %s" % values.text)
	check(log_label.text.begins_with("Removed +2 attack (sword)\nattack is now 5"), "the log: %s" % log_label.text)
	sword.button_pressed = true
	left_ring.button_pressed = true
	check(hero.value(&"attack") == 10.5, "one ring: (5 + 2) × 1.5")
	right_ring.button_pressed = true
	check(hero.value(&"attack") == 14.0, "two rings add up: (5 + 2) × (1 + 0.5 + 0.5) = 14, not 15.75")
	check(values.text.contains("+50 % attack (left_ring), +50 % attack (right_ring)"), "one .tres, two sources")
	left_ring.button_pressed = false
	check(hero.value(&"attack") == 10.5 and hero.sources() == ([&"sword", &"right_ring"] as Array[StringName]), "left")
	shield.button_pressed = true
	check(hero.value(&"defense") == 6.0, "shield: 4 × 1.5")
	bless.pressed.emit()
	check(hero.value(&"defense") == 9.0, "ADD before MUL: (4 + 2) × 1.5 = 9, not 4 × 1.5 + 2")
	check(hero.value(&"moves") == 4.0 and not remove_blessing.disabled, "+1 moves, and something to remove")
	check(values.text.contains("defense 9 (max 10): base 4, ×1.5 defense (shield), +2 defense (blessing)"), values.text)
	swamp.button_pressed = true
	check(hero.value(&"moves") == 1.0, "SET last: the swamp fixes moves at 1 over the base and the blessing")
	bless.pressed.emit()
	check(hero.value(&"defense") == 10.0, "a second blessing stacks to (4 + 4) × 1.5 = 12, and the maximum keeps 10")
	check(values.text.contains("moves 1: base 3, +1 moves (blessing), = 1 moves (swamp), +1 moves (blessing)"), "list")
	remove_blessing.pressed.emit()
	check(log_label.text.begins_with("Removed 4 modifiers of blessing"), "every one of the source: %s" % log_label.text)
	check(hero.value(&"defense") == 6.0 and hero.value(&"moves") == 1.0, "back to the shield and the swamp")
	check(remove_blessing.disabled and not values.text.contains("blessing"), "no blessing left: %s" % values.text)
	swamp.button_pressed = false
	check(hero.value(&"moves") == 3.0, "out of the swamp")
	scene.queue_free()
	await tree.process_frame
