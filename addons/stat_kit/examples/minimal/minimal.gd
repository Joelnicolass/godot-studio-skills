extends Control

## A hero card: attack, defense and moves on a StatBlock (`%Hero`), with defense capped at 10 in its `max_values`.
## The sword starts equipped as a start modifier in the Hero's inspector, so the editor already shows attack 7 under
## "Values". Sword, Shield and Swamp each add or remove one modifier (a `.tres` in `modifiers/`). One ring resource
## (+50 % attack) is worn on either hand: each hand adds it with its own source, and two +50 % add up to ×2. Bless adds
## two modifiers made in code under one source (press it twice: they stack); Remove blessing takes every one of them
## away with `remove_source`. The log shows each `stat_changed`.

const BLESSING := &"blessing"
const LEFT_RING := &"left_ring"
const RIGHT_RING := &"right_ring"
const LOG_LINES := 6

## Sword, Shield and Swamp add or remove these.
@export var sword: StatModifier
@export var shield: StatModifier
@export var swamp: StatModifier
## One ring, worn on either hand: each hand adds it with its own source.
@export var ring: StatModifier

@onready var hero: StatBlock = %Hero
@onready var values_label: Label = %Values
@onready var log_label: Label = %Log
@onready var sword_button: Button = %Sword
@onready var shield_button: Button = %Shield
@onready var swamp_button: Button = %Swamp
@onready var left_ring_button: Button = %LeftRing
@onready var right_ring_button: Button = %RightRing
@onready var bless_button: Button = %Bless
@onready var remove_blessing_button: Button = %RemoveBlessing


func _ready() -> void:
	hero.stat_changed.connect(_on_stat_changed)
	_wire(sword_button, sword)
	_wire(shield_button, shield)
	_wire(swamp_button, swamp)
	_wire_ring(left_ring_button, LEFT_RING)
	_wire_ring(right_ring_button, RIGHT_RING)
	bless_button.pressed.connect(_on_bless)
	remove_blessing_button.pressed.connect(_on_remove_blessing)
	_refresh()


# The blessing: two modifiers made in code, given by BLESSING when they are added.
func _blessing() -> Array[StatModifier]:
	return [StatModifier.plus(&"defense", 2), StatModifier.plus(&"moves", 1)]


func _wire(button: Button, mod: StatModifier) -> void:
	button.text = mod.describe()
	button.set_pressed_no_signal(hero.modifiers().has(mod))
	button.toggled.connect(func(on: bool) -> void: _toggle(mod, on))


func _wire_ring(button: Button, hand: StringName) -> void:
	button.text = ring.describe(hand)
	button.toggled.connect(func(on: bool) -> void: _wear(hand, on))


func _toggle(mod: StatModifier, on: bool) -> void:
	if on:
		hero.add(mod)
		_note("Added " + mod.describe())
	else:
		hero.remove(mod)
		_note("Removed " + mod.describe())
	_refresh()


func _wear(hand: StringName, on: bool) -> void:
	if on:
		hero.add(ring, hand)
		_note("Put on " + ring.describe(hand))
	else:
		hero.remove_source(hand)
		_note("Took off " + ring.describe(hand))
	_refresh()


func _on_bless() -> void:
	var gifts := _blessing()
	hero.add_all(gifts, BLESSING)
	var parts: PackedStringArray = []
	for mod in gifts:
		parts.append(mod.describe(BLESSING))
	_note("Blessed: " + ", ".join(parts))
	_refresh()


func _on_remove_blessing() -> void:
	var count := hero.remove_source(BLESSING)
	_note("Removed %d modifiers of %s" % [count, BLESSING])
	_refresh()


func _on_stat_changed(stat: StringName, new_value: float) -> void:
	_note("%s is now %s" % [stat, _num(new_value)])


# Each stat with its value, its limits and where it comes from. The handlers call it, not `stat_changed`: a bonus
# under a SET changes the list without changing the value.
func _refresh() -> void:
	var lines: PackedStringArray = []
	var all := hero.values()
	for stat in all:
		var limits := hero.sheet.limits(stat)
		var capped := " (max %s)" % _num(limits.y) if limits.y < INF else ""
		var parts: PackedStringArray = ["base " + _num(hero.base(stat))]
		parts.append_array(hero.describe(stat))
		lines.append("%s %s%s: %s" % [stat, _num(all[stat]), capped, ", ".join(parts)])
	values_label.text = "\n".join(lines)
	remove_blessing_button.disabled = not hero.sources().has(BLESSING)


func _note(line: String) -> void:
	var lines := (line + "\n" + log_label.text).strip_edges().split("\n")
	log_label.text = "\n".join(lines.slice(0, LOG_LINES))


# 7 → "7", 1.5 → "1.5".
func _num(x: float) -> String:
	return String.num(x, 3).trim_suffix(".0")
