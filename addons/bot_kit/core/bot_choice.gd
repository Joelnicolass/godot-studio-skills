class_name BotChoice
extends RefCounted

## One thing a bot can do, with how much it wants it: what `BotBrainCore.best` picks from. `id` names it (a mode, an
## order, an option node), `score` is how much it wants it (0 or less: not at all), `payload` is whatever your game
## wants back with it (an order to send, a target, the node that runs it).

## Its name. The choice a bot already does is found by it: keep ids unique within one decision.
var id: StringName
## How much the bot wants it. The highest above 0 wins.
var score: float
## Yours: what to do when it wins (an order with its arguments, a target, a node). The kit never reads it.
var payload: Variant


func _init(choice_id := &"", choice_score := 0.0, choice_payload: Variant = null) -> void:
	id = choice_id
	score = choice_score
	payload = choice_payload


func _to_string() -> String:
	return "%s (%s)" % [id, snappedf(score, 0.01)]
