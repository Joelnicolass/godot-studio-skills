extends BotOption

## Wood for the house: `score` with no wood, less the more it has, nothing without the strength to carry it.

const Villager := preload("res://addons/bot_kit/examples/turn_based/villager.gd")

## With this much wood it wants no more.
@export var enough_wood := 8


func _score(context: Variant) -> float:
	var villager := context as Villager
	if villager.energy < Villager.GATHER_ENERGY:
		return 0.0
	return score * (1.0 - float(villager.wood) / enough_wood)
