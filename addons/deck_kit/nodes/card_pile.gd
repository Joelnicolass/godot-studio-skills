# gdlint: disable=max-public-methods
@tool
@icon("res://addons/deck_kit/icons/card_pile.svg")
class_name CardPile
extends Node

## Cards in the scene tree: a hand, a discard, the table. It owns a `CardStack` built from its inspector values
## (`start_cards`, `max_size`), or shows one your game's rules already keep (`use_stack`). Every call goes to the
## stack, and its signals come out here with the other side named as the `CardPile` that shows it (`showing`).

## `cards` came in, in the order they moved. `from` is the pile they left (null: they came from nowhere, or from a
## stack no pile shows).
signal added(cards: Array[CardData], from: CardPile)
## `cards` left, in the order they moved. `to` is the pile they went to (null: they were taken out, or went to a stack
## no pile shows).
signal removed(cards: Array[CardData], to: CardPile)
## The order of the cards changed with `shuffle`.
signal shuffled
## The pile shows another stack now (`use_stack`, `use_own_stack`, or new `start_cards`): read every card again.
signal rebuilt
## The pile turned face up or face down: views draw it again.
signal flipped(face_up: bool)

# The pile that shows each stack, by the stack's instance id, as a WeakRef: nothing here keeps a pile alive, and a
# pile takes itself out when it stops showing a stack or is freed.
static var _shown_by: Dictionary[int, WeakRef] = {}

## What the stack holds when it is built, top first. Changing it builds the stack again with these cards.
@export var start_cards: Array[CardData] = []:
	set(value):
		start_cards = value
		_rebuild_own()
## The most cards the pile holds (-1: no limit). Moves into a full pile move only what fits. In the editor it builds
## the stack again with the start cards that fit; in the game it never takes cards out.
@export_range(-1, 999, 1, "or_greater") var max_size := -1:
	set(value):
		max_size = value
		# While the scene loads (start_cards may come first) and in the editor, start again under the new limit.
		if not is_node_ready() or Engine.is_editor_hint():
			_rebuild_own()
		elif _own and _stack != null:
			_stack.max_size = value
		update_configuration_warnings()
## Whether views draw the cards' faces (true) or their backs (false). A deck is usually face down.
@export var face_up := true:
	set(value):
		if face_up == value:
			return
		face_up = value
		flipped.emit(value)

## The stack this pile shows.
var stack: CardStack:
	get:
		if _stack == null:
			_rebuild_own()
		return _stack

var _stack: CardStack
var _own := true


## The pile that shows `other` (the last one that started showing it), or null when none does. The signals of every
## pile name the other side with it.
static func showing(other: CardStack) -> CardPile:
	if other == null or not _shown_by.has(other.get_instance_id()):
		return null
	var pile: CardPile = _shown_by[other.get_instance_id()].get_ref()
	return pile


## Shows `other` instead of the pile's own stack (your game's rules keep it). The inspector values no longer apply
## until `use_own_stack()`. Emits `rebuilt`.
func use_stack(other: CardStack) -> void:
	if other == null:
		push_error("CardPile.use_stack: the stack is null")
		return
	_own = false
	_set_stack(other)


## Goes back to a stack built from the inspector values, with the start cards. Emits `rebuilt`.
func use_own_stack() -> void:
	_own = true
	_rebuild_own()


## A copy of the cards, top first.
func cards() -> Array[CardData]:
	return stack.cards()


## How many cards there are.
func size() -> int:
	return stack.size()


## True when there are no cards.
func is_empty() -> bool:
	return stack.is_empty()


## The top `n` cards, top first, without taking them.
func top(n := 1) -> Array[CardData]:
	return stack.top(n)


## True when `card` is in the pile.
func has(card: CardData) -> bool:
	return stack.has(card)


## The card with `id` nearest the top, or null.
func find_id(id: StringName) -> CardData:
	return stack.find_id(id)


## How many cards have `tag`.
func count_tag(tag: StringName) -> int:
	return stack.count_tag(tag)


## Draws up to `n` cards from the top onto `pile` and returns them in the order drawn.
func draw_to(pile: CardPile, n := 1) -> Array[CardData]:
	if pile == null:
		push_error("%s.draw_to: there is no pile to draw to" % name)
		var none: Array[CardData] = []
		return none
	return stack.draw_to(pile.stack, n)


## Moves the first copy of `card` from the top to `to` at `index` (0: the top; -1: the bottom). False when it is not
## here or `to` is full. With copies of one card, use `move_at`.
func move(card: CardData, to: CardPile, index := 0) -> bool:
	if to == null:
		push_error("%s.move: there is no pile to move to" % name)
		return false
	return stack.move(card, to.stack, index)


## Moves the card at `index` (0: the top) to `to` at `to_index` (0: the top; -1: the bottom). False when `to` is full.
## `HandView.card_pressed` gives the index of the card that was clicked.
func move_at(index: int, to: CardPile, to_index := 0) -> bool:
	if to == null:
		push_error("%s.move_at: there is no pile to move to" % name)
		return false
	return stack.move_at(index, to.stack, to_index)


## Puts `card` at `index` (0: the top; -1: the bottom). False when the pile is full.
func add(card: CardData, index := 0) -> bool:
	return stack.add(card, index)


## Takes the first copy of `card` from the top out, to nowhere. False when it is not here.
func remove(card: CardData) -> bool:
	return stack.remove(card)


## Takes the card at `index` (0: the top) out, to nowhere, and returns it.
func remove_at(index: int) -> CardData:
	return stack.remove_at(index)


## Takes up to `n` cards off the top, to nowhere, and returns them.
func take(n := 1) -> Array[CardData]:
	return stack.take(n)


## Takes every card out, to nowhere.
func clear() -> void:
	stack.clear()


## Shuffles the pile with `rng`. A `Deck` uses its own `rng` when none is passed.
func shuffle(rng: RandomNumberGenerator = null) -> void:
	stack.shuffle(_rng_or_own(rng))


## Moves every card of `other` under this pile and, with an `rng`, shuffles it. A `Deck` uses its own `rng` when none
## is passed.
func refill_from(other: CardPile, rng: RandomNumberGenerator = null) -> Array[CardData]:
	if other == null:
		push_error("%s.refill_from: there is no pile to refill from" % name)
		var none: Array[CardData] = []
		return none
	return stack.refill_from(other.stack, _rng_or_own(rng))


## Plain data for a save: the stack's `to_dict()`. Load it with `use_stack(CardStack.from_dict(data, catalog))`.
func to_dict() -> Dictionary:
	return stack.to_dict()


# The rng a call uses when it is passed none: none here; a Deck gives its own.
func _rng_or_own(rng: RandomNumberGenerator) -> RandomNumberGenerator:
	return rng


func _rebuild_own() -> void:
	if not _own:
		return
	_set_stack(CardStack.new(_start_list(), max_size))
	update_configuration_warnings()


# The start cards without the empty slots (the editor warns about them) and only what fits.
func _start_list() -> Array[CardData]:
	var list: Array[CardData] = []
	for card in start_cards:
		if card != null and (max_size < 0 or list.size() < max_size):
			list.append(card)
	return list


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _stack != null:
		_forget(_stack)


func _set_stack(next: CardStack) -> void:
	if _stack != null:
		_stack.added.disconnect(_on_added)
		_stack.removed.disconnect(_on_removed)
		_stack.shuffled.disconnect(_on_shuffled)
		_forget(_stack)
	_stack = next
	_shown_by[next.get_instance_id()] = weakref(self)
	_stack.added.connect(_on_added)
	_stack.removed.connect(_on_removed)
	_stack.shuffled.connect(_on_shuffled)
	rebuilt.emit()


# Takes this pile out of the registry for `old`, unless another pile started showing it since.
func _forget(old: CardStack) -> void:
	if showing(old) == self:
		_shown_by.erase(old.get_instance_id())


func _on_added(cards_in: Array[CardData], from: CardStack) -> void:
	added.emit(cards_in, showing(from))


func _on_removed(cards_out: Array[CardData], to: CardStack) -> void:
	removed.emit(cards_out, showing(to))


func _on_shuffled() -> void:
	shuffled.emit()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var by_id: Dictionary[StringName, CardData] = {}
	for index in start_cards.size():
		var card := start_cards[index]
		if card == null:
			warnings.append("start_cards: slot %d is empty. Drag a CardData there or remove the slot." % index)
		elif card.id == &"":
			warnings.append("start_cards: the card in slot %d has no id, so to_dict cannot save it." % index)
		elif by_id.has(card.id) and by_id[card.id] != card:
			warnings.append(
				"start_cards: slot %d is another card with the id %s. Give each card its own id." % [index, card.id]
			)
		else:
			by_id[card.id] = card
	if max_size >= 0 and start_cards.size() > max_size:
		warnings.append(
			"start_cards: %d cards, but max_size is %d. The last ones are left out." % [start_cards.size(), max_size]
		)
	return warnings
