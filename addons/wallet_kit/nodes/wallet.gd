@tool
class_name Wallet
extends Node

## Resources or coins in the scene tree. It owns a `Purse` built from its inspector values (start amounts, limits,
## wildcard), or shows one your game's rules already keep (`use_purse`). Every call goes to the purse: `can_pay`,
## `pay`, `add`, `amount`.

## The amount of `key` is now `value`.
signal changed(key: StringName, value: int)
## `lost` of `key` did not fit under its limit.
signal overflowed(key: StringName, lost: int)
## The wallet shows another purse now (`use_purse`, `use_own_purse`, or new `start_amounts`): read every amount again.
signal rebuilt

## What the purse holds when it is built. Changing it builds the purse again with these amounts.
@export var start_amounts: Dictionary[StringName, int] = {}:
	set(value):
		start_amounts = value
		_rebuild_own()
## The most each key can hold. A key that is not here has no limit.
@export var limits: Dictionary[StringName, int] = {}:
	set(value):
		limits = value
		if _own and _purse != null:
			for key in _purse.keys():
				_purse.set_limit(key, int(value.get(key, -1)))
			for key in value:
				_purse.set_limit(key, value[key])
		update_configuration_warnings()
## The key that covers, 1 to 1, what is missing when paying. Empty: no wildcard.
@export var wildcard: StringName = &"":
	set(value):
		wildcard = value
		if _own and _purse != null:
			_purse.wildcard = value
		update_configuration_warnings()
## The keys the wildcard can cover. Empty: every key but itself.
@export var wildcard_covers: Array[StringName] = []:
	set(value):
		wildcard_covers = value
		if _own and _purse != null:
			_purse.wildcard_covers = value.duplicate()
		update_configuration_warnings()

## The purse this wallet shows.
var purse: Purse:
	get:
		if _purse == null:
			_rebuild_own()
		return _purse

var _purse: Purse
var _own := true


## Shows `other` instead of the wallet's own purse (your game's rules keep it). The inspector values no longer apply
## until `use_own_purse()`. Emits `rebuilt`.
func use_purse(other: Purse) -> void:
	_own = false
	_set_purse(other)


## Goes back to a purse built from the inspector values, with the start amounts. Emits `rebuilt`.
func use_own_purse() -> void:
	_own = true
	_rebuild_own()


func amount(key: StringName) -> int:
	return purse.amount(key)


func amounts() -> Dictionary[StringName, int]:
	return purse.amounts()


func limit(key: StringName) -> int:
	return purse.limit(key)


func can_pay(cost: Dictionary) -> bool:
	return purse.can_pay(cost)


func payment_for(cost: Dictionary) -> Dictionary[StringName, int]:
	return purse.payment_for(cost)


func pay(cost: Dictionary) -> bool:
	return purse.pay(cost)


func add(gains: Dictionary) -> Dictionary[StringName, int]:
	return purse.add(gains)


func set_amount(key: StringName, value: int) -> int:
	return purse.set_amount(key, value)


func _rebuild_own() -> void:
	if not _own:
		return
	var next := Purse.new(start_amounts, limits, wildcard)
	next.wildcard_covers = wildcard_covers.duplicate()
	_set_purse(next)
	update_configuration_warnings()


func _set_purse(next: Purse) -> void:
	if _purse != null:
		_purse.changed.disconnect(_on_changed)
		_purse.overflowed.disconnect(_on_overflowed)
	_purse = next
	_purse.changed.connect(_on_changed)
	_purse.overflowed.connect(_on_overflowed)
	rebuilt.emit()


func _on_changed(key: StringName, value: int) -> void:
	changed.emit(key, value)


func _on_overflowed(key: StringName, lost: int) -> void:
	overflowed.emit(key, lost)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	for key in start_amounts:
		if start_amounts[key] < 0:
			warnings.append("start_amounts: %s is negative." % key)
		elif limits.has(key) and start_amounts[key] > limits[key]:
			warnings.append("start_amounts: %s starts above its limit (%d)." % [key, limits[key]])
	for key in limits:
		if limits[key] < 0:
			warnings.append("limits: %s is negative (leave the key out for no limit)." % key)
	if wildcard != &"" and wildcard_covers.has(wildcard):
		warnings.append("The wildcard cannot cover itself: take %s out of wildcard_covers." % wildcard)
	if wildcard == &"" and not wildcard_covers.is_empty():
		warnings.append("wildcard_covers does nothing without a wildcard key.")
	return warnings
