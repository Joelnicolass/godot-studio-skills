@tool
extends Node

## Reads InputMap and asks the pawn. Does not spawn or score.

## Required: the pawn it drives (needs try_move and try_emote).
@export var body: Node


func _get_configuration_warnings() -> PackedStringArray:
	if body == null:
		return PackedStringArray(["Assign body (the pawn this input drives)."])
	return PackedStringArray()


func _ready() -> void:
	if body == null and not Engine.is_editor_hint():
		push_error("PawnInput '%s': assign body." % name)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or body == null or not body.has_method("try_move"):
		return
	if not _is_local_driver():
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	body.try_move(dir)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or body == null or not body.has_method("try_emote"):
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
