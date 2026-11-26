extends BotOption

## A part of the house: more the more wood it has (`score` with `full_wood`), only with the wood and the strength.

const Villager := preload("res://addons/bot_kit/examples/turn_based/villager.gd")

## With this much wood it wants it the most.
@export var full_wood := 6


func _score(context: Variant) -> float:
	var villager := context as Villager
	if villager.is_done() or villager.wood < Villager.BUILD_WOOD or villager.energy < Villager.BUILD_ENERGY:
		return 0.0
	return score * minf(float(villager.wood) / full_wood, 1.0)
