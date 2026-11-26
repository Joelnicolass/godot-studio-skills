@tool
@icon("res://addons/bot_kit/icons/bot_brain.svg")
class_name BotBrain
extends Node

## Picks what a bot does, for any game: a villager by turns, a card player, a strategy rival. Each BotOption child
## (and each choice your script gives in `options`) says how much it wants it; `think()` picks the one that wants it
## most, and `chose` tells your game, which does it. What it chose last stays on a tie. `noise` makes an easier bot
## pick a worse choice now and then, with numbers from `rng`: the same seed picks the same way. The rule is
## `BotBrainCore.best`.

## It picked `choice`, on a think that found one scoring above 0: do it.
signal chose(choice: BotChoice)

# Hands out the seeds of brains left at rng_seed 0. Two fresh RandomNumberGenerators made in the same microsecond
# start with the same seed, so every brain takes its own number from this one.
static var _seeds := RandomNumberGenerator.new()

## On: it thinks on its own every `think_s`, about its parent. Off: your game calls `think()` (on each turn).
@export var auto_think := false:
	set(value):
		auto_think = value
		_think_left_s = 0.0
## How often it thinks with `auto_think` on. It thinks right away when `auto_think` turns on.
@export_range(0.02, 10.0, 0.01, "or_greater", "suffix:s") var think_s := 0.5
## How far each score moves at random before it picks, as a share of itself (0.15: up to 15 % up or down). 0 always
## picks the best.
@export_range(0.0, 1.0, 0.01) var noise := 0.0
## The seed of the brain's own rng: the same seed picks the same way in the same order. 0: a seed of its own, new each
## run. Changing it starts the own rng again; an rng you assigned is never touched.
@export var rng_seed := 0:
	set(value):
		rng_seed = value
		_own_rng = null

## Where the noise comes from. Your match's rng when you assign one (each think with noise draws one number per
## choice from it, in turn with the rest of your game); otherwise the brain's own, built from `rng_seed` the first time
## it is needed. Assigning null goes back to the own one.
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
## (context: Variant) -> Array[BotChoice]: choices from your game besides the BotOption children (one per legal
## order, one per enemy). Called on each think.
var options: Callable = Callable()
## What it chose last (null: nothing yet, or nothing scored above 0). It stays while nothing scores higher; set it to
## null to forget it.
var current: BotChoice
## Every choice the last think weighed, in order (the BotOption children, then `options`), to show their scores.
var last_choices: Array[BotChoice] = []

var _own_rng: RandomNumberGenerator
var _assigned_rng: RandomNumberGenerator
var _think_left_s := 0.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not auto_think:
		return
	_think_left_s -= delta
	if _think_left_s <= 0.0:
		_think_left_s = think_s
		think()


## Weighs every choice and picks one (`BotBrainCore.best`, with `current` kept on a tie, `noise` and `rng`). Each
## BotOption child and `options` get `context`: what the bot thinks about (the villager, the match as its player sees
## it). Null: the brain's parent. Emits `chose` and returns the choice, or null when nothing scores above 0.
func think(context: Variant = null) -> BotChoice:
	var about: Variant = context if context != null else get_parent()
	last_choices = _gather(about)
	var keep := current.id if current != null else &""
	current = BotBrainCore.best(last_choices, keep, rng, noise)
	if current != null:
		chose.emit(current)
	return current


func _gather(about: Variant) -> Array[BotChoice]:
	var out: Array[BotChoice] = []
	for child in get_children():
		var option := child as BotOption
		if option != null and option.enabled:
			out.append_array(option._choices(about))
	if options.is_valid():
		var more: Variant = options.call(about)
		if more is Array:
			for each: Variant in more:
				if each is BotChoice:
					out.append(each)
	return out


func _notification(what: int) -> void:
	if what == NOTIFICATION_CHILD_ORDER_CHANGED and Engine.is_editor_hint():
		update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	var ids: Dictionary[StringName, bool] = {}
	for child in get_children():
		var option := child as BotOption
		if option == null:
			continue
		# Read, not called: an option whose script is not a @tool has no methods in the editor.
		var each := option.id if not option.id.is_empty() else StringName(option.name)
		if ids.has(each):
			out.append('Two options are both "%s": give one of them another id.' % each)
		ids[each] = true
	if ids.is_empty():
		out.append("No BotOption child: it picks only among the choices your script gives in `options`.")
	return out
