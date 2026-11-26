@tool
@icon("res://addons/bot_kit/icons/bot_option.svg")
class_name BotOption
extends Node

## One thing a BotBrain can choose: gather, build, rest, attack. Add it as a child of the brain. As it is, it scores
## `score` (set it in the inspector). For a score from your game, override `_score(context)`; for several choices from
## one node (one per enemy, one per legal order), override `_choices(context)`. The context is what the brain thinks
## about: what your game passed to `think()`, or the brain's parent.

## Off: the brain never picks it.
@export var enabled := true
## Its name in the choice (empty: the node's name).
@export var id := &"":
	set(value):
		id = value
		if is_inside_tree() and get_parent() != null:
			get_parent().update_configuration_warnings()
## How much it wants it, unless `_score` is overridden (0 or less: not at all).
@export_range(0.0, 10.0, 0.05, "or_greater", "or_less") var score := 1.0


## How much it wants it now (0 or less: not at all). Called on each think of the brain.
func _score(_context: Variant) -> float:
	return score


## What it offers on each think. Unless overridden, one choice: `choice_id()`, `_score(context)`, and the option
## itself as payload (so your game can ask it what to do).
func _choices(context: Variant) -> Array[BotChoice]:
	return [BotChoice.new(choice_id(), _score(context), self)]


## Its id in a choice: `id`, or the node's name.
func choice_id() -> StringName:
	return id if not id.is_empty() else StringName(name)


func _get_configuration_warnings() -> PackedStringArray:
	if not get_parent() is BotBrain:
		return PackedStringArray(["A BotOption works as a child of a BotBrain."])
	return PackedStringArray()
