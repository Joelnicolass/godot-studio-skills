extends CharacterBody3D

## A fighter of the arena, played by its Bot3D: it walks, jumps and fires from `bot.input` (a person's would read
## `Input`), and switches weapon when the bot asks (`weapon_changed`). A rifle while fire is held; a grenade on each
## press, while it has some. It dies, and comes back somewhere else.

signal died(fighter: Node, by: Node)

const SPEED := 5.0
const JUMP_VELOCITY := 4.5
const MAX_HEALTH := 100.0
const RIFLE_EVERY_S := 0.12
const RIFLE_DAMAGE := 9.0
const GRENADE_SPEED := 13.0
const RESPAWN_S := 3.0
const Grenade := preload("res://addons/bot_kit/examples/arena_3d/grenade.gd")

@onready var bot: Bot3D = $Bot3D
@onready var head: Node3D = $Head

var health := MAX_HEALTH
var grenades := 2
var kills := 0
var dead := false
var weapon_name := &"rifle"
var _cooldown_s := 0.0
var _spawn := Vector3.ZERO


func _ready() -> void:
	_spawn = global_position
	bot.weapon_changed.connect(func(weapon: BotWeapon) -> void: weapon_name = weapon.name)
	# The game's own rule on a weapon: no grenade left, no grenade.
	bot.weapon_score = func(weapon: BotWeapon, _distance: float, score: float) -> float:
		return 0.0 if weapon.name == &"grenade" and grenades <= 0 else score


func _physics_process(delta: float) -> void:
	if dead:
		return
	var input := bot.input
	if not is_on_floor():
		velocity += get_gravity() * delta
	if input.is_action_just_pressed(&"ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	var keys := input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	var direction := transform.basis * Vector3(keys.x, 0.0, keys.y)
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED
	move_and_slide()
	_cooldown_s -= delta
	if weapon_name == &"grenade":
		if input.is_action_just_pressed(&"fire") and grenades > 0:
			grenades -= 1
			_throw()
	elif input.is_action_pressed(&"fire") and _cooldown_s <= 0.0:
		_cooldown_s = RIFLE_EVERY_S
		_shoot()


func hurt(damage: float, by: Node) -> void:
	if dead:
		return
	health -= damage
	if health <= 0.0:
		_die(by)


func heal(amount: float) -> void:
	health = minf(health + amount, MAX_HEALTH)


func _shoot() -> void:
	var from := head.global_position
	var to := from - head.global_basis.z * 40.0
	var query := PhysicsRayQueryParameters3D.create(from, to, 0b11, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var other := hit.get("collider") as Node
	if other != null and other.has_method(&"hurt"):
		other.call(&"hurt", RIFLE_DAMAGE, self)
	get_parent().call(&"tracer", from, hit.get("position", to))


func _throw() -> void:
	var grenade := Grenade.new()
	grenade.thrower = self
	grenade.velocity = -head.global_basis.z * GRENADE_SPEED
	get_parent().add_child(grenade)
	grenade.global_position = head.global_position


func _die(by: Node) -> void:
	dead = true
	bot.enabled = false
	remove_from_group(&"bot_target")
	hide()
	$Shape.set_deferred(&"disabled", true)
	died.emit(self, by)
	await get_tree().create_timer(RESPAWN_S, false).timeout
	global_position = _spawn
	velocity = Vector3.ZERO
	health = MAX_HEALTH
	grenades = 2
	$Shape.set_deferred(&"disabled", false)
	show()
	add_to_group(&"bot_target")
	dead = false
	bot.enabled = true
