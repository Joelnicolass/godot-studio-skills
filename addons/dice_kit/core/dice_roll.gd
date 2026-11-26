class_name DiceRoll
extends RefCounted

## What the dice said, as plain data: the die in each place (`dice`), the face it showed (`faces`) and that face's
## place in its die (`indices`, for views and the network). A place is a slot: 0 is the first die rolled. Read it with
## `sum()`, `count(tag)`, `values()` and `highest()` / `lowest()`; roll some dice again with `rerolled()`. Make one with
## `DieData.roll(n, rng)`, `DiceRoll.of(pool, rng)` (mixed dice), a `DiceRoller`, or `from_dict` / `from_indices` for a
## roll that came from the network or a log. Each die draws exactly one number from the rng, in order: the same seed
## gives the same roll. A roll never changes: what reads it gets copies.

## The die in each slot, in the order rolled (a copy).
var dice: Array[DieData]:
	get:
		return _dice.duplicate()
	set(_value):
		push_error("DiceRoll.dice is read only")
## The place in `DieData.faces` of the face each die showed, 0 first (a copy).
var indices: Array[int]:
	get:
		return _indices.duplicate()
	set(_value):
		push_error("DiceRoll.indices is read only")
## The face each die showed (a copy).
var faces: Array[DieFace]:
	get:
		return _faces.duplicate()
	set(_value):
		push_error("DiceRoll.faces is read only")

var _dice: Array[DieData] = []
var _indices: Array[int] = []
var _faces: Array[DieFace] = []


## The values of every face, added up (0 for an empty roll).
func sum() -> int:
	var total := 0
	for face in _faces:
		total += face.value
	return total


## How many times `tag` came up, over every face: a face `[hit, hit, shield]` counts 2 hits.
func count(tag: StringName) -> int:
	var found := 0
	for face in _faces:
		found += face.tags.count(tag)
	return found


## True when `tag` came up at least once.
func has(tag: StringName) -> bool:
	return count(tag) > 0


## The slots (die places, 0 first) whose face has `tag`, in order. For `rerolled(roll.slots_with(&"blank"), rng)`.
func slots_with(tag: StringName) -> Array[int]:
	var list: Array[int] = []
	for slot in _faces.size():
		if _faces[slot].tags.has(tag):
			list.append(slot)
	return list


## The value of each die, in the order rolled.
func values() -> Array[int]:
	var list: Array[int] = []
	for face in _faces:
		list.append(face.value)
	return list


## How many dice it has (0: an empty roll, what a broken setup returns).
func size() -> int:
	return _faces.size()


## The slots of the `n` highest values, highest first (a tie keeps the earlier slot first). For the values themselves,
## `highest_values(n)`. Fewer dice than `n`: all of them; `n` under 1: none.
func highest(n := 1) -> Array[int]:
	return _ranked(true).slice(0, maxi(n, 0))


## The slots of the `n` lowest values, lowest first (a tie keeps the earlier slot first).
func lowest(n := 1) -> Array[int]:
	return _ranked(false).slice(0, maxi(n, 0))


## The `n` highest values, highest first: advantage is `highest_values()[0]`.
func highest_values(n := 1) -> Array[int]:
	return _values_at(highest(n))


## The `n` lowest values, lowest first: "drop the lowest" is `sum() - lowest_values()[0]`.
func lowest_values(n := 1) -> Array[int]:
	return _values_at(lowest(n))


## A new roll with the dice at `slots` rolled again and the others kept as they are. Each rerolled die draws one number
## from `rng`, in slot order (a slot named twice is rolled once). This roll does not change. A slot out of range or no
## `rng`: an error and an empty roll, and nothing drawn.
func rerolled(slots: Array[int], rng: RandomNumberGenerator) -> DiceRoll:
	if rng == null:
		push_error("DiceRoll.rerolled: no RandomNumberGenerator to roll with")
		return DiceRoll.new()
	var order: Array[int] = []
	for slot in slots:
		if slot < 0 or slot >= _faces.size():
			push_error("DiceRoll.rerolled: there is no die %d (the roll has %d)" % [slot, _faces.size()])
			return DiceRoll.new()
		if not order.has(slot):
			order.append(slot)
	order.sort()
	var picked := _indices.duplicate()
	for slot in order:
		picked[slot] = rng.randi_range(0, _dice[slot].faces.size() - 1)
	return from_indices(_dice, picked)


## The roll in words, for a log or a tooltip: `"3 + 5 = 8"`, `"1 + 0 + 2 = 3 · 1 blank · 1 crit · 1 hit"` (tags in
## alphabetical order). One die shows its value without a sum (`"4"`); a roll whose faces are all worth 0 shows only
## its tags (`"2 hit"`). Empty for an empty roll.
func describe() -> String:
	if _faces.is_empty():
		return ""
	var parts: PackedStringArray = []
	var numbers: PackedStringArray = []
	var worth := false
	for face in _faces:
		numbers.append(str(face.value))
		worth = worth or face.value != 0
	var tags := _tags()
	if worth or tags.is_empty():
		parts.append(numbers[0] if numbers.size() == 1 else "%s = %d" % [" + ".join(numbers), sum()])
	for tag in tags:
		parts.append("%d %s" % [count(tag), tag])
	return " · ".join(parts)


## Plain data for a save, a network message or a replay check: `{"indices": [..]}`. The dice are the game's to know;
## `DiceRoll.from_dict(pool, data)` rebuilds it with them.
func to_dict() -> Dictionary:
	return {"indices": _indices.duplicate()}


## Rolls one die of each kind in `pool`, in order (two d6 and a d8: `[d6, d6, d8]`), drawing one number from `rng` per
## die. An empty pool, a null die, a die that cannot roll (no faces, an empty slot) or no `rng`: an error and an empty
## roll, and nothing drawn.
static func of(pool: Array[DieData], rng: RandomNumberGenerator) -> DiceRoll:
	var roll := DiceRoll.new()
	if not _can_roll(pool, rng):
		return roll
	for die in pool:
		var index := rng.randi_range(0, die.faces.size() - 1)
		roll._dice.append(die)
		roll._indices.append(index)
		roll._faces.append(die.faces[index])
	return roll


## The roll `to_dict()` saved, shown by the same `pool` of dice (the game knows which dice it rolled). It draws
## nothing; JSON's floats are fine. No `indices` list in `data`, or indices that do not fit the dice: an error and an
## empty roll.
static func from_dict(pool: Array[DieData], data: Dictionary) -> DiceRoll:
	var saved: Variant = data.get("indices")
	if not saved is Array:
		push_error("DiceRoll.from_dict: no indices list in %s" % [data])
		return DiceRoll.new()
	var picked: Array = saved
	return from_indices(pool, picked)


## The roll `pool` showed when each die came up on the face at `picked` (one index per die, as `to_dict()` keeps
## them): a log, or a fixed roll for a tutorial. It draws nothing. Ints may come as floats (from JSON). A size that
## does not match, a die that cannot roll (null, no faces, an empty slot) or an index out of its die: an error and an
## empty roll.
static func from_indices(pool: Array[DieData], picked: Array) -> DiceRoll:
	var roll := DiceRoll.new()
	if picked.size() != pool.size():
		push_error("DiceRoll.from_indices: %d indices for %d dice" % [picked.size(), pool.size()])
		return roll
	for slot in pool.size():
		var die := pool[slot]
		var raw: Variant = picked[slot]
		var index := int(raw) if raw is int or raw is float else -1
		if die == null or not die.can_roll() or index < 0 or index >= die.faces.size():
			push_error("DiceRoll.from_indices: die %d cannot show face %s" % [slot, raw])
			return DiceRoll.new()
		roll._dice.append(die)
		roll._indices.append(index)
		roll._faces.append(die.faces[index])
	return roll


# The tags that came up, each once, in alphabetical order.
func _tags() -> Array[StringName]:
	var list: Array[StringName] = []
	for face in _faces:
		for tag in face.tags:
			if tag != &"" and not list.has(tag):
				list.append(tag)
	list.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return list


# Every slot, by value (highest or lowest first); a tie keeps slot order.
func _ranked(high_first: bool) -> Array[int]:
	var slots: Array[int] = []
	for slot in _faces.size():
		slots.append(slot)
	slots.sort_custom(
		func(a: int, b: int) -> bool:
			var left := _faces[a].value
			var right := _faces[b].value
			if left == right:
				return a < b
			return left > right if high_first else left < right
	)
	return slots


func _values_at(slots: Array[int]) -> Array[int]:
	var list: Array[int] = []
	for slot in slots:
		list.append(_faces[slot].value)
	return list


static func _can_roll(pool: Array[DieData], rng: RandomNumberGenerator) -> bool:
	if rng == null:
		push_error("DiceRoll: no RandomNumberGenerator to roll with")
		return false
	if pool.is_empty():
		push_error("DiceRoll: no dice to roll")
		return false
	for slot in pool.size():
		var die := pool[slot]
		if die == null:
			push_error("DiceRoll: die %d is null" % slot)
			return false
		if die.faces.is_empty():
			push_error("DiceRoll: die %d has no faces" % slot)
			return false
		if die.faces.has(null):
			push_error("DiceRoll: die %d has an empty face slot; fill it or remove it" % slot)
			return false
	return true
