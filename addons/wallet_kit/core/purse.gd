class_name Purse
extends RefCounted

## Amounts of resources or coins by key, as plain data: no nodes, no scene. Each key may have a limit (what goes past
## it is lost and reported); some keys may be substitutes that cover what is missing of others when paying, at a rate.
## Amounts are whole numbers from 0 up. A game keeps one per player in its rules; `Wallet` wraps one for the editor.

## The amount of `key` is now `value`.
signal changed(key: StringName, value: int)
## `lost` of `key` did not fit under its limit.
signal overflowed(key: StringName, lost: int)

var _amounts: Dictionary[StringName, int] = {}
var _limits: Dictionary[StringName, int] = {}
var _rules: Array[_Rule] = []


## A purse with `start` amounts and `limits` per key (both optional).
func _init(start: Dictionary = {}, limits: Dictionary = {}) -> void:
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


## Makes `rate` of `key` pay for 1 that is missing of any key in `covers` (empty: any key but `key`).
## `add_substitute(&"gold")`: gold covers what is missing of anything, 1 to 1.
## `add_substitute(&"wood", [&"gold"], 2)`: 2 wood cover 1 gold.
## When several substitutes can cover a key, they are tried in the order they were added.
## A `rate` under 1, an empty `key` or a `covers` that holds `key` is an error and adds nothing.
func add_substitute(key: StringName, covers: Array = [], rate: int = 1) -> void:
	if key == &"":
		push_error("Purse.add_substitute: the key is empty")
		return
	if rate < 1:
		push_error("Purse.add_substitute: the rate of %s must be 1 or more (%d)" % [key, rate])
		return
	var list: Array[StringName] = []
	for item: Variant in covers:
		list.append(StringName(item))
	if list.has(key):
		push_error("Purse.add_substitute: %s cannot cover itself" % key)
		return
	_rules.append(_Rule.new(key, list, rate))


## A copy of the substitutes, in the order they were added: `[{key, covers, rate}]`.
func substitutes() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for rule in _rules:
		list.append(rule.to_dict())
	return list


## The substitutes that can cover what is missing of `key`, in the order they are tried.
func substitutes_for(key: StringName) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for rule in _rules:
		if rule.covers_key(key):
			list.append(rule.to_dict())
	return list


## Takes every substitute away.
func clear_substitutes() -> void:
	_rules.clear()


## True when `cost` (`{key: amount}`) can be paid, the substitutes included.
func can_pay(cost: Dictionary) -> bool:
	var read: Variant = _read(cost, "can_pay")
	return read != null and _plan(read) != null


## What paying `cost` would take, by key, the substitutes included: `{gold: 1, wood: 1}` for 2 wood with 1 in the
## purse and gold as a substitute. Nothing is paid. Empty when it cannot be paid (and when `cost` is free: ask
## `can_pay`).
func payment_for(cost: Dictionary) -> Dictionary[StringName, int]:
	var none: Dictionary[StringName, int] = {}
	var read: Variant = _read(cost, "payment_for")
	if read == null:
		return none
	var plan: Variant = _plan(read)
	return plan if plan != null else none


## Pays `cost`, covering with the substitutes what is missing. False, and nothing changes, when it cannot be paid.
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
	return {"amounts": amounts_out, "limits": limits_out, "substitutes": substitutes()}


## Rebuilds a purse from `to_dict()`. No signal is emitted. It also reads the 0.2 format (`wildcard` and
## `wildcard_covers`) as one substitute at rate 1.
static func from_dict(data: Dictionary) -> Purse:
	var purse := Purse.new(data.get("amounts", {}), data.get("limits", {}))
	var saved: Variant = data.get("substitutes")
	if saved is Array:
		for entry: Variant in saved:
			if entry is Dictionary:
				var rule: Dictionary = entry
				purse.add_substitute(StringName(rule.get("key", "")), rule.get("covers", []), int(rule.get("rate", 1)))
		return purse
	var wildcard := StringName(data.get("wildcard", ""))
	if wildcard != &"":
		var covers: Array[StringName] = []
		var old_covers: Array = data.get("wildcard_covers", [])
		for key: Variant in old_covers:
			if StringName(key) != wildcard:
				covers.append(StringName(key))
		# A list that only held the wildcard itself covered nothing: it must not turn into "everything".
		if covers.is_empty() == old_covers.is_empty():
			purse.add_substitute(wildcard, covers)
	return purse


# What paying `cost` takes, by key (sorted), or null when it cannot be paid.
# 1. Each key of the cost takes its own stock first, so a substitute never spends what the cost asks of it directly.
# 2. What is still missing, key by key in sorted order, is covered by the substitutes in list order, each as many
#    units as its remaining stock allows.
func _plan(cost: Dictionary[StringName, int]) -> Variant:
	var taken: Dictionary[StringName, int] = {}
	var missing: Dictionary[StringName, int] = {}
	var wanted := _sorted_keys(cost)
	for key in wanted:
		var need := cost[key]
		if need == 0:
			continue
		var own := mini(amount(key), need)
		if own > 0:
			taken[key] = own
		if need > own:
			missing[key] = need - own
	for key in wanted:
		var still: int = missing.get(key, 0)
		for rule in _rules:
			if still == 0:
				break
			if not rule.covers_key(key):
				continue
			var left := amount(rule.key) - int(taken.get(rule.key, 0))
			@warning_ignore("integer_division")
			var units := mini(still, left / rule.rate)
			if units > 0:
				taken[rule.key] = int(taken.get(rule.key, 0)) + units * rule.rate
				still -= units
		if still > 0:
			return null
	var ordered: Dictionary[StringName, int] = {}
	for key in _sorted_keys(taken):
		ordered[key] = taken[key]
	return ordered


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


# One substitute: `rate` of `key` pay for 1 of what `covers` names (empty: anything but `key`).
class _Rule:
	var key: StringName
	var covers: Array[StringName]
	var rate: int

	func _init(key_in: StringName, covers_in: Array[StringName], rate_in: int) -> void:
		key = key_in
		covers = covers_in
		rate = rate_in

	func covers_key(other: StringName) -> bool:
		return other != key and (covers.is_empty() or covers.has(other))

	func to_dict() -> Dictionary:
		return {"key": key, "covers": covers.duplicate(), "rate": rate}
