extends CharacterBody2D

## Your player. Movement goes in mp_move: the server runs it and, with MpActor > Prediction on, the owner runs it at
## once too (no lag). The rules go in _physics_process behind net.is_authority().
## Calls by name: net.to_server(&"x") runs mp_sv_x on the server; net.to_all(&"x") runs mp_all_x everywhere.

const SPEED := 220.0

@onready var net: MpActor = $MpActor
@onready var input: MpInput = $MpInput


func mp_move(keys: MpInput, _delta: float) -> void:
	var dir := keys.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	velocity = dir * SPEED
	move_and_slide()


func _physics_process(_delta: float) -> void:
	if not net.is_authority():
		return
	if input.is_action_just_pressed(&"ui_accept"):
		MpState.of(self).add(StringName("p%d" % net.owner_slot))
		net.to_all(&"flash")


func mp_all_flash() -> void:
	$Visual.scale = Vector2(1.4, 1.4)
	create_tween().tween_property($Visual, "scale", Vector2(1, 1), 0.2)
