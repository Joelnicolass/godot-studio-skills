class_name Purse
extends RefCounted

## Amounts of resources or coins by key, as plain data: no nodes, no scene. Each key may have a limit (what goes past
## it is lost and reported); one key may be a wildcard that covers, 1 to 1, what is missing of the others when paying.
## Amounts are whole numbers from 0 up. A game keeps one per player in its rules; `Wallet` wraps one for the editor.

## The amount of `key` is now `value`.
signal changed(key: StringName, value: int)
## `lost` of `key` did not fit under its limit.
signal overflowed(key: StringName, lost: int)

## The key that covers what is missing when paying (`&""`: no wildcard).
var wildcard: StringName = &""
## The keys the wildcard can cover. Empty: every key but itself.
var wildcard_covers: Array[StringName] = []

var _amounts: Dictionary[StringName, int] = {}
var _limits: Dictionary[StringName, int] = {}


## A purse with `start` amounts, `limits` per key and a `wildcard` key (all optional).
func _init(start: Dictionary = {}, limits: Dictionary = {}, wildcard_key: StringName = &"") -> void:
	wildcard = wildcard_key
	for key: Variant in limits:
		_limits[StringName(key)] = maxi(int(limits[key]), 0)
	for key: Variant in start:
		var value := int(start[key])
		_amounts[StringName(key)] = (
			clampi(value, 0, limit(StringName(key))) if has_limit(StringName(key)) else maxi(value, 0)
		)


## How much of `key` there is (0 when it was never added).
func amount(key: StringName) -> int:
	return _amounts.get(key, 0)


## A copy of every amount, by key.
func amounts() -> Dictionary[StringName, int]:
	return _amounts.duplicate()


## Every key with an amount or a limit, sorted.
func keys() -> Array[StringName]:
	var seen: Dictionary[StringName, bool] = {}
	for key in _amounts:
		seen[key] = true
	for key in _limits:
		seen[key] = true
	var list: Array[StringName] = []
	list.assign(seen.keys())
	list.sort_custom(_before)
	return list


func has_limit(key: StringName) -> bool:
	return _limits.has(key)


## The most `key` can hold (-1: no limit).
func limit(key: StringName) -> int:
	return _limits.get(key, -1)


## Sets the most `key` can hold; a negative `value` takes the limit away. Returns what did not fit any more.
func set_limit(key: StringName, value: int) -> int:
	if value < 0:
		_limits.erase(key)
		return 0
	_limits[key] = value
	return _store(key, amount(key))


## Sets the amount of `key` (from 0 up to its limit). Returns what did not fit.
func set_amount(key: StringName, value: int) -> int:
	if value < 0:
		push_error("Purse: %s cannot be negative (%d)" % [key, value])
		return 0
	return _store(key, value)


## Adds `gains` (`{key: amount}`). Returns what did not fit under the limits, `{key: lost}` (empty when it all fit).
## A negative amount adds nothing at all and is an error.
func add(gains: Dictionary) -> Dictionary[StringName, int]:
	var lost: Dictionary[StringName, int] = {}
	var read: Variant = _read(gains, "add")
	if read == null:
		return lost
	var clean: Dictionary[StringName, int] = read
	for key in _sorted_keys(clean):
		if clean[key] == 0:
			continue
		var over := _store(key, amount(key) + clean[key])
		if over > 0:
			lost[key] = over
	return lost


## True when `cost` (`{key: amount}`) can be paid, the wildcard included.
func can_pay(cost: Dictionary) -> bool:
	var read: Variant = _read(cost, "can_pay")
	return read != null and _plan(read) != null


## What paying `cost` would take, by key, the wildcard included: `{wood: 1, gold: 1}` for 2 wood with 1 in the purse
## and gold as the wildcard. Empty when it cannot be paid (and when `cost` is free: ask `can_pay`).
func payment_for(cost: Dictionary) -> Dictionary[StringName, int]:
	var none: Dictionary[StringName, int] = {}
	var read: Variant = _read(cost, "payment_for")
	if read == null:
		return none
	var plan: Variant = _plan(read)
	return plan if plan != null else none


## Pays `cost`, covering with the wildcard what is missing. False, and nothing changes, when it cannot be paid.
func pay(cost: Dictionary) -> bool:
	var read: Variant = _read(cost, "pay")
	if read == null:
		return false
	var plan: Variant = _plan(read)
	if plan == null:
		return false
	var taken: Dictionary[StringName, int] = plan
	for key in _sorted_keys(taken):
		_store(key, amount(key) - taken[key])
	return true


## Plain data for a save, a network snapshot or a replay check.
func to_dict() -> Dictionary:
	var amounts_out: Dictionary = {}
	for key in _sorted_keys(_amounts):
		amounts_out[key] = _amounts[key]
	var limits_out: Dictionary = {}
	for key in _sorted_keys(_limits):
		limits_out[key] = _limits[key]
	return {
		"amounts": amounts_out,
		"limits": limits_out,
		"wildcard": wildcard,
		"wildcard_covers": wildcard_covers.duplicate(),
	}


## Rebuilds a purse from `to_dict()`. No signal is emitted.
static func from_dict(data: Dictionary) -> Purse:
	var purse := Purse.new(data.get("amounts", {}), data.get("limits", {}), StringName(data.get("wildcard", "")))
	for key: Variant in data.get("wildcard_covers", []):
		purse.wildcard_covers.append(StringName(key))
	return purse


## Can the wildcard pay for what is missing of `key`?
func covers(key: StringName) -> bool:
	if wildcard == &"" or key == wildcard:
		return false
	return wildcard_covers.is_empty() or wildcard_covers.has(key)


# What paying `cost` takes, by key, or null when it cannot be paid. Keys in sorted order, so it is the same every run.
func _plan(cost: Dictionary[StringName, int]) -> Variant:
	var taken: Dictionary[StringName, int] = {}
	var from_wildcard := 0
	for name in _sorted_keys(cost):
		var need := cost[name]
		if need == 0:
			continue
		if name == wildcard:
			from_wildcard += need
			continue
		var own := mini(amount(name), need)
		if own > 0:
			taken[name] = own
		var missing := need - own
		if missing > 0:
			if not covers(name):
				return null
			from_wildcard += missing
	if from_wildcard > 0:
		if wildcard == &"" or amount(wildcard) < from_wildcard:
			return null
		taken[wildcard] = from_wildcard
	return taken


# Stores `value` for `key`, cut at the limit; emits `overflowed` and `changed`. Returns what was cut.
func _store(key: StringName, value: int) -> int:
	var kept := mini(value, limit(key)) if has_limit(key) else value
	var lost := value - kept
	if lost > 0:
		overflowed.emit(key, lost)
	var before := amount(key)
	_amounts[key] = kept
	if before != kept:
		changed.emit(key, kept)
	return lost


# `amounts_in` with StringName keys and int values, or null (and an error) when an amount is negative.
func _read(amounts_in: Dictionary, where: String) -> Variant:
	var clean: Dictionary[StringName, int] = {}
	for key: Variant in amounts_in:
		var value := int(amounts_in[key])
		if value < 0:
			push_error("Purse.%s: %s is negative (%d)" % [where, key, value])
			return null
		clean[StringName(key)] = clean.get(StringName(key), 0) + value
	return clean


static func _sorted_keys(dict: Dictionary) -> Array[StringName]:
	var list: Array[StringName] = []
	for key: Variant in dict:
		list.append(StringName(key))
	list.sort_custom(_before)
	return list


static func _before(a: StringName, b: StringName) -> bool:
	return String(a) < String(b)
