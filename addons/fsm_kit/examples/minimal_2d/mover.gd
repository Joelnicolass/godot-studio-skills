extends CharacterBody2D

## FsmKit's minimal example: the actor is a thin container. Its states are the children of States
## (an FsmMachine) and each one does its own part, with its own numbers in its own inspector.
## Arrows: Move. Enter: a hit, which the actor turns into Hurt with the push as the payload.

@onready var states: FsmMachine = $States


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept"):
		hit(Vector2.UP)


## A hit from the game (a hitbox, a trap). The owner's transition changes the state now; the push
## travels as the payload, which the kit never reads.
func hit(push: Vector2) -> void:
	states.transition(&"Hurt", push)
