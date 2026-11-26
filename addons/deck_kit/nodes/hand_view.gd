@tool
@icon("res://addons/deck_kit/icons/hand_view.svg")
class_name HandView
extends Control

## Shows a `CardPile` as a row or a fan of cards, in the editor too. The bottom of the pile is on the left, so the
## newest card drawn to a hand is on the right. Without `card_scene` each card is drawn as a rounded panel with its
## title, its art (or its text when it has no art) and its tags; with one, each card is an instance of your scene.
## A face-down pile shows backs. Cards slide to their new place (`settle_time`) and the card under the pointer (or
## picked with the arrows) lifts. The view handles the mouse, the keyboard and the gamepad: `card_pressed` and
## `card_hovered` give the card and its index in the pile. With `drag_cards`, cards drag to another view (or to another
## place in this one) and the view they land on emits `card_dropped`: your game moves the card.

## The card at `index` of the pile (0: the top) was clicked (the left button pressed and released on it, like a
## Button) or accepted with `ui_accept`. With copies of one card, the index tells which one:
## `pile.move_at(index, other)`.
signal card_pressed(card: CardData, index: int)
## The pointer, or `ui_left` / `ui_right`, moved onto the card at `index` of the pile (null and -1: it left the cards).
signal card_hovered(card: CardData, index: int)
## A card dragged from `from` (the card at `from_index` of its pile) was dropped on this view, where it would go at
## `to_index` of this pile (counted as if it had already left, when both views show the same pile). Nothing moves by
## itself: `from.pile.move_at(from_index, pile, to_index)` moves it.
signal card_dropped(card: CardData, from_index: int, from: HandView, to_index: int)

# The fan bends along a circle this many card heights wide.
const _FAN_RADIUS := 2.5
const _CORNER := 8
const _MARGIN := 6.0

## The pile to show.
@export var pile: CardPile:
	set(value):
		_listen(value)
		pile = value
		_refresh()
		update_configuration_warnings()
## Optional: a scene for each card (a Control root). The view makes one per card, sets its `card` property (declare
## `var card: CardData` in its script, `@tool` to see it in the editor), sizes it to `card_size` and places it. Empty:
## the view draws the cards itself. The view keeps the mouse: the scene gets no clicks.
@export var card_scene: PackedScene:
	set(value):
		card_scene = value
		_drop_shown()
		_refresh()
		update_configuration_warnings()

@export_group("Layout")
## The size of one card.
@export var card_size := Vector2(100, 140):
	set(value):
		card_size = value
		_relayout()
## From one card's left edge to the next. It shrinks so the row fits the width of the view.
@export_range(0.0, 400.0, 1.0, "or_greater", "suffix:px") var spread := 110.0:
	set(value):
		spread = value
		_relayout()
## The turn from the first card to the last (0: a straight row).
@export_range(0.0, 90.0, 0.5, "suffix:°") var fan_degrees := 0.0:
	set(value):
		fan_degrees = value
		_relayout()
## How far the card under the pointer rises.
@export_range(0.0, 100.0, 1.0, "suffix:px") var hover_lift := 16.0:
	set(value):
		hover_lift = value
		_relayout()
## How long a card takes to slide to its new place when cards come, go or the pointer lifts one. 0: they jump.
@export_range(0.0, 2.0, 0.01, "suffix:s") var settle_time := 0.15

@export_group("Input")
## The view takes focus (`focus_mode` All), `ui_left` / `ui_right` move along the cards and `ui_accept` presses the
## one picked. Off: `focus_mode` None, and the view leaves those keys alone.
@export var keyboard := true:
	set(value):
		keyboard = value
		focus_mode = FOCUS_ALL if value else FOCUS_NONE
## Cards can be dragged out of this view and dropped on it (from another view with `drag_cards`, or from this one to
## reorder). Off: no drag starts here and drops are refused.
@export var drag_cards := false

@export_group("Look")
## The picture on the back of a face-down card. Empty: a plain back in `back_color`.
@export var back: Texture2D:
	set(value):
		back = value
		queue_redraw()
## In the editor, show the faces of a face-down pile too, so you can check its cards.
@export var faces_in_editor := true:
	set(value):
		faces_in_editor = value
		_refresh()
## The face of a drawn card.
@export var card_color := Color(0.96, 0.93, 0.86):
	set(value):
		card_color = value
		_face_box = null
		queue_redraw()
## The back of a card when there is no `back` picture.
@export var back_color := Color(0.55, 0.12, 0.24):
	set(value):
		back_color = value
		_back_box = null
		queue_redraw()
## The edge of every drawn card and back.
@export var border_color := Color(0.18, 0.1, 0.12):
	set(value):
		border_color = value
		_face_box = null
		_back_box = null
		queue_redraw()
## The title, the text and the tags of a drawn card.
@export var text_color := Color(0.15, 0.1, 0.1):
	set(value):
		text_color = value
		queue_redraw()
## The size of a drawn card's title; the text and the tags are a bit smaller.
@export_range(6, 48, 1, "suffix:px") var font_size := 14:
	set(value):
		font_size = value
		queue_redraw()

# One card on screen, in pile order (index 0: the top). It keeps its place while it slides to a new one.
var _shown: Array[_Shown] = []
var _holder: Control
var _hover := -1
var _hover_card: CardData
# The hovered card was picked with the keys, not the pointer: leaving with the mouse does not drop it.
var _from_keys := false
var _press_index := -1
var _mouse_inside := false
var _mouse := Vector2.ZERO
var _watched: Array[CardData] = []
var _face_box: StyleBoxFlat
var _back_box: StyleBoxFlat


func _ready() -> void:
	if keyboard and focus_mode == FOCUS_NONE:
		focus_mode = FOCUS_ALL
	_refresh()


## The card under `point` (in this view's coordinates), the one on top when cards overlap; null when none.
func card_at(point: Vector2) -> CardData:
	var index := card_index_at(point)
	return _cards()[index] if index >= 0 else null


## The index in the pile (0: the top) of the card under `point`, the one on top when cards overlap; -1 when none. The
## hover lift and the slide do not count: it reads where each card belongs.
func card_index_at(point: Vector2) -> int:
	var count := _cards().size()
	for slot in range(count - 1, -1, -1):
		var rect := _slot_rect(slot, count)
		var pivot := Vector2(rect.get_center().x, rect.end.y)
		var local := (point - pivot).rotated(-_slot_angle(slot, count)) + pivot
		if rect.has_point(local):
			return count - 1 - slot
	return -1


## Where a card dropped at `point` would go in this pile (0: the top). For a card of this same pile (`drag`, from
## `_get_drag_data`), counted as if it had already left, so `move_at(drag.index, pile, drop_index(...))` puts it there.
func drop_index(point: Vector2, drag: CardDrag = null) -> int:
	var count := _cards().size()
	var left := 0
	for slot in count:
		var rect := _slot_rect(slot, count)
		if rect.get_center().x < point.x:
			left += 1
	var to_index := count - left
	if drag != null and drag.from != null and drag.from.pile == pile and drag.index < to_index:
		to_index -= 1
	return to_index


## The picture that follows the pointer while the card at `index` is dragged: an instance of `card_scene`, or the card
## as the view draws it (its back when the pile is face down). Not in the tree yet; `_get_drag_data` hands it to Godot.
func drag_preview(index: int) -> Control:
	var card: CardData = _cards()[index]
	var holder := Control.new()
	holder.mouse_filter = MOUSE_FILTER_IGNORE
	var face: Control = _make_scene(card) if card_scene != null and _shows_faces() else null
	if face == null:
		face = Control.new()
		face.draw.connect(_paint_preview.bind(face, card, _shows_faces()))
	_ignore_mouse(face)
	face.size = card_size
	face.position = -card_size * 0.5
	holder.add_child(face)
	return holder


## Where the card at `index` of the pile (0: the top, on the right) belongs, before the fan's turn and the hover lift.
## An empty Rect2 when there is no card there.
func card_rect(index: int) -> Rect2:
	var count := _cards().size()
	if index < 0 or index >= count:
		return Rect2()
	return _slot_rect(count - 1 - index, count)


func _get_minimum_size() -> Vector2:
	return Vector2(card_size.x, card_size.y + hover_lift + _max_drop())


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			_aim_all(true)
		NOTIFICATION_MOUSE_EXIT:
			_mouse_inside = false
			if not _from_keys:
				_set_hover(-1)
		NOTIFICATION_FOCUS_EXIT:
			if _from_keys:
				_from_keys = false
				_set_hover(-1)
		NOTIFICATION_DRAG_BEGIN:
			_press_index = -1


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_mouse_inside = true
		_mouse = motion.position
		_from_keys = false
		_set_hover(card_index_at(_mouse))
		return
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		var index := card_index_at(button.position)
		if button.pressed:
			_press_index = index
		elif index >= 0 and index == _press_index:
			accept_event()
			card_pressed.emit(_cards()[index], index)
		if not button.pressed:
			_press_index = -1
		return
	if keyboard:
		_key_input(event)


func _get_drag_data(at_position: Vector2) -> Variant:
	var index := card_index_at(at_position)
	if not drag_cards or index < 0:
		return null
	_press_index = -1
	set_drag_preview(drag_preview(index))
	return CardDrag.new(_cards()[index], index, self)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return drag_cards and data is CardDrag


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not drag_cards or not data is CardDrag:
		return
	var drag: CardDrag = data
	card_dropped.emit(drag.card, drag.index, drag.from, drop_index(at_position, drag))


func _process(delta: float) -> void:
	var step := delta / settle_time if settle_time > 0.0 else 1.0
	var moving := false
	for shown in _shown:
		if shown.progress < 1.0:
			moving = shown.advance(step) or moving
			_place(shown)
	queue_redraw()
	set_process(moving)


func _draw() -> void:
	var faces := _shows_faces()
	var font := get_theme_default_font()
	for index in range(_shown.size() - 1, -1, -1):
		var shown := _shown[index]
		if faces and shown.node != null:
			continue
		var pivot := shown.at + Vector2(card_size.x * 0.5, card_size.y)
		draw_set_transform(pivot, shown.angle)
		var local := Rect2(Vector2(-card_size.x * 0.5, -card_size.y), card_size)
		if faces:
			_draw_face(self, shown.card, local, font)
		else:
			_draw_back(self, local)
	draw_set_transform(Vector2.ZERO)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if pile == null:
		warnings.append("Assign pile: the CardPile (or Deck) to show.")
	warnings.append_array(_scene_problems())
	return warnings


# Draws `card` on `target` (this view, or a drag preview) inside `rect`.
func _draw_face(target: CanvasItem, card: CardData, rect: Rect2, font: Font) -> void:
	target.draw_style_box(_box(true), rect)
	var inner := rect.grow(-_MARGIN)
	var small := maxi(font_size - 3, 6)
	var title := card.title if card.title != "" else String(card.id)
	var title_size := _fit(font, title, inner.size.x, font_size)
	target.draw_string(
		font,
		Vector2(inner.position.x, inner.position.y + font.get_ascent(title_size)),
		title,
		HORIZONTAL_ALIGNMENT_CENTER,
		inner.size.x,
		title_size,
		text_color
	)
	var tags_line := " · ".join(PackedStringArray(card.tags))
	var tags_height := small + 4.0 if tags_line != "" else 0.0
	var body := Rect2(
		inner.position + Vector2(0, title_size + 4.0),
		Vector2(inner.size.x, inner.size.y - title_size - 4.0 - tags_height)
	)
	if card.art != null:
		target.draw_texture_rect(card.art, _fit_rect(card.art.get_size(), body), false)
	elif card.text != "" and body.size.y > small:
		target.draw_multiline_string(
			font,
			body.position + Vector2(0, small),
			card.text,
			HORIZONTAL_ALIGNMENT_CENTER,
			body.size.x,
			small,
			maxi(int(body.size.y / (small + 2.0)), 1),
			text_color
		)
	if tags_line != "":
		var tag_color := Color(text_color, text_color.a * 0.7)
		var at := Vector2(inner.position.x, inner.end.y - 2.0)
		var tag_size := _fit(font, tags_line, inner.size.x, small)
		target.draw_string(font, at, tags_line, HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, tag_size, tag_color)


func _draw_back(target: CanvasItem, rect: Rect2) -> void:
	if back != null:
		target.draw_texture_rect(back, rect, false)
		return
	target.draw_style_box(_box(false), rect)
	target.draw_rect(rect.grow(-_MARGIN), Color(border_color, 0.6), false, 2.0)


func _paint_preview(face: Control, card: CardData, faces: bool) -> void:
	var rect := Rect2(Vector2.ZERO, card_size)
	if faces:
		_draw_face(face, card, rect, get_theme_default_font())
	else:
		_draw_back(face, rect)


# The rounded panel of a face or a back, made once and again only when its colors change.
func _box(face: bool) -> StyleBoxFlat:
	if face and _face_box != null:
		return _face_box
	if not face and _back_box != null:
		return _back_box
	var box := StyleBoxFlat.new()
	box.bg_color = card_color if face else back_color
	box.border_color = border_color
	box.set_border_width_all(2)
	box.set_corner_radius_all(_CORNER)
	if face:
		_face_box = box
	else:
		_back_box = box
	return box


# The biggest font size up to `wanted` at which `line` fits in `width`.
func _fit(font: Font, line: String, width: float, wanted: int) -> int:
	var fitted := wanted
	while fitted > 6 and font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > width:
		fitted -= 1
	return fitted


# `picture` scaled to fit inside `box`, centered, keeping its shape.
func _fit_rect(picture: Vector2, box: Rect2) -> Rect2:
	if picture.x <= 0.0 or picture.y <= 0.0 or box.size.x <= 0.0 or box.size.y <= 0.0:
		return Rect2(box.position, Vector2.ZERO)
	var scale_by := minf(box.size.x / picture.x, box.size.y / picture.y)
	var fitted := picture * scale_by
	return Rect2(box.position + (box.size - fitted) * 0.5, fitted)


# The rect of the card in `slot` (0: the leftmost, the bottom of the pile) out of `count`, before its turn.
func _slot_rect(slot: int, count: int) -> Rect2:
	var step := spread
	if count > 1 and card_size.x + spread * (count - 1) > size.x:
		step = maxf((size.x - card_size.x) / (count - 1), 0.0)
	var width := card_size.x + step * maxi(count - 1, 0)
	var left := (size.x - width) * 0.5 + step * slot
	var angle := _slot_angle(slot, count)
	var drop := card_size.y * _FAN_RADIUS * (1.0 - cos(angle))
	var top := size.y - card_size.y - _max_drop() + drop
	return Rect2(Vector2(left, top), card_size)


func _slot_angle(slot: int, count: int) -> float:
	if count < 2:
		return 0.0
	return deg_to_rad(fan_degrees) * (float(slot) / (count - 1) - 0.5)


func _max_drop() -> float:
	return card_size.y * _FAN_RADIUS * (1.0 - cos(deg_to_rad(fan_degrees) * 0.5))


func _cards() -> Array[CardData]:
	if pile == null or not is_instance_valid(pile):
		var none: Array[CardData] = []
		return none
	return pile.cards()


func _shows_faces() -> bool:
	if pile == null or not is_instance_valid(pile):
		return true
	return pile.face_up or (faces_in_editor and Engine.is_editor_hint())


# After the cards or the layout changed: the pointer's card again, or the same place for a card picked with the keys.
func _update_hover() -> void:
	if _from_keys:
		_set_hover(mini(_hover, _cards().size() - 1))
	else:
		_set_hover(card_index_at(_mouse) if _mouse_inside else -1)


# Lifts the card at `index` (-1: none) and emits card_hovered when the card or its index changed.
func _set_hover(index: int) -> void:
	var list := _cards()
	var card: CardData = list[index] if index >= 0 and index < list.size() else null
	if card == null:
		index = -1
	if index == _hover and card == _hover_card:
		return
	_hover = index
	_hover_card = card
	_aim_all(false)
	card_hovered.emit(card, index)


# `ui_left` / `ui_right` walk the cards from where the pick is (from an end when nothing is picked) and `ui_accept`
# presses the picked card. At an end the key is left alone, so focus can move on to the next control.
func _key_input(event: InputEvent) -> void:
	var count := _cards().size()
	var step := 0
	if event.is_action_pressed(&"ui_left", true):
		step = 1
	elif event.is_action_pressed(&"ui_right", true):
		step = -1
	elif event.is_action_pressed(&"ui_accept") and _hover >= 0:
		accept_event()
		card_pressed.emit(_cards()[_hover], _hover)
		return
	if step == 0 or count == 0:
		return
	var next := (0 if step > 0 else count - 1) if _hover < 0 else _hover + step
	if next < 0 or next >= count:
		return
	accept_event()
	_from_keys = true
	_set_hover(next)


func _relayout() -> void:
	update_minimum_size()
	_aim_all(true)
	_update_hover()


# The pile changed: match the cards on screen to the new order, then let each slide to its place.
func _refresh() -> void:
	var list := _cards()
	var count := list.size()
	_watch(list)
	var old: Array[_Shown] = _shown.duplicate()
	var next: Array[_Shown] = []
	for index in count:
		var slot := count - 1 - index
		var target := _slot_rect(slot, count).position
		var shown := _take_nearest(old, list[index], target)
		if shown == null:
			shown = _Shown.new(list[index])
			shown.node = _make_node(list[index])
			shown.aim(target, _slot_angle(slot, count), true)
		next.append(shown)
	for leftover in old:
		_free_node(leftover)
	_shown = next
	_aim_all(false)
	_update_hover()


# The card on screen showing `card` that is nearest to `target`, taken out of `old`; null when none shows it. With
# copies, the nearest one is the one that stayed.
func _take_nearest(old: Array[_Shown], card: CardData, target: Vector2) -> _Shown:
	var best := -1
	for i in old.size():
		if old[i].card == card and (best < 0 or old[i].at.distance_to(target) < old[best].at.distance_to(target)):
			best = i
	if best < 0:
		return null
	var found := old[best]
	old.remove_at(best)
	return found


# Every card heads to where it belongs (lifted when hovered); `jump` puts it there at once.
func _aim_all(jump: bool) -> void:
	var count := _shown.size()
	var faces := _shows_faces()
	for index in count:
		var shown := _shown[index]
		var slot := count - 1 - index
		var target := _slot_rect(slot, count).position
		if index == _hover:
			target.y -= hover_lift
		shown.aim(target, _slot_angle(slot, count), jump or settle_time <= 0.0)
		if shown.node != null:
			shown.node.visible = faces
			_holder_node().move_child(shown.node, slot)
			_place(shown)
	set_process(_shown.any(func(shown: _Shown) -> bool: return shown.progress < 1.0))
	queue_redraw()


func _place(shown: _Shown) -> void:
	if shown.node == null:
		return
	shown.node.size = card_size
	shown.node.pivot_offset = Vector2(card_size.x * 0.5, card_size.y)
	shown.node.position = shown.at
	shown.node.rotation = shown.angle


# An instance of `card_scene` for `card` under the holder, or null when there is no scene (or its root is not a
# Control).
func _make_node(card: CardData) -> Control:
	var node := _make_scene(card)
	if node != null:
		_holder_node().add_child(node)
	return node


# An instance of `card_scene` with its `card` set and the mouse off, out of the tree; null when there is none.
func _make_scene(card: CardData) -> Control:
	if card_scene == null:
		return null
	var made := card_scene.instantiate()
	var node := made as Control
	if node == null:
		push_error("HandView: card_scene must have a Control root; the cards are drawn instead")
		made.free()
		return null
	if &"card" in node:
		node.set(&"card", card)
	else:
		push_error("HandView: card_scene's root script needs a property card (var card: CardData)")
	_ignore_mouse(node)
	return node


func _ignore_mouse(node: Node) -> void:
	var control := node as Control
	if control != null:
		control.mouse_filter = MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


# The parent of the card scenes: an internal child, so it is never saved with the scene and stays under the view.
func _holder_node() -> Control:
	if _holder == null:
		_holder = Control.new()
		_holder.name = "Cards"
		_holder.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(_holder, false, INTERNAL_MODE_FRONT)
	return _holder


func _drop_shown() -> void:
	for shown in _shown:
		_free_node(shown)
	_shown.clear()


# Out of the holder now (so the order of the others is right this frame), freed at the end of the frame.
func _free_node(shown: _Shown) -> void:
	if shown.node == null:
		return
	_holder_node().remove_child(shown.node)
	shown.node.queue_free()
	shown.node = null


# What is wrong with `card_scene` for the editor: its root must be a Control whose script declares `card`.
func _scene_problems() -> PackedStringArray:
	var problems := PackedStringArray()
	if card_scene == null or card_scene.get_state().get_node_count() == 0:
		return problems
	var state := card_scene.get_state()
	var type := state.get_node_type(0)
	if type == &"":
		return problems
	if not ClassDB.is_parent_class(type, &"Control"):
		problems.append("card_scene: its root is a %s. Make it a Control (a PanelContainer, for example)." % type)
	var script: Script = null
	for i in state.get_node_property_count(0):
		if state.get_node_property_name(0, i) == &"script":
			script = state.get_node_property_value(0, i)
	var declares := false
	if script != null:
		for property in script.get_script_property_list():
			declares = declares or property["name"] == "card"
	if not declares:
		problems.append("card_scene: its root script needs a property card (var card: CardData); the view sets it.")
	return problems


func _listen(next: CardPile) -> void:
	if pile != null and is_instance_valid(pile) and pile.rebuilt.is_connected(_refresh):
		pile.added.disconnect(_on_cards_moved)
		pile.removed.disconnect(_on_cards_moved)
		pile.shuffled.disconnect(_refresh)
		pile.rebuilt.disconnect(_refresh)
		pile.flipped.disconnect(_on_flipped)
	if next != null:
		next.added.connect(_on_cards_moved)
		next.removed.connect(_on_cards_moved)
		next.shuffled.connect(_refresh)
		next.rebuilt.connect(_refresh)
		next.flipped.connect(_on_flipped)


func _on_cards_moved(_cards_moved: Array[CardData], _other: CardPile) -> void:
	_refresh()


func _on_flipped(_face_up: bool) -> void:
	_refresh()


# Listens to `changed` of every card shown (a title edited in the inspector shows at once), and only to those.
func _watch(list: Array[CardData]) -> void:
	for card in _watched:
		if card.changed.is_connected(_on_card_changed):
			card.changed.disconnect(_on_card_changed)
	_watched.clear()
	for card in list:
		if not _watched.has(card):
			card.changed.connect(_on_card_changed)
			_watched.append(card)


# A card's data changed: scenes get their card again, so they show it.
func _on_card_changed() -> void:
	for shown in _shown:
		if shown.node != null and &"card" in shown.node:
			shown.node.set(&"card", shown.card)
	queue_redraw()


## What a card dragged out of a HandView carries: the card, its index in the pile it left and the view it left. A
## drop target of your own reads it: `func _can_drop_data(_at, data): return data is HandView.CardDrag`.
class CardDrag:
	## The card dragged.
	var card: CardData
	## Its index in the pile it is dragged from (0: the top).
	var index := -1
	## The view it is dragged from; `from.pile` is the pile.
	var from: HandView

	func _init(card_in: CardData, index_in: int, from_in: HandView) -> void:
		card = card_in
		index = index_in
		from = from_in


# One card on screen: the card, its scene (null when drawn), where it is and where it is heading.
class _Shown:
	var card: CardData
	var node: Control
	var at := Vector2.ZERO
	var angle := 0.0
	var progress := 1.0
	var _from_at := Vector2.ZERO
	var _from_angle := 0.0
	var _to_at := Vector2.ZERO
	var _to_angle := 0.0

	func _init(card_in: CardData) -> void:
		card = card_in

	# Heads to `target` and `turn`; `jump` puts it there at once.
	func aim(target: Vector2, turn: float, jump: bool) -> void:
		if jump:
			at = target
			angle = turn
			_to_at = target
			_to_angle = turn
			progress = 1.0
		elif not target.is_equal_approx(_to_at) or not is_equal_approx(turn, _to_angle):
			_from_at = at
			_from_angle = angle
			_to_at = target
			_to_angle = turn
			progress = 0.0

	# Moves `step` (a share of the whole slide) further. True while it has not arrived.
	func advance(step: float) -> bool:
		progress = minf(progress + step, 1.0)
		var eased := smoothstep(0.0, 1.0, progress)
		at = _from_at.lerp(_to_at, eased)
		angle = lerpf(_from_angle, _to_angle, eased)
		return progress < 1.0
