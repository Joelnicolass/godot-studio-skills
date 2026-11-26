extends BotOption

## Rest: `score` when it has no energy left, nothing when it is full.

const Villager := preload("res://addons/bot_kit/examples/turn_based/villager.gd")


func _score(context: Variant) -> float:
	var villager := context as Villager
	return score * (1.0 - float(villager.energy) / Villager.MAX_ENERGY)
