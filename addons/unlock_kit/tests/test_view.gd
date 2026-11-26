extends "res://addons/unlock_kit/tests/unlock_test.gd"

## UnlockTreeView: columns by depth (or rows, top to bottom), rows in tree order, view_position, the minimum size,
## clicks, hover, tooltips, requires_any, the corner radius and the theme's font, an entry_scene per box and redrawing
## after the tree changes.

const ENTRY_BUTTON := """extends Button

var entry_id: StringName
var tree: UnlockTree
"""


func _build() -> UnlockTreeView:
	var unlocks := UnlockTree.new()
	var farming := _entry("Farming", {}, "Grow food.")
	farming.start_unlocked = true
	unlocks.add_child(farming)
	var irrigation := _entry("Irrigation", {&"points": 2}, "Water.")
	farming.add_child(irrigation)
	var aqueduct := _entry("Aqueduct", {&"points": 4, &"stone": 1}, "Water from far away.")
	irrigation.add_child(aqueduct)
	var masonry := _entry("Masonry", {&"points": 2}, "")
	unlocks.add_child(masonry)
	aqueduct.requires = [masonry]
	var view := UnlockTreeView.new()
	view.box_size = Vector2(100, 40)
	view.gap = Vector2(20, 10)
	view.tree = unlocks
	view.add_child(unlocks)
	tree.root.add_child(view)
	return view


func _entry(entry_name: String, cost: Dictionary[StringName, int], text: String) -> UnlockEntry:
	var entry := UnlockEntry.new()
	entry.name = entry_name
	entry.cost = cost
	entry.description = text
	return entry


func test_layout() -> void:
	var view := _build()
	var farming := view.box_rect(&"Farming")
	var masonry := view.box_rect(&"Masonry")
	var irrigation := view.box_rect(&"Irrigation")
	var aqueduct := view.box_rect(&"Aqueduct")
	check(farming.size == Vector2(100, 40), "box_size")
	check(is_equal_approx(farming.position.x, masonry.position.x), "the roots share column 0")
	check(masonry.position.y - farming.position.y == 50.0, "rows in tree order, gap.y apart")
	check(irrigation.position.x - farming.position.x == 120.0, "depth 1 is one column right, gap.x apart")
	check(aqueduct.position.x - farming.position.x == 240.0, "Aqueduct sits after its deepest requirement")
	check(view.box_rect(&"walls") == Rect2(), "no box: an empty rect")
	var size := view.get_combined_minimum_size()
	check(size.x >= aqueduct.end.x and size.y >= masonry.end.y, "the minimum size fits the tree: %s" % size)
	view.box_size = Vector2(60, 30)
	check(view.box_rect(&"Irrigation").position.x - view.box_rect(&"Farming").position.x == 80.0, "a new box_size")
	view.free()


func test_entry_at() -> void:
	var view := _build()
	var aqueduct := view.box_rect(&"Aqueduct")
	check(view.entry_at(aqueduct.get_center()) == &"Aqueduct", "inside a box")
	check(view.entry_at(aqueduct.position + Vector2(-5, 5)) == &"", "in the gap")
	view.free()


func test_click_and_hover() -> void:
	var view := _build()
	var pressed: Array[StringName] = []
	var hovered: Array[StringName] = []
	view.entry_pressed.connect(func(id: StringName) -> void: pressed.append(id))
	view.entry_hovered.connect(func(id: StringName) -> void: hovered.append(id))
	var center := view.box_rect(&"Irrigation").get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = center
	view._gui_input(motion)
	view._gui_input(motion)
	check(hovered == ([&"Irrigation"] as Array[StringName]), "hovered once: %s" % [hovered])
	var right := InputEventMouseButton.new()
	right.position = center
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	view._gui_input(right)
	check(pressed.is_empty(), "the right button does nothing")
	var left := InputEventMouseButton.new()
	left.position = center
	left.button_index = MOUSE_BUTTON_LEFT
	left.pressed = true
	view._gui_input(left)
	check(pressed == ([&"Irrigation"] as Array[StringName]), "a left click reports the id")
	check(not view.tree.is_unlocked(&"Irrigation"), "the view never unlocks by itself")
	motion.position = Vector2(-50, -50)
	view._gui_input(motion)
	check(hovered == ([&"Irrigation", &""] as Array[StringName]), 'off the boxes: &""')
	motion.position = center
	view._gui_input(motion)
	view.notification(Control.NOTIFICATION_MOUSE_EXIT)
	check(hovered == ([&"Irrigation", &"", &"Irrigation", &""] as Array[StringName]), 'leaving the view: &"" too')
	view.free()


func test_tooltip() -> void:
	var view := _build()
	var tip := view._get_tooltip(view.box_rect(&"Aqueduct").get_center())
	check(tip.contains("Aqueduct") and tip.contains("Water from far away."), "title and description: %s" % tip)
	check(tip.contains("Cost: 4 points, 1 stone"), "the cost: %s" % tip)
	check(tip.contains("Needs: Irrigation, Masonry"), "what is missing: %s" % tip)
	var farming := view._get_tooltip(view.box_rect(&"Farming").get_center())
	check(farming.contains("Unlocked") and not farming.contains("Cost"), "an unlocked root: %s" % farming)
	check(view._get_tooltip(Vector2(-10, -10)) == "", "no box: no tooltip")
	view.free()


func test_redraws_with_the_tree() -> void:
	var view := _build()
	await tree.process_frame
	var draws: Array[int] = [0]
	view.draw.connect(func() -> void: draws[0] += 1)
	view.tree.unlock(&"Irrigation")
	await tree.process_frame
	check(draws[0] == 1, "an unlock redraws once")
	var walls := _entry("Walls", {&"points": 3}, "")
	view.tree.entry(&"Masonry").add_child(walls)
	await tree.process_frame
	check(view.box_rect(&"Walls").position.x > view.box_rect(&"Masonry").position.x, "a new entry gets a box")
	check(draws[0] == 2, "and the view redraws: %d" % draws[0])
	check(view._get_configuration_warnings().is_empty(), "no warnings with a tree")
	var unlocks := view.tree
	view.tree = null
	check(view.box_rect(&"Walls") == Rect2() and view.get_combined_minimum_size() == Vector2.ZERO, "no tree: nothing")
	check(view._get_configuration_warnings().size() == 1, "a warning without a tree")
	unlocks.unlock(&"Masonry")
	check(unlocks.rebuilt.get_connections().is_empty(), "the old tree is no longer heard")
	view.free()


func test_requires_any_tooltip_and_draw() -> void:
	var view := _build()
	await tree.process_frame
	var draws: Array[int] = [0]
	view.draw.connect(func() -> void: draws[0] += 1)
	var market := _entry("Market", {&"points": 1}, "")
	view.tree.add_child(market)
	market.requires_any = [view.tree.entry(&"Irrigation"), view.tree.entry(&"Masonry")]
	var tip := view._get_tooltip(view.box_rect(&"Market").get_center())
	check(tip.contains("Needs one of: Irrigation, Masonry"), "one of: %s" % tip)
	check(not tip.contains("Needs: "), "and no requirement of all: %s" % tip)
	view.tree.unlock(&"Masonry")
	tip = view._get_tooltip(view.box_rect(&"Market").get_center())
	check(not tip.contains("Needs"), "one is unlocked: nothing missing: %s" % tip)
	await tree.process_frame
	check(draws[0] >= 1, "the dashed links draw")
	view.free()


func test_view_position() -> void:
	var view := _build()
	var masonry := view.tree.entry(&"Masonry")
	masonry.view_position = Vector2(400, 10)
	check(view.box_rect(&"Masonry").position == Vector2(400, 10), "the entry's view_position wins")
	check(view.box_rect(&"Farming").position.y == view.box_rect(&"Irrigation").position.y, "its column closes up")
	check(view.get_combined_minimum_size().x >= 500.0, "the minimum size reaches it")
	check(view.entry_at(Vector2(450, 30)) == &"Masonry", "and clicks find it there")
	masonry.view_position = Vector2.ZERO
	check(view.box_rect(&"Masonry").position.x == view.box_rect(&"Farming").position.x, "(0, 0): the column again")
	view.free()


func test_entry_scene() -> void:
	var view := _build()
	var pressed: Array[StringName] = []
	var hovered: Array[StringName] = []
	view.entry_pressed.connect(func(id: StringName) -> void: pressed.append(id))
	view.entry_hovered.connect(func(id: StringName) -> void: hovered.append(id))
	view.entry_scene = _button_scene()
	await tree.process_frame
	var buttons := _buttons(view)
	check(buttons.size() == 4, "one instance per entry: %d" % buttons.size())
	for button in buttons:
		var id: StringName = button.get(&"entry_id")
		var given: UnlockTree = button.get(&"tree")
		check(given == view.tree, "%s gets the tree" % id)
		check(button.position == view.box_rect(id).position and button.size == view.box_size, "%s sits on its box" % id)
	var irrigation := _button_of(view, &"Irrigation")
	irrigation.pressed.emit()
	check(pressed == ([&"Irrigation"] as Array[StringName]), "a pressed button is entry_pressed")
	irrigation.mouse_entered.emit()
	irrigation.mouse_exited.emit()
	check(hovered == ([&"Irrigation", &""] as Array[StringName]), "and the pointer is entry_hovered")
	view.tree.entry(&"Masonry").add_child(_entry("Walls", {}, ""))
	await tree.process_frame
	check(_buttons(view).size() == 5, "a new entry gets its instance")
	check(view._get_configuration_warnings().is_empty(), "a scene that keeps the contract: no warning")
	view.entry_scene = null
	await tree.process_frame
	check(_buttons(view).is_empty(), "no entry_scene: the view draws the boxes again")
	var label := Label.new()
	var wrong := PackedScene.new()
	wrong.pack(label)
	label.free()
	view.entry_scene = wrong
	check(view._get_configuration_warnings().size() == 1, "a scene without entry_id and tree: a warning")
	await tree.process_frame
	check(view.get_children(true).filter(func(node: Node) -> bool: return node is Label).is_empty(), "and no instance")
	view.free()


func test_top_to_bottom() -> void:
	var view := _build()
	view.direction = UnlockTreeView.Direction.TOP_TO_BOTTOM
	var farming := view.box_rect(&"Farming")
	var masonry := view.box_rect(&"Masonry")
	var irrigation := view.box_rect(&"Irrigation")
	var aqueduct := view.box_rect(&"Aqueduct")
	check(farming.position.y == masonry.position.y, "the roots share row 0")
	check(masonry.position.x - farming.position.x == 120.0, "side by side, gap.x apart")
	check(irrigation.position.y - farming.position.y == 50.0, "depth 1 is one row down, gap.y apart")
	check(aqueduct.position.y - farming.position.y == 100.0, "Aqueduct two rows down")
	var size := view.get_combined_minimum_size()
	check(size.x >= masonry.end.x and size.y >= aqueduct.end.y, "the minimum size fits: %s" % size)
	view.tree.entry(&"Masonry").view_position = Vector2(300, 300)
	check(view.box_rect(&"Masonry").position == Vector2(300, 300), "view_position still wins")
	var draws: Array[int] = [0]
	view.draw.connect(func() -> void: draws[0] += 1)
	view.queue_redraw()
	await tree.process_frame
	check(draws[0] >= 1, "the curves go down without errors")
	view.direction = UnlockTreeView.Direction.LEFT_TO_RIGHT
	check(view.box_rect(&"Irrigation").position.x > view.box_rect(&"Farming").position.x, "back to columns")
	view.free()


func test_corner_radius_and_theme_font() -> void:
	var view := _build()
	await tree.process_frame
	check(view.corner_radius == 6, "6 by default")
	view.corner_radius = 12
	await tree.process_frame
	check(view._style.corner_radius_top_left == 12, "the drawn boxes use it")
	var parent := Control.new()
	tree.root.add_child(parent)
	view.reparent(parent)
	var theme := Theme.new()
	var game_font := FontVariation.new()
	theme.default_font = game_font
	parent.theme = theme
	check(view._font() == game_font, "a Theme's default_font above the view")
	var label_font := FontVariation.new()
	theme.set_font(&"font", &"Label", label_font)
	var draws: Array[int] = [0]
	view.draw.connect(func() -> void: draws[0] += 1)
	await tree.process_frame
	check(view._font() == label_font, "and its Label font, when it sets one")
	check(draws[0] >= 1, "a theme change redraws the view")
	parent.theme = null
	check(view._font() != game_font and view._font() != label_font, "no Theme: the project's font")
	parent.free()


func _button_scene() -> PackedScene:
	var script := GDScript.new()
	script.source_code = ENTRY_BUTTON
	script.reload()
	var button := Button.new()
	button.set_script(script)
	var scene := PackedScene.new()
	scene.pack(button)
	button.free()
	return scene


func _buttons(view: UnlockTreeView) -> Array[Button]:
	var list: Array[Button] = []
	for node in view.get_children(true):
		if node is Button:
			list.append(node as Button)
	return list


func _button_of(view: UnlockTreeView, id: StringName) -> Button:
	for button in _buttons(view):
		if button.get(&"entry_id") == id:
			return button
	return null
