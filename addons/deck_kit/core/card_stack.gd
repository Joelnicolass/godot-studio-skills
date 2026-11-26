class_name CardStack
extends RefCounted

## Cards in order, as plain data: no nodes, no scene. Index 0 is the top. The same `CardData` may be in a stack
## several times (copies): `move_at` and `remove_at` tell them apart by index. Cards move between stacks with
## `draw_to`, `move_at` and `refill_from`; shuffling takes your `RandomNumberGenerator`, so the same seed gives the same
## order. A game keeps one per pile in its rules (the deck, each hand, the discard); `CardPile` wraps one for the
## editor.

## `cards` came in, in the order they moved. `from` is the stack they left (null: they came from nowhere, with `add`).
signal added(cards: Array[CardData], from: CardStack)
## `cards` left, in the order they moved. `to` is the stack they went to (null: they were taken out, with `remove`,
## `take` or `clear`). A move emits `removed` here first and then `added` on the other stack.
signal removed(cards: Array[CardData], to: CardStack)
## The order of the cards changed with `shuffle`.
signal shuffled

## The most cards the stack holds (-1: no limit). Moves into a full stack move only what fits. Lowering it never takes
## cards out: it only stops more coming in.
var max_size := -1

var _cards: Array[CardData] = []


## A stack with `start` cards (top first) and a `max_size` (-1: no limit). A null card, or a card past `max_size`, is
## an error and is left out.
func _init(start: Array[CardData] = [], max_size_in := -1) -> void:
	max_size = max_size_in
	var dropped := 0
	for card in start:
		if card == null:
			push_error("CardStack: a start card is null; it is left out")
		elif _room(1) == 0:
			dropped += 1
		else:
			_cards.append(card)
	if dropped > 0:
		push_error("CardStack: %d start cards do not fit under max_size %d; they are left out" % [dropped, max_size])


## A copy of the cards, top first.
func cards() -> Array[CardData]:
	return _cards.duplicate()


## How many cards there are.
func size() -> int:
	return _cards.size()


## True when there are no cards.
func is_empty() -> bool:
	return _cards.is_empty()


## True when `card` is in the stack (any copy).
func has(card: CardData) -> bool:
	return _cards.has(card)


## The top `n` cards, top first, without taking them (fewer when there are fewer).
func top(n := 1) -> Array[CardData]:
	return _cards.slice(0, maxi(n, 0))


## The card with `id` nearest the top, or null when there is none.
func find_id(id: StringName) -> CardData:
	for card in _cards:
		if card.id == id:
			return card
	return null


## How many cards have `tag`.
func count_tag(tag: StringName) -> int:
	var count := 0
	for card in _cards:
		if card.has_tag(tag):
			count += 1
	return count


## Puts `card` at `index` (0: the top; -1 or past the end: the bottom). False when the stack is full. A null card is an
## error. Emits `added` with no `from`.
func add(card: CardData, index := 0) -> bool:
	if card == null:
		push_error("CardStack.add: the card is null")
		return false
	if _room(1) == 0:
		return false
	_insert(card, index)
	added.emit(_one(card), null)
	return true


## Takes the first copy of `card` from the top out, to nowhere. False when it is not here. A shortcut for
## `remove_at`: with copies of one card, use the index of the one you mean.
func remove(card: CardData) -> bool:
	var at := _cards.find(card)
	return at >= 0 and remove_at(at) != null


## Takes the card at `index` (0: the top) out, to nowhere, and returns it. An index outside the stack is an error and
## returns null. Emits `removed` with no `to`.
func remove_at(index: int) -> CardData:
	if index < 0 or index >= _cards.size():
		push_error("CardStack.remove_at: no card at index %d (the stack has %d)" % [index, _cards.size()])
		return null
	var card := _cards[index]
	_cards.remove_at(index)
	removed.emit(_one(card), null)
	return card


## Takes up to `n` cards off the top, to nowhere, and returns them top first. Emits `removed` with no `to`.
func take(n := 1) -> Array[CardData]:
	var taken := _take_top(n)
	if not taken.is_empty():
		removed.emit(taken, null)
	return taken


## Takes every card out, to nowhere. Emits `removed` with no `to` (when there was any card).
func clear() -> void:
	take(_cards.size())


## Draws up to `n` cards from the top, each put on top of `pile`, and returns them in the order drawn: the last one
## drawn ends on top of `pile`. Fewer when this stack runs out or `pile` is full.
func draw_to(pile: CardStack, n := 1) -> Array[CardData]:
	var drawn: Array[CardData] = []
	if pile == null or pile == self:
		push_error("CardStack.draw_to: draw to another stack")
		return drawn
	drawn = _take_top(pile._room(n))
	if drawn.is_empty():
		return drawn
	for card in drawn:
		pile._cards.push_front(card)
	removed.emit(drawn, pile)
	pile.added.emit(drawn, self)
	return drawn


## Moves the first copy of `card` from the top to `to` at `index`. False when it is not here or `to` is full. A
## shortcut for `move_at`: with copies of one card, use the index of the one you mean.
func move(card: CardData, to: CardStack, index := 0) -> bool:
	if to == null:
		push_error("CardStack.move: there is no stack to move to (use remove to take a card out)")
		return false
	var at := _cards.find(card)
	return at >= 0 and move_at(at, to, index)


## Moves the card at `index` (0: the top) to `to` at `to_index` (0: the top; -1 or past the end: the bottom). `to` may
## be this same stack, to move a card inside it (to the bottom, for example). False when `to` is full. No `to`, or an
## index outside the stack, is an error.
func move_at(index: int, to: CardStack, to_index := 0) -> bool:
	if to == null:
		push_error("CardStack.move_at: there is no stack to move to (use remove_at to take a card out)")
		return false
	if index < 0 or index >= _cards.size():
		push_error("CardStack.move_at: no card at index %d (the stack has %d)" % [index, _cards.size()])
		return false
	if to != self and to._room(1) == 0:
		return false
	var card := _cards[index]
	_cards.remove_at(index)
	to._insert(card, to_index)
	removed.emit(_one(card), to)
	to.added.emit(_one(card), self)
	return true


## Shuffles the cards with `rng` (Fisher–Yates). The same seed gives the same order. Without an rng it is an error and
## nothing changes. Emits `shuffled`.
func shuffle(rng: RandomNumberGenerator) -> void:
	if rng == null:
		push_error("CardStack.shuffle: pass a RandomNumberGenerator (the match's, or one with a seed)")
		return
	for i in range(_cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := _cards[i]
		_cards[i] = _cards[j]
		_cards[j] = swap
	shuffled.emit()


## Moves every card of `other` under this stack, in their order (only what fits), and returns them. With an `rng`,
## shuffles this stack afterwards: the discard goes back into the deck, shuffled.
func refill_from(other: CardStack, rng: RandomNumberGenerator = null) -> Array[CardData]:
	var moved: Array[CardData] = []
	if other == null or other == self:
		push_error("CardStack.refill_from: refill from another stack")
		return moved
	moved = other._take_top(_room(other.size()))
	_cards.append_array(moved)
	if not moved.is_empty():
		other.removed.emit(moved, self)
		added.emit(moved, other)
	if rng != null:
		shuffle(rng)
	return moved


## Plain data for a save, a network snapshot or a replay check: `{"cards": [ids, top first], "max_size": n}`.
func to_dict() -> Dictionary:
	var ids: Array = []
	for card in _cards:
		ids.append(String(card.id))
	return {"cards": ids, "max_size": max_size}


## Rebuilds a stack from `to_dict()`, finding each id in `catalog` by `CardData.id`. An id that is not in the catalog is
## an error and is left out. No signal is emitted.
static func from_dict(data: Dictionary, catalog: Array[CardData]) -> CardStack:
	var by_id: Dictionary[StringName, CardData] = {}
	for card in catalog:
		if card != null and card.id != &"" and not by_id.has(card.id):
			by_id[card.id] = card
	var saved_size: Variant = data.get("max_size", -1)
	var limit: int = saved_size if saved_size is int or saved_size is float else -1
	var stack := CardStack.new([], limit)
	var ids: Variant = data.get("cards", [])
	if not ids is Array:
		push_error("CardStack.from_dict: cards must be a list of ids")
		return stack
	for id: Variant in ids:
		var key := StringName(str(id))
		if not by_id.has(key):
			push_error("CardStack.from_dict: no card with id %s in the catalog; it is left out" % key)
			continue
		stack._cards.append(by_id[key])
	return stack


# How many of `wanted` cards fit (all of them when there is no limit).
func _room(wanted: int) -> int:
	if wanted <= 0:
		return 0
	if max_size < 0:
		return wanted
	return clampi(max_size - _cards.size(), 0, wanted)


func _insert(card: CardData, index: int) -> void:
	if index < 0 or index >= _cards.size():
		_cards.append(card)
	else:
		_cards.insert(index, card)


# Takes up to `n` cards off the top, with no signal.
func _take_top(n: int) -> Array[CardData]:
	var count := clampi(n, 0, _cards.size())
	var taken: Array[CardData] = _cards.slice(0, count)
	for i in count:
		_cards.remove_at(0)
	return taken


static func _one(card: CardData) -> Array[CardData]:
	var list: Array[CardData] = [card]
	return list
