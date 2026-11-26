extends "res://addons/deck_kit/tests/deck_test.gd"

## HandView: where each card sits (bottom of the pile on the left), the spread that shrinks to fit, the fan, the hit
## test, hover and press signals with the index (copies too), card scenes, the slide, redrawing when cards or piles
## change, and its warnings.

const FixtureCard := preload("res://addons/deck_kit/tests/fixture_card.gd")
const FixtureNoCard := preload("res://addons/deck_kit/tests/fixture_no_card.gd")


func _card(id: StringName) -> CardData:
	var card := CardData.new()
	card.id = id
	card.title = String(id)
	card.text = "Some text on %s." % id
	card.tags = [&"tag"]
	return card


func _cards(count: int) -> Array[CardData]:
	var list: Array[CardData] = []
	for i in count:
		list.append(_card(StringName("c%d" % i)))
	return list


func _setup(cards: Array[CardData], width := 600.0) -> HandView:
	var pile := CardPile.new()
	pile.start_cards = cards
	tree.root.add_child(pile)
	var view := HandView.new()
	view.pile = pile
	tree.root.add_child(view)
	view.size = Vector2(width, 220)
	return view


func _done(view: HandView) -> void:
	view.pile.free()
	view.free()


func _left_strip(view: HandView, index: int) -> Vector2:
	var rect := view.card_rect(index)
	return rect.position + Vector2(4, rect.size.y * 0.5)


func _motion(at: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = at
	return event


func test_layout() -> void:
	var cards := _cards(3)
	var view := _setup(cards)
	check(view.card_rect(2).position.x < view.card_rect(0).position.x, "the bottom of the pile is on the left")
	check(is_equal_approx(view.card_rect(1).position.x - view.card_rect(2).position.x, 110.0), "spread between cards")
	var middle := view.card_rect(1).get_center()
	check(is_equal_approx(middle.x, 300.0), "the row is centered: %s" % middle)
	check(is_equal_approx(view.card_rect(0).end.y, 220.0), "bottom aligned")
	check(view.card_rect(3) == Rect2() and view.card_rect(-1) == Rect2(), "no card there: an empty rect")
	check(view.card_at(view.card_rect(0).get_center()) == cards[0], "card_at finds the top card")
	check(view.card_at(_left_strip(view, 2)) == cards[2], "and the bottom one")
	check(view.card_at(Vector2(2, 2)) == null, "nothing outside the cards")
	var minimum := view.get_combined_minimum_size()
	check(minimum == Vector2(100, 140 + 16), "minimum size: a card and the lift: %s" % minimum)
	_done(view)


func test_spread_shrinks_to_fit() -> void:
	var view := _setup(_cards(10), 400.0)
	check(view.card_rect(9).position.x >= -0.01 and view.card_rect(0).end.x <= 400.01, "ten cards fit in 400 px")
	for index in 10:
		check(view.card_at(_left_strip(view, index)) == view.pile.cards()[index], "card %d can be picked" % index)
	_done(view)


func test_fan() -> void:
	var cards := _cards(5)
	var view := _setup(cards)
	view.fan_degrees = 30.0
	var rect := view.card_rect(4)
	var pivot := Vector2(rect.get_center().x, rect.end.y)
	var turned := (Vector2(rect.position.x + 10, rect.position.y + 10) - pivot).rotated(deg_to_rad(-15.0)) + pivot
	check(view.card_at(turned) == cards[4], "the hit test follows the leftmost card's turn")
	check(view.card_rect(2).position.y < view.card_rect(0).position.y, "cards at the ends sit lower")
	check(view.get_combined_minimum_size().y > 156.0, "the fan needs more height")
	_done(view)


func test_hover_and_press() -> void:
	var cards := _cards(3)
	var view := _setup(cards)
	var hovered: Array[String] = []
	view.card_hovered.connect(
		func(card: CardData, index: int) -> void: hovered.append("%s@%d" % [card.id, index] if card != null else "none")
	)
	var pressed: Array[String] = []
	view.card_pressed.connect(func(card: CardData, index: int) -> void: pressed.append("%s@%d" % [card.id, index]))
	view._gui_input(_motion(_left_strip(view, 1)))
	view._gui_input(_motion(_left_strip(view, 1) + Vector2(1, 0)))
	view._gui_input(_motion(_left_strip(view, 0)))
	view._gui_input(_motion(Vector2(1, 1)))
	check(hovered == (["c1@1", "c0@0", "none"] as Array[String]), "card_hovered on each change: %s" % [hovered])
	view._gui_input(_motion(_left_strip(view, 2)))
	view.notification(Control.NOTIFICATION_MOUSE_EXIT)
	check(hovered[-1] == "none", "leaving the view: null")
	_press(view, _left_strip(view, 2))
	check(pressed.is_empty(), "nothing on the press alone: a click is press and release")
	_release(view, _left_strip(view, 2))
	_click(view, Vector2(1, 1))
	_press(view, _left_strip(view, 2))
	_release(view, _left_strip(view, 0))
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = _left_strip(view, 2)
	view._gui_input(right)
	check(
		pressed == (["c2@2"] as Array[String]),
		"card_pressed: left button pressed and released on the same card only: %s" % [pressed]
	)
	_done(view)


func test_hover_follows_the_pile() -> void:
	var cards := _cards(3)
	var view := _setup(cards)
	var hovered: Array[String] = []
	view.card_hovered.connect(
		func(card: CardData, _index: int) -> void: hovered.append(str(card.id) if card != null else "none")
	)
	view._gui_input(_motion(_left_strip(view, 0)))
	view.pile.take()
	check(hovered.size() == 2 and hovered[0] == "c0", "the hovered card left: another one is under the pointer")
	view.pile.clear()
	check(hovered[-1] == "none", "no cards: null")
	_done(view)


func test_watches_its_cards() -> void:
	var cards := _cards(3)
	var view := _setup(cards)
	var first := view.pile
	check(cards[0].changed.get_connections().size() == 1, "the view hears a shown card's changes")
	var other := CardPile.new()
	tree.root.add_child(other)
	view.pile.move(cards[0], other)
	check(cards[0].changed.get_connections().is_empty(), "a card that left is no longer heard")
	view.pile = other
	check(cards[1].changed.get_connections().is_empty() and cards[0].changed.get_connections().size() == 1, "new pile")
	check(view.pile.added.get_connections().size() == 1, "the view listens to its pile once")
	view.pile = null
	other.free()
	first.free()
	view.free()


func test_draws_faces_and_backs() -> void:
	var cards := _cards(4)
	var art := GradientTexture2D.new()
	cards[1].art = art
	cards[2].tags = []
	var view := _setup(cards)
	view.fan_degrees = 10.0
	view._gui_input(_motion(_left_strip(view, 1)))
	view.queue_redraw()
	await tree.process_frame
	view.pile.face_up = false
	await tree.process_frame
	view.back = art
	await tree.process_frame
	check(view.pile.size() == 4, "faces, art, a card without tags and backs draw without errors")
	_done(view)


func test_warning() -> void:
	var view := HandView.new()
	check(view._get_configuration_warnings().size() == 1, "no pile: a warning")
	view.pile = CardPile.new()
	check(view._get_configuration_warnings().is_empty(), "a pile: none")
	view.pile.free()
	view.free()


func test_copies_click_the_one_under_the_pointer() -> void:
	var a := _card(&"a")
	var b := _card(&"b")
	var view := _setup([a, b, a])
	var discard := CardPile.new()
	tree.root.add_child(discard)
	var hand := view.pile
	view.card_pressed.connect(func(_pressed: CardData, index: int) -> void: hand.move_at(index, discard))
	check(view.card_index_at(_left_strip(view, 2)) == 2, "card_index_at: the left copy is index 2")
	_click(view, _left_strip(view, 2))
	check(hand.top(2) == ([a, b] as Array[CardData]) and discard.top()[0] == a, "the left copy left, not the right")
	check(view.card_at(_left_strip(view, 0)) == a and view.card_index_at(Vector2(1, 1)) == -1, "the right one stayed")
	discard.free()
	_done(view)


func test_card_scene() -> void:
	var cards := _cards(3)
	var view := _setup(cards)
	view.settle_time = 0.0
	view.card_scene = _scene(FixtureCard.new())
	var nodes := _card_nodes(view)
	check(nodes.size() == 3, "one scene per card: %d" % nodes.size())
	var right := true
	for index in 3:
		var node := nodes[2 - index] as Control
		right = (
			right
			and (node as FixtureCard).card == cards[index]
			and node.position.is_equal_approx(view.card_rect(index).position)
		)
		right = right and node.size == view.card_size and node.mouse_filter == Control.MOUSE_FILTER_IGNORE
	check(right, "each scene got its card, its place and its size; the view keeps the mouse")
	var pressed: Array[int] = []
	view.card_pressed.connect(func(_pressed: CardData, index: int) -> void: pressed.append(index))
	_click(view, _left_strip(view, 1))
	check(pressed == ([1] as Array[int]), "clicks work over scenes")
	var middle := nodes[1] as FixtureCard
	var before := middle.times_set
	cards[1].title = "Edited"
	check(middle.times_set == before + 1, "a card's change reaches its scene")
	view.pile.take()
	nodes = _card_nodes(view)
	check(nodes.size() == 2 and (nodes[0] as FixtureCard).card == cards[2], "a card that left takes its scene")
	view.pile.face_up = false
	check(not (nodes[0] as Control).visible and not (nodes[1] as Control).visible, "face down: backs are drawn instead")
	view.pile.face_up = true
	view.card_scene = null
	check(_card_nodes(view).is_empty(), "no scene: drawn again")
	_done(view)


func test_card_scene_warnings() -> void:
	var view := _setup(_cards(2))
	view.card_scene = _scene(Node2D.new())
	check(view._get_configuration_warnings().size() == 2, "a root that is not a Control, without card")
	check(_card_nodes(view).is_empty(), "drawn instead, with an error")
	view.card_scene = _scene(FixtureNoCard.new())
	check(view._get_configuration_warnings().size() == 1, "a root without card")
	view.card_scene = _scene(FixtureCard.new())
	check(view._get_configuration_warnings().is_empty(), "a Control with card: no warning")
	_done(view)


func test_cards_slide() -> void:
	var cards := _cards(3)
	var view := _setup(cards)
	view.card_scene = _scene(FixtureCard.new())
	view.settle_time = 0.2
	var left := _card_nodes(view)[0] as Control
	check(left.position.is_equal_approx(view.card_rect(2).position), "they start in place")
	view.pile.take()
	var target := view.card_rect(1).position
	check(not left.position.is_equal_approx(target), "a card that must move does not jump")
	await tree.create_timer(0.4).timeout
	check(left.position.is_equal_approx(target), "it arrives after settle_time: %s %s" % [left.position, target])
	view._gui_input(_motion(_left_strip(view, 1)))
	await tree.create_timer(0.4).timeout
	check(is_equal_approx(left.position.y, target.y - view.hover_lift), "the hovered card rises")
	view.settle_time = 0.0
	view.pile.take()
	check(left.position.is_equal_approx(view.card_rect(0).position), "settle_time 0: it jumps")
	_done(view)


func test_style_boxes_are_kept() -> void:
	var view := _setup(_cards(1))
	var face := view._box(true)
	check(face == view._box(true) and view._box(false) == view._box(false), "made once, not per card and frame")
	view.card_color = Color.WHITE
	check(view._box(true) != face and view._box(true).bg_color == Color.WHITE, "made again when a color changes")
	_done(view)


func test_keyboard() -> void:
	var cards := _cards(3)
	var view := _setup(cards)
	view.settle_time = 0.0
	view.card_scene = _scene(FixtureCard.new())
	check(view.focus_mode == Control.FOCUS_ALL, "the view takes focus")
	var hovered: Array[String] = []
	view.card_hovered.connect(
		func(card: CardData, index: int) -> void: hovered.append("%s@%d" % [card.id, index] if card != null else "none")
	)
	var pressed: Array[int] = []
	view.card_pressed.connect(func(_pressed: CardData, index: int) -> void: pressed.append(index))
	_action(view, &"ui_right")
	_action(view, &"ui_right")
	_action(view, &"ui_left")
	_action(view, &"ui_left")
	check(hovered == (["c2@2", "c1@1", "c2@2"] as Array[String]), "the arrows walk the cards: %s" % [hovered])
	var key := InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.pressed = true
	view._gui_input(key)
	check(hovered[-1] == "c1@1", "a real arrow key too")
	var node := _card_nodes(view)[1] as Control
	check(is_equal_approx(node.position.y, view.card_rect(1).position.y - view.hover_lift), "the picked card lifts")
	_action(view, &"ui_accept")
	check(pressed == ([1] as Array[int]), "ui_accept presses it")
	view.notification(Control.NOTIFICATION_MOUSE_EXIT)
	check(hovered[-1] == "c1@1", "the mouse leaving keeps a card picked with the keys")
	view.notification(Control.NOTIFICATION_FOCUS_EXIT)
	check(hovered[-1] == "none", "losing focus lets it go")
	view.keyboard = false
	_action(view, &"ui_right")
	check(
		view.focus_mode == Control.FOCUS_NONE and hovered[-1] == "none", "keyboard off: no focus, the keys do nothing"
	)
	_done(view)


func test_drag_between_views() -> void:
	var hand := _setup(_cards(3))
	var table := _setup([])
	table.position = Vector2(0, 300)
	var dropped: Array[String] = []
	table.card_dropped.connect(
		func(card: CardData, from_index: int, from: HandView, to_index: int) -> void:
			dropped.append("%s %d %s %d" % [card.id, from_index, from == hand, to_index])
			from.pile.move_at(from_index, table.pile, to_index)
	)
	var pressed: Array[int] = []
	hand.card_pressed.connect(func(_pressed: CardData, index: int) -> void: pressed.append(index))
	var start := _left_strip(hand, 1)
	check(not await _drag(start, table, Vector2(300, 110)), "drag_cards off: no drag starts")
	check(dropped.is_empty() and hand.pile.size() == 3, "and nothing moves")
	check(pressed == ([1] as Array[int]), "pressed and released on the card, without a drag: a click")
	pressed.clear()
	hand.drag_cards = true
	check(await _drag(start, table, Vector2(300, 110)), "drag_cards on: the drag starts through the viewport")
	check(dropped.is_empty() and hand.pile.size() == 3, "the target refuses drops while its drag_cards is off")
	table.drag_cards = true
	await _drag(start, table, Vector2(300, 110))
	check(dropped == (["c1 1 true 0"] as Array[String]), "card_dropped on the target: %s" % [dropped])
	check(table.pile.top()[0].id == &"c1" and hand.pile.size() == 2, "the game moved it")
	check(pressed.is_empty(), "a drag is not a click: %s" % [pressed])
	_done(hand)
	_done(table)


func test_drop_index_and_reorder() -> void:
	var cards := _cards(3)
	var view := _setup(cards)
	view.drag_cards = true
	var far_right := Vector2(599, 150)
	var far_left := Vector2(1, 150)
	var between := (view.card_rect(2).get_center() + view.card_rect(1).get_center()) * 0.5
	check(view.drop_index(far_right) == 0 and view.drop_index(far_left) == 3, "the top on the right, the bottom left")
	check(view.drop_index(between) == 2, "between the two leftmost cards")
	var top := HandView.CardDrag.new(cards[0], 0, view)
	check(view.drop_index(between, top) == 1, "a card of this same pile counts as already gone")
	check(view._can_drop_data(between, top) and not view._can_drop_data(between, "text"), "only card drags")
	var dropped: Array[int] = []
	view.card_dropped.connect(
		func(_dropped_card: CardData, from_index: int, from: HandView, to_index: int) -> void:
			dropped.append(to_index)
			from.pile.move_at(from_index, view.pile, to_index)
	)
	view._drop_data(between, top)
	check(dropped == ([1] as Array[int]), "card_dropped with that index")
	check(view.pile.cards() == ([cards[1], cards[0], cards[2]] as Array[CardData]), "c0 now sits between c2 and c1")
	view.drag_cards = false
	view._drop_data(between, top)
	check(dropped.size() == 1 and not view._can_drop_data(between, top), "drag_cards off: drops refused")
	_done(view)


func test_drag_preview() -> void:
	var cards := _cards(2)
	var view := _setup(cards)
	var drawn := view.drag_preview(0)
	var face := drawn.get_child(0) as Control
	check(face.size == view.card_size and face.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the card as drawn")
	check(face.position == -view.card_size * 0.5, "centred on the pointer")
	tree.root.add_child(drawn)
	await tree.process_frame
	drawn.free()
	view.card_scene = _scene(FixtureCard.new())
	var scene := view.drag_preview(1)
	check((scene.get_child(0) as FixtureCard).card == cards[1], "or an instance of card_scene with its card")
	scene.free()
	view.pile.face_up = false
	var hidden := view.drag_preview(1)
	check(not hidden.get_child(0) is FixtureCard, "a face-down pile drags its back")
	hidden.free()
	_done(view)


# A real drag through the viewport: a press, then motions past Godot's threshold, so `_get_drag_data` runs and the
# drag starts. Headless has no cursor, so Godot's own drop would land at (0, 0): the test makes the calls Godot makes
# on release (`_can_drop_data`, then `_drop_data`) on `target` at `local`, and ends the drag. True when one started.
func _drag(from: Vector2, target: HandView, local: Vector2) -> bool:
	tree.root.push_input(_mouse_motion(from, from, 0))
	tree.root.push_input(_mouse_button(from, true))
	await tree.process_frame
	var last := from
	for step in 4:
		var at := from + Vector2(0, 12 * (step + 1))
		tree.root.push_input(_mouse_motion(at, last, MOUSE_BUTTON_MASK_LEFT))
		last = at
		await tree.process_frame
	var started := tree.root.gui_is_dragging()
	var data: Variant = tree.root.gui_get_drag_data()
	tree.root.gui_cancel_drag()
	tree.root.push_input(_mouse_button(last, false))
	await tree.process_frame
	if started and target._can_drop_data(local, data):
		target._drop_data(local, data)
	return started


# The drag starts once the motions' `relative` add up past Godot's threshold, so each one carries it.
func _mouse_motion(at: Vector2, previous: Vector2, mask: int) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = at - previous
	event.button_mask = mask
	return event


func _mouse_button(at: Vector2, down: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = at
	event.global_position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	return event


func _press(view: HandView, at: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	view._gui_input(down)


func _release(view: HandView, at: Vector2) -> void:
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = at
	view._gui_input(up)


func _click(view: HandView, at: Vector2) -> void:
	_press(view, at)
	_release(view, at)


func _action(view: HandView, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	view._gui_input(event)


func _scene(root: Node) -> PackedScene:
	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	return packed


# The card scenes the view made, left to right.
func _card_nodes(view: HandView) -> Array[Node]:
	if view.get_child_count(true) == 0:
		var none: Array[Node] = []
		return none
	return view.get_child(0, true).get_children()
