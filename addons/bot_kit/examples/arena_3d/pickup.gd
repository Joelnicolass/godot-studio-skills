extends Area3D

## A pickup: health or grenades. Its BotGoal3D child makes it a place worth walking to, for a fighter that wants it
## (`wanted`); taken, it hides (its goal with it) and comes back after RESPAWN_S.

const Fighter := preload("res://addons/bot_kit/examples/arena_3d/fighter.gd")

enum Kind { HEALTH, GRENADES }

const RESPAWN_S := 8.0

@export var kind := Kind.HEALTH

@export var goal: BotGoal3D


func _ready() -> void:
	if kind == Kind.HEALTH:
		add_to_group(&"arena_health")
	goal.wanted = func(bot: Bot3D) -> bool: return _wanted_by(bot.body as Fighter)
	body_entered.connect(_on_body_entered)


func _wanted_by(fighter: Fighter) -> bool:
	if kind == Kind.HEALTH:
		return fighter.health < 80.0
	return fighter.grenades < 3


func _on_body_entered(body: Node) -> void:
	var fighter := body as Fighter
	if not visible or fighter == null or not _wanted_by(fighter):
		return
	if kind == Kind.HEALTH:
		fighter.heal(50.0)
	else:
		fighter.grenades += 2
	hide()
	set_deferred(&"monitoring", false)
	await get_tree().create_timer(RESPAWN_S, false).timeout
	show()
	monitoring = true
