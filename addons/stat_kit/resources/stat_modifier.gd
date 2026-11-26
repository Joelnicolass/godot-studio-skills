@tool
@icon("res://addons/stat_kit/icons/stat_modifier.svg")
class_name StatModifier
extends Resource

## One bonus to one stat: +2 attack from a sword, +10 % attack from a ring, ×1.5 defense from a shield, moves fixed at
## 1 in a swamp. A `StatSheet` (or a `StatBlock`) computes `(base + every ADD) × (1 + every PERCENT) × every MUL`,
## and when there is a SET, the last SET added wins instead. `source` says who gives it, so every bonus of an item or a
## buff can be taken away at once; the code that adds it can also pass its own source (`StatSheet.add(mod, source)`).

## How the modifier changes the stat. ADD adds `amount` to the base. MUL multiplies by `amount`. SET fixes the stat at
## `amount`. PERCENT adds `amount` as a percent bonus, and percent bonuses add up before they multiply (0.1 is +10 %;
## two +10 % make +20 %).
enum Op { ADD, MUL, SET, PERCENT }

const _OP_NAMES: Array[String] = ["add", "mul", "set", "percent"]

## The stat it changes (for example `attack`).
@export var stat: StringName = &"":
	set(value):
		stat = value
		emit_changed()
## Add: adds `amount` to the base. Mul: multiplies by `amount` (two ×1.5 make ×2.25). Set: the stat is `amount`,
## whatever the rest says. Percent: `amount` is a percent bonus that adds up with the others (0.5 is +50 %; two +50 %
## make ×2).
@export var op := Op.ADD:
	set(value):
		op = value
		emit_changed()
## What it adds (Add), the factor (Mul, 1.5 is +50 %), the value it fixes (Set) or the fraction (Percent, 0.1 is
## +10 %). A negative Add or Percent is a penalty.
@export var amount: float = 0.0:
	set(value):
		amount = value
		emit_changed()
## Who gives it: an item, an unlock, a buff. `remove_source` takes every modifier of one source away at once. The code
## that adds it may pass another source instead (two rings from one `.tres`).
@export var source: StringName = &"":
	set(value):
		source = value
		emit_changed()


## A modifier of `p_stat`. Every value has a default, so the editor can create one empty.
func _init(p_stat := &"", p_op := Op.ADD, p_amount := 0.0, p_source := &"") -> void:
	stat = p_stat
	op = p_op
	amount = p_amount
	source = p_source


## Adds `p_amount` to `p_stat`: `StatModifier.plus(&"attack", 2, &"sword")`.
static func plus(p_stat: StringName, p_amount: float, p_source: StringName = &"") -> StatModifier:
	return StatModifier.new(p_stat, Op.ADD, p_amount, p_source)


## A percent bonus to `p_stat` that adds up with the others: `StatModifier.percent(&"attack", 0.1, &"ring")` is +10 %.
static func percent(p_stat: StringName, p_fraction: float, p_source: StringName = &"") -> StatModifier:
	return StatModifier.new(p_stat, Op.PERCENT, p_fraction, p_source)


## Multiplies `p_stat` by `p_factor`: `StatModifier.times(&"food", 1.5, &"granary")`.
static func times(p_stat: StringName, p_factor: float, p_source: StringName = &"") -> StatModifier:
	return StatModifier.new(p_stat, Op.MUL, p_factor, p_source)


## Fixes `p_stat` at `p_value`: `StatModifier.fixed(&"moves", 1, &"swamp")`.
static func fixed(p_stat: StringName, p_value: float, p_source: StringName = &"") -> StatModifier:
	return StatModifier.new(p_stat, Op.SET, p_value, p_source)


## One line for a tooltip: `+2 attack (sword)`, `+10 % attack (ring)`, `×1.5 food (granary)`, `= 1 moves (swamp)`.
## With `p_source`, it names that source instead of its own (the one it was added with). No source, no brackets.
func describe(p_source: StringName = &"") -> String:
	var text := ""
	match op:
		Op.MUL:
			text = "×%s %s" % [_number(amount), stat]
		Op.SET:
			text = "= %s %s" % [_number(amount), stat]
		Op.PERCENT:
			text = "%s%s %% %s" % ["" if amount < 0.0 else "+", _number(amount * 100.0), stat]
		_:
			text = "%s%s %s" % ["" if amount < 0.0 else "+", _number(amount), stat]
	var named := p_source if p_source != &"" else source
	return text if named == &"" else "%s (%s)" % [text, named]


## Plain data for a save or the network: `{"stat", "op" ("add", "mul", "set" or "percent"), "amount", "source"}`.
func to_dict() -> Dictionary:
	return {"stat": String(stat), "op": _OP_NAMES[op], "amount": amount, "source": String(source)}


## A modifier from `to_dict()`. `op` may be the name or its number. An unknown `op` is an error and returns null.
static func from_dict(data: Dictionary) -> StatModifier:
	var saved: Variant = data.get("op", "add")
	var found := -1
	if saved is String or saved is StringName:
		found = _OP_NAMES.find(str(saved).to_lower())
	elif saved is int or saved is float:
		found = int(saved) if int(saved) >= 0 and int(saved) < _OP_NAMES.size() else -1
	if found < 0:
		push_error("StatModifier.from_dict: unknown op %s" % [saved])
		return null
	return StatModifier.new(
		StringName(str(data.get("stat", ""))),
		found as Op,
		float(data.get("amount", 0.0)),
		StringName(str(data.get("source", "")))
	)


# 2 → "2", 1.5 → "1.5", 1/3 → "0.333".
static func _number(x: float) -> String:
	return String.num(x, 3).trim_suffix(".0")
