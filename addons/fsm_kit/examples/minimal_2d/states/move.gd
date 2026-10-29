extends FsmState

## Walks with the arrows. Back to Idle when they are released.

## Pixels per second.
@export var speed := 220.0


func physics_update(_delta: float) -> void:
	var wish := Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	if wish == Vector2.ZERO:
		transition(&"Idle")
		return
	var body := actor as CharacterBody2D
	body.velocity = wish * speed
	body.move_and_slide()
