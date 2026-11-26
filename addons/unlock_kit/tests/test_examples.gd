extends "res://addons/unlock_kit/tests/unlock_test.gd"

## The minimal example plays as a person would: clicks on the boxes of the view (through the viewport), the "+3 points"
## and "Reset" buttons, the log, and the Aqueduct entry's own signal wired in the editor.

const MINIMAL := preload("res://addons/unlock_kit/examples/minimal/minimal.tscn")


func test_minimal_plays() -> void:
	var scene := MINIMAL.instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	var unlocks := scene.get_node(^"%Tree") as UnlockTree
	var view := scene.get_node(^"%View") as UnlockTreeView
	var points := scene.get_node(^"%Points") as Label
	var log_label := scene.get_node(^"%Log") as Label
	var add_points := scene.get_node(^"%AddPoints") as Button
	var reset := scene.get_node(^"%Reset") as Button
	check(unlocks.graph.ids().size() == 9, "nine entries in three branches: %s" % [unlocks.graph.ids()])
	check(unlocks.requires(&"Aqueduct") == ([&"Irrigation", &"Masonry"] as Array[StringName]), "the cross link")
	check(unlocks.requires_any(&"Market") == ([&"Pottery", &"Writing"] as Array[StringName]), "the one-of link")
	check(unlocks.unlocked_ids() == ([&"Farming"] as Array[StringName]), "Farming is a starting tech")
	check(points.text == "Points: 2", "starts with 2 points: %s" % points.text)
	check(view.get_global_rect().has_point(_center(view, &"Market")), "every box is on screen")
	check(view.get_combined_minimum_size().x >= view.box_rect(&"Aqueduct").end.x, "the view fits the tree")

	_click(view, &"Market")
	check(log_label.text.begins_with("Market needs Pottery or Writing first"), "one of: %s" % log_label.text)
	_click(view, &"Irrigation")
	check(unlocks.is_unlocked(&"Irrigation") and points.text == "Points: 0", "a click buys: pays 2 and unlocks")
	check(log_label.text.begins_with("Unlocked Irrigation for 2 points"), "the log says it: %s" % log_label.text)
	_click(view, &"Pottery")
	check(not unlocks.is_unlocked(&"Pottery"), "no points left")
	check(log_label.text.begins_with("Pottery costs 1 points (you have 0)"), "why: %s" % log_label.text)
	_click(view, &"Aqueduct")
	check(log_label.text.begins_with("Aqueduct needs Masonry first"), "the missing requirement: %s" % log_label.text)
	_click(view, &"Farming")
	check(log_label.text.begins_with("Farming is already unlocked"), "already unlocked: %s" % log_label.text)

	add_points.pressed.emit()
	check(points.text == "Points: 3", "+3 points")
	_click(view, &"Masonry")
	check(unlocks.is_unlocked(&"Masonry") and points.text == "Points: 1", "Masonry")
	add_points.pressed.emit()
	_click(view, &"Aqueduct")
	check(unlocks.is_unlocked(&"Aqueduct") and points.text == "Points: 0", "Aqueduct, with both requirements")
	check(log_label.text.contains("Aqueduct.unlocked reached the scene"), "the entry's signal, wired in the editor")
	add_points.pressed.emit()
	_click(view, &"Pottery")
	check(unlocks.is_unlocked(&"Pottery") and points.text == "Points: 2", "Pottery")
	_click(view, &"Market")
	check(
		log_label.text.begins_with("Market costs 3 points (you have 2)"), "Pottery opened Market: %s" % log_label.text
	)
	add_points.pressed.emit()
	_click(view, &"Market")
	check(unlocks.is_unlocked(&"Market") and points.text == "Points: 2", "Market, with one of its two")

	reset.pressed.emit()
	check(unlocks.unlocked_ids() == ([&"Farming"] as Array[StringName]), "Reset: only Farming again")
	check(points.text == "Points: 2" and log_label.text.begins_with("Reset"), "and 2 points")
	scene.queue_free()
	await tree.process_frame


func test_editor_view_needs_no_play() -> void:
	# What the editor shows: the scene, not running, already has its graph and its boxes.
	var scene := MINIMAL.instantiate()
	var view := scene.get_node(^"%View") as UnlockTreeView
	check(view.box_rect(&"Aqueduct").size == view.box_size, "boxes before entering the scene tree")
	check(view.tree.is_unlocked(&"Farming"), "and the starting tech")
	scene.free()


func _center(view: UnlockTreeView, id: StringName) -> Vector2:
	return view.get_global_transform() * view.box_rect(id).get_center()


# A left click at the box's center, through the viewport like a mouse.
func _click(view: UnlockTreeView, id: StringName) -> void:
	var at := _center(view, id)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	tree.root.push_input(motion)
	for pressed: bool in [true, false]:
		var button := InputEventMouseButton.new()
		button.position = at
		button.global_position = at
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = pressed
		tree.root.push_input(button)
