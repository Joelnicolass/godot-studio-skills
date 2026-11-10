extends Area3D

## A pickup: health or grenades. Its BotGoal3D child makes it a place worth walking to, for a fighter that wants it
## (`wanted`); taken, it hides (its goal with it) and comes back after RESPAWN_S.

enum Kind { HEALTH, GRENADES }

const RESPAWN_S := 8.0

@export var kind := Kind.HEALTH

@onready var goal: BotGoal3D = $BotGoal3D


func _ready() -> void:
	if kind == Kind.HEALTH:
		add_to_group(&"arena_health")
	goal.wanted = func(bot: Bot3D) -> bool: return _wanted_by(bot.body)
	body_entered.connect(_on_body_entered)


func _wanted_by(fighter: Node) -> bool:
	if kind == Kind.HEALTH:
		return float(fighter.get(&"health")) < 80.0
	return int(fighter.get(&"grenades")) < 3


func _on_body_entered(body: Node) -> void:
	if not visible or not body.has_method(&"heal") or not _wanted_by(body):
		return
	if kind == Kind.HEALTH:
		body.call(&"heal", 50.0)
	else:
		body.set(&"grenades", int(body.get(&"grenades")) + 2)
	hide()
	set_deferred(&"monitoring", false)
	await get_tree().create_timer(RESPAWN_S, false).timeout
	show()
	monitoring = true
