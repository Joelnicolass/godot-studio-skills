extends "res://addons/deck_kit/tests/deck_test.gd"

## The minimal example plays as a person would: draw until the hand is full, click a card to discard it (the copy under
## the pointer, among copies of Coin), refill the deck, and deal again with a seed, which gives the same draw order
## every time.

const SCENE := "res://addons/deck_kit/examples/minimal/minimal.tscn"


func _ids(list: Array[CardData]) -> Array[String]:
	var ids: Array[String] = []
	for card in list:
		ids.append(String(card.id))
	return ids


func _click(view: HandView, at: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	view._gui_input(down)
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	view._gui_input(up)


# The ids of the five cards drawn after dealing with `seed_value`, in the order drawn.
func _deal_and_draw(scene: Node, seed_value: int) -> Array[String]:
	var seed_box := scene.get_node(^"%Seed") as SpinBox
	var draw := scene.get_node(^"%Draw") as Button
	var hand := scene.get_node(^"%Hand") as CardPile
	seed_box.value = seed_value
	for i in 5:
		draw.pressed.emit()
	var drawn := _ids(hand.cards())
	drawn.reverse()
	return drawn


func test_minimal_plays() -> void:
	var scene := (load(SCENE) as PackedScene).instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	var deck := scene.get_node(^"%Deck") as Deck
	var hand := scene.get_node(^"%Hand") as CardPile
	var discard := scene.get_node(^"%Discard") as CardPile
	var view := scene.get_node(^"%HandView") as HandView
	var draw := scene.get_node(^"%Draw") as Button
	var refill := scene.get_node(^"%Refill") as Button
	var counts := scene.get_node(^"%Counts") as Label
	var log_label := scene.get_node(^"%Log") as Label
	check(deck.size() == 12 and deck.count_tag(&"event") == 3 and not deck.face_up, "12 cards face down, 3 events")
	check(deck.find_id(&"coin") != null and _ids(deck.cards()).count("coin") == 3, "Coin three times")
	check(counts.text.begins_with("Deck 12 · Hand 0/5 · Discard 0"), "the counts: %s" % counts.text)
	check(refill.disabled and not draw.disabled, "nothing to refill yet")
	var top := deck.top()[0]
	draw.pressed.emit()
	check(hand.top()[0] == top and log_label.text.begins_with("Drew " + top.title), "drew the top: %s" % log_label.text)
	for i in 4:
		draw.pressed.emit()
	check(hand.size() == 5 and deck.size() == 7 and draw.disabled, "the hand is full: Draw is off")
	var newest := hand.top()[0]
	check(view.card_rect(0).position.x > view.card_rect(4).position.x, "the newest card is on the right")
	var rect := view.card_rect(0)
	_click(view, rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.5))
	check(discard.top()[0] == newest and hand.size() == 4, "clicking a card discards it")
	check(log_label.text.begins_with("Discarded " + newest.title), "the log says so: %s" % log_label.text)
	check(not draw.disabled and not refill.disabled, "room in the hand, something to refill")
	var oldest_rect := view.card_rect(3)
	_click(view, oldest_rect.position + Vector2(6, oldest_rect.size.y * 0.5))
	check(discard.size() == 2 and hand.size() == 3, "the leftmost card too")
	refill.pressed.emit()
	check(deck.size() == 9 and discard.is_empty() and refill.disabled, "Refill puts the discard back in the deck")
	check(log_label.text.begins_with("Refilled 2 cards, shuffled"), "and says it: %s" % log_label.text)
	check(counts.text.contains("Deck 9 · Hand 3/5 · Discard 0"), "the counts follow: %s" % counts.text)
	var first := _deal_and_draw(scene, 7)
	check(log_label.text.contains("New deal, seed 7") and discard.is_empty(), "a new deal: %s" % log_label.text)
	var other := _deal_and_draw(scene, 8)
	var again := _deal_and_draw(scene, 7)
	check(first.size() == 5 and first == again, "the same seed, the same draw order: %s %s" % [first, again])
	check(other != first, "another seed, another order: %s" % [other])
	check(deck.size() + hand.size() + discard.size() == 12, "no card was lost or doubled")
	scene.queue_free()
	await tree.process_frame


func test_same_seed_twice_from_a_fresh_scene() -> void:
	var orders: Array[Array] = []
	for i in 2:
		var scene := (load(SCENE) as PackedScene).instantiate()
		tree.root.add_child(scene)
		await tree.process_frame
		var draw := scene.get_node(^"%Draw") as Button
		var hand := scene.get_node(^"%Hand") as CardPile
		for n in 5:
			draw.pressed.emit()
		orders.append(_ids(hand.cards()))
		scene.queue_free()
		await tree.process_frame
	check(orders[0] == orders[1], "seed 1 from the inspector deals the same hand on every start: %s" % [orders])


func test_clicking_a_copy_discards_that_copy() -> void:
	var scene := (load(SCENE) as PackedScene).instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	var hand := scene.get_node(^"%Hand") as CardPile
	var discard := scene.get_node(^"%Discard") as CardPile
	var view := scene.get_node(^"%HandView") as HandView
	# A seed whose first five cards hold two Coins with another card between them, so which copy left shows.
	var ids: Array[String] = []
	var seed_value := 0
	for candidate in range(1, 300):
		ids = _deal_and_draw(scene, candidate)
		ids.reverse()
		var first := ids.find("coin")
		var second := ids.find("coin", first + 1)
		if first >= 0 and second > first + 1:
			seed_value = candidate
			break
	check(seed_value > 0, "a seed with two Coins apart: %d" % seed_value)
	var left := ids.rfind("coin")
	var rect := view.card_rect(left)
	_click(view, rect.position + Vector2(6, rect.size.y * 0.5))
	var expected := ids.duplicate()
	expected.remove_at(left)
	check(_ids(hand.cards()) == expected, "the left Coin left the hand: %s, not the right one" % [_ids(hand.cards())])
	check(discard.size() == 1 and discard.top()[0].id == &"coin", "it is in the discard")
	scene.queue_free()
	await tree.process_frame


func test_drag_to_the_discard_and_back() -> void:
	# Headless, the window is 64 px: the example's own size, so its controls sit where they do on a screen.
	var window_size := tree.root.size
	tree.root.size = Vector2i(1152, 648)
	var scene := (load(SCENE) as PackedScene).instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	var hand := scene.get_node(^"%Hand") as CardPile
	var discard := scene.get_node(^"%Discard") as CardPile
	var hand_view := scene.get_node(^"%HandView") as HandView
	var discard_view := scene.get_node(^"%DiscardView") as HandView
	var log_label := scene.get_node(^"%Log") as Label
	var draw := scene.get_node(^"%Draw") as Button
	for i in 3:
		draw.pressed.emit()
	var dragged := hand.top()[0]
	var rect := hand_view.card_rect(0)
	var start := hand_view.global_position + rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.5)
	await _drag(start, discard_view, discard_view.size * 0.5)
	check(discard.top()[0] == dragged and hand.size() == 2, "dragged onto the discard: %d in the hand" % hand.size())
	check(log_label.text.begins_with("Discarded " + dragged.title), "the log says so: %s" % log_label.text)
	var back := discard_view.get_global_rect().get_center()
	await _drag(back, hand_view, Vector2(hand_view.size.x - 4, hand_view.size.y * 0.5))
	check(
		discard.is_empty() and hand.size() == 3 and hand.top()[0] == dragged,
		"dragged back to the hand, on the right: %s" % [_ids(hand.cards())]
	)
	check(log_label.text.begins_with("Took back " + dragged.title), "and the log: %s" % log_label.text)
	var right := hand_view.card_rect(0)
	var from := hand_view.global_position + right.position + Vector2(right.size.x * 0.5, right.size.y * 0.5)
	await _drag(from, hand_view, Vector2(2, hand_view.size.y * 0.5))
	check(hand.cards()[-1] == dragged, "dragged inside the hand: now the leftmost")
	scene.queue_free()
	await tree.process_frame
	tree.root.size = window_size


# A real drag through the viewport: a press, then motions past Godot's threshold, so `_get_drag_data` runs and the
# drag starts. Headless has no cursor, so Godot's own drop would land at (0, 0): the test makes the calls Godot makes
# on release (`_can_drop_data`, then `_drop_data`) on `target` at `local`, and ends the drag. True when one started.
func _drag(from: Vector2, target: HandView, local: Vector2) -> bool:
	tree.root.push_input(_motion(from, from, 0))
	tree.root.push_input(_button(from, true))
	await tree.process_frame
	var last := from
	for step in 4:
		var at := from + Vector2(0, 12 * (step + 1))
		tree.root.push_input(_motion(at, last, MOUSE_BUTTON_MASK_LEFT))
		last = at
		await tree.process_frame
	var started := tree.root.gui_is_dragging()
	var data: Variant = tree.root.gui_get_drag_data()
	tree.root.gui_cancel_drag()
	tree.root.push_input(_button(last, false))
	await tree.process_frame
	if started and target._can_drop_data(local, data):
		target._drop_data(local, data)
	return started


# The drag starts once the motions' `relative` add up past Godot's threshold, so each one carries it.
func _motion(at: Vector2, previous: Vector2, mask: int) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = at - previous
	event.button_mask = mask
	return event


func _button(at: Vector2, down: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = at
	event.global_position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	return event
