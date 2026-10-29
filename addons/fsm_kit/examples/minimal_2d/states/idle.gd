extends FsmState

## Stands still until an arrow is held.


func physics_update(_delta: float) -> void:
	if Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down") != Vector2.ZERO:
		transition(&"Move")
