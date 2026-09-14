extends Node

## Reads InputMap and asks the pawn. Does not spawn or score.

@export var body: Node


func _ready() -> void:
	if body == null:
		body = get_parent()


func _physics_process(_delta: float) -> void:
	if body == null or not body.has_method("try_move"):
		return
	if not _is_local_driver():
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	body.try_move(dir)


func _unhandled_input(event: InputEvent) -> void:
	if body == null or not body.has_method("try_emote"):
		return
	if not _is_local_driver():
		return
	if event.is_action_pressed("emote"):
		body.try_emote()
		get_viewport().set_input_as_handled()


func _is_local_driver() -> bool:
	if MpKit.local_slot() == 0:
		return false
	if not ("player_slot" in body):
		return true
	return int(body.player_slot) == MpKit.local_slot()
