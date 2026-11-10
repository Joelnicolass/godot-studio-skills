extends BotMode

## The arena's own behaviour, a BotMode child of each Bot3D: hurt below `below`, the bot runs to the nearest health it
## can take (it wants 2, more than its fight's 1); with none out, it fights on.

## It flees under this much health.
@export var below := 35.0

var _health: Node3D


func _want(bot: Bot3D) -> float:
	if float(bot.body.get(&"health")) >= below:
		return 0.0
	_health = _nearest_health(bot)
	return 2.0 if _health != null else 0.0


func _tick(bot: Bot3D, delta: float) -> void:
	if _health != null and _health.visible:
		bot.walk_to(_health.global_position, delta)


func _nearest_health(bot: Bot3D) -> Node3D:
	var best: Node3D = null
	for node in bot.get_tree().get_nodes_in_group(&"arena_health"):
		var pickup := node as Node3D
		if pickup.visible and (best == null or bot.flat_distance_to(pickup.global_position) < bot.flat_distance_to(best.global_position)):
			best = pickup
	return best
