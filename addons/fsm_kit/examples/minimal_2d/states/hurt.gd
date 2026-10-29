extends FsmState

## Knocked back along the push it was given (the machine's payload), then Idle. A second hit while
## hurt arrives as apply_payload(): the same state with a fresh push, no exit and no enter.

## Seconds of knockback.
@export var duration := 0.35
## Pixels per second at the start of the knockback; it slows to zero.
@export var push_speed := 420.0
@export var tint := Color(1.0, 0.45, 0.45)

var _left := 0.0
var _push := Vector2.ZERO


func enter() -> void:
	super()
	(actor as CanvasItem).modulate = tint
	_start(machine.payload)


func exit() -> void:
	(actor as CanvasItem).modulate = Color.WHITE
	super()


func apply_payload(next_payload: Variant) -> void:
	_start(next_payload)


func physics_update(delta: float) -> void:
	var body := actor as CharacterBody2D
	body.velocity = _push * push_speed * (_left / duration)
	body.move_and_slide()
	_left -= delta
	if _left <= 0.0:
		transition(&"Idle")


func _start(push: Variant) -> void:
	_push = (push as Vector2).normalized() if push is Vector2 else Vector2.ZERO
	_left = duration
