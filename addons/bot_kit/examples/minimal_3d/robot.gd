extends CharacterBody3D

## The bot's character: Godot's CharacterBody3D template, reading `bot.input` where a person's reads `Input`. The
## bot only presses keys; this script walks, jumps and shoots like any player's.

signal shot(from: Vector3, to: Vector3, hit: Object)

const SPEED := 4.0
const JUMP_VELOCITY := 4.5
## Seconds between shots while fire is held.
const FIRE_EVERY_S := 0.15

@onready var bot: Bot3D = $Bot3D
@onready var head: Node3D = $Head

var _cooldown_s := 0.0


func _physics_process(delta: float) -> void:
	var input := bot.input  # a person's character: Input
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
	if input.is_action_pressed(&"fire") and _cooldown_s <= 0.0:
		_cooldown_s = FIRE_EVERY_S
		_shoot()


## A ray from the head, along where it looks.
func _shoot() -> void:
	var from := head.global_position
	var to := from - head.global_basis.z * 40.0
	var query := PhysicsRayQueryParameters3D.create(from, to, 0b11, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	shot.emit(from, hit.get("position", to), hit.get("collider"))
