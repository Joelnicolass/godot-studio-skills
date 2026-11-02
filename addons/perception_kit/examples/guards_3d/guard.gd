extends CharacterBody3D

## A guard of the guards_3d example, the game's side of a PerceptionSensor3D (a game would use its
## own state machine; this one is a match):
## - WATCH: at home, turning its head from side to side;
## - LOOK: it sees someone, and faces them;
## - SEARCH: it saw or heard something it no longer sees, and walks to where it was;
## - HOME: it forgot it, and walks back.

enum State { WATCH, LOOK, SEARCH, HOME }

@export var sensor: PerceptionSensor3D
@export var head: Node3D
@export var speed := 2.5
@export var turn_deg_s := 200.0
## How far its head turns from side to side while watching.
@export var watch_deg := 50.0

var state := State.WATCH

@onready var _home := global_position
@onready var _home_yaw := rotation.y
var _clock := 0.0


func _ready() -> void:
	sensor.forgotten.connect(_on_forgotten)


func _physics_process(delta: float) -> void:
	_clock += delta
	var latest := sensor.latest()
	if sensor.sees_any():
		state = State.LOOK
	elif latest != null:
		state = State.SEARCH
	elif state != State.WATCH:
		state = State.HOME
	match state:
		State.WATCH:
			_turn_head(sin(_clock * 0.8) * deg_to_rad(watch_deg), delta)
		State.LOOK:
			velocity = Vector3.ZERO
			_face(latest.position, delta)
			_turn_head(0.0, delta)
		State.SEARCH:
			_walk_to(latest.position, delta)
		State.HOME:
			if _walk_to(_home, delta):
				rotation.y = rotate_toward(rotation.y, _home_yaw, deg_to_rad(turn_deg_s) * delta)
				if is_equal_approx(rotation.y, _home_yaw):
					state = State.WATCH
	move_and_slide()


func state_name() -> String:
	return State.keys()[state]


func _on_forgotten(_stimulus: PerceptionStimulus) -> void:
	if not sensor.is_aware():
		state = State.HOME


## Walks toward `point` (on the ground); true once there.
func _walk_to(point: Vector3, delta: float) -> bool:
	var to := point - global_position
	to.y = 0.0
	if to.length() < 0.6:
		velocity = Vector3.ZERO
		return true
	velocity = to.normalized() * speed
	_face(point, delta)
	_turn_head(0.0, delta)
	return false


func _face(point: Vector3, delta: float) -> void:
	var to := point - global_position
	if Vector2(to.x, to.z).length_squared() < 0.01:
		return
	rotation.y = rotate_toward(rotation.y, atan2(-to.x, -to.z), deg_to_rad(turn_deg_s) * delta)


func _turn_head(yaw: float, delta: float) -> void:
	head.rotation.y = rotate_toward(head.rotation.y, yaw, deg_to_rad(turn_deg_s) * delta)
