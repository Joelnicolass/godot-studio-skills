@tool
@icon("res://addons/dice_kit/icons/dice_roller.svg")
class_name DiceRoller
extends Node

## Rolls dice in the scene tree. Drop a die in `die` (a ready one from `addons/dice_kit/dice/`, or your own `DieData`),
## set `count`, and call `roll()`: the `DiceRoll` it returns (and `rolled` carries) says what came up, with `sum()` and
## `count(tag)`. `extra_dice` mixes in other dice (2d6 + 1d8). Press Roll in the inspector to try it without running
## the game. Every number comes from `rng`: its own one, built from `rng_seed`, or your match's when you assign it.

## A roll came up, from `roll()` or from the inspector's Roll button. A `DiceTray3D` listens to this one.
signal rolled(roll: DiceRoll)
## The dice a roll takes changed: `die`, `count`, `extra_dice`, or a face inside one of them. A `DiceTray3D` shows the
## new dice at rest.
signal dice_changed

const _LAST_RESULT := &"last_result"

# Hands out the seeds of rollers left at rng_seed 0. Two fresh RandomNumberGenerators made in the same microsecond
# start with the same seed, so every roller takes its own number from this one.
static var _seeds := RandomNumberGenerator.new()

## The kind of die it rolls `count` of.
@export var die: DieData:
	set(value):
		die = value
		_dice_set_changed()
## How many dice of `die` a roll takes when it is not told how many.
@export_range(1, 20, 1, "or_greater") var count := 1:
	set(value):
		count = value
		_dice_set_changed()
## Other dice every roll takes too, one of each, after the `count` dice of `die`: a d8 here and a d6 in `die` with
## `count` 2 rolls 2d6 + 1d8. Leave `die` empty to roll only these.
@export var extra_dice: Array[DieData] = []:
	set(value):
		extra_dice = value
		_dice_set_changed()
## The seed of the roller's own rng: the same seed gives the same rolls in the same order. 0: a seed of its own, new
## each run. Changing it starts the own rng again; an rng you assigned is never touched.
@export var rng_seed := 0:
	set(value):
		rng_seed = value
		_own_rng = null
@export_group("Try it")
## Rolls with these values, in the editor too, and shows the result below (last_result).
@export_tool_button("Roll", "Play") var roll_button := _try_roll

## Where the numbers come from. Your match's rng when you assign one (each die draws one number from it, in turn with
## the rest of your game); otherwise the roller's own, built from `rng_seed` the first time it is needed. Assigning
## null goes back to the own one.
var rng: RandomNumberGenerator:
	get:
		if _assigned_rng != null:
			return _assigned_rng
		if _own_rng == null:
			_own_rng = RandomNumberGenerator.new()
			_own_rng.seed = rng_seed if rng_seed != 0 else (_seeds.randi() << 32) | _seeds.randi()
		return _own_rng
	set(value):
		_assigned_rng = value
## The last roll that came up (null before the first).
var last_roll: DiceRoll

var _own_rng: RandomNumberGenerator
var _assigned_rng: RandomNumberGenerator
var _watched: Array[DieData] = []


## Rolls `n` dice of `die` (-1: `count`) and one of each of `extra_dice` with `rng`, keeps the result in `last_roll`
## and emits `rolled`. No dice at all, a die that cannot roll or an `n` under -1: an error, an empty roll, no signal
## and nothing drawn.
func roll(n := -1) -> DiceRoll:
	if n < -1:
		push_error("DiceRoller.roll: n must be 0 or more, or -1 for count (%d)" % n)
		return DiceRoll.new()
	var result := DiceRoll.of(pool(n), rng)
	if result.size() == 0:
		return result
	last_roll = result
	rolled.emit(result)
	if Engine.is_editor_hint():
		notify_property_list_changed()
	return result


## The dice a roll of `n` takes (-1: `count`), in order: `n` of `die`, then `extra_dice`. For `DiceRoll.from_dict`
## on the other side of the network, or to show them before rolling.
func pool(n := -1) -> Array[DieData]:
	var list: Array[DieData] = []
	if die != null:
		for slot in count if n == -1 else maxi(n, 0):
			list.append(die)
	list.append_array(extra_dice)
	return list


func _try_roll() -> void:
	roll()


func _dice_set_changed() -> void:
	_watch()
	update_configuration_warnings()
	dice_changed.emit()


# Listens to `changed` of `die` and of every extra die, and only to those.
func _watch() -> void:
	for watched in _watched:
		if watched.changed.is_connected(_on_die_edited):
			watched.changed.disconnect(_on_die_edited)
	_watched.clear()
	var every: Array[DieData] = [die]
	every.append_array(extra_dice)
	for data in every:
		if data != null and not _watched.has(data):
			data.changed.connect(_on_die_edited)
			_watched.append(data)


func _on_die_edited() -> void:
	update_configuration_warnings()
	dice_changed.emit()


func _get_property_list() -> Array[Dictionary]:
	return [{"name": _LAST_RESULT, "type": TYPE_STRING, "usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY}]


func _get(property: StringName) -> Variant:
	if property != _LAST_RESULT:
		return null
	return last_roll.describe() if last_roll != null else "(press Roll)"


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if die == null and extra_dice.is_empty():
		warnings.append("No die: drag one into die (addons/dice_kit/dice/d6.tres) or create a DieData.")
		return warnings
	if die != null:
		warnings.append_array(_problems_of(die, "The die"))
	for slot in extra_dice.size():
		if extra_dice[slot] == null:
			warnings.append("extra_dice: slot %d is empty. Drag a die there or remove the slot." % slot)
		else:
			warnings.append_array(_problems_of(extra_dice[slot], "extra_dice[%d]" % slot))
	return warnings


func _problems_of(data: DieData, label: String) -> PackedStringArray:
	if data.faces.is_empty():
		return PackedStringArray(["%s has no faces: add DieFace entries to its faces list." % label])
	var empty := data.faces.count(null)
	if empty > 0:
		return PackedStringArray(
			["%s has %d empty face slot(s), so it cannot roll: fill them or remove them." % [label, empty]]
		)
	return PackedStringArray()
