extends CharacterBody3D

## You: the arrows walk you (the same template as the robot, reading `Input`). You are in the group `bot_target`, so
## the robot hunts you.

const SPEED := 5.0


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	var keys := Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	velocity.x = keys.x * SPEED
	velocity.z = keys.y * SPEED
	move_and_slide()
