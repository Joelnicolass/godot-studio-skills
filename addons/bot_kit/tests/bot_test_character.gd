extends CharacterBody3D

## A character for the tests, written like a game's: it walks, jumps and fires from `input` (its bot's), the way a
## person's character reads `Input`. It counts what it did.

const SPEED := 5.0
const JUMP_SPEED := 4.5
const GRAVITY := 9.8

var input: BotInput
## Physics frames with fire held, presses of fire, jumps.
var fired_frames := 0
var shots := 0
var jumps := 0
## Off: it stands (a dummy target).
var walks := true


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	velocity.x = 0.0
	velocity.z = 0.0
	if input != null:
		if input.is_action_pressed(&"fire"):
			fired_frames += 1
		if input.is_action_just_pressed(&"fire"):
			shots += 1
	if input != null and walks:
		if input.is_action_just_pressed(&"ui_accept") and is_on_floor():
			velocity.y = JUMP_SPEED
			jumps += 1
		var keys := input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
		var direction := transform.basis * Vector3(keys.x, 0.0, keys.y)
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	move_and_slide()
