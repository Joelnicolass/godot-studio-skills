@tool
extends CharacterBody2D

## Optional: a type for this pawn. Empty = the catalog picks one by player_slot.
@export var type: PawnType:
	set(value):
		type = value
		_apply_type()
## The types by slot. Required when `type` is empty.
@export var catalog: PawnCatalog
@export var player_slot: int = 1

@onready var _visual: Sprite2D = %Visual
@onready var _badge: Label = %Badge
@onready var _pipe: MpCustomPipe = %MpCustomPipe

var _type: PawnType


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	motion_mode = MOTION_MODE_FLOATING
	if name.begins_with("Pawn_"):
		var parsed := int(name.get_slice("_", 1))
		if parsed > 0:
			player_slot = parsed
	_apply_type()
	_pipe.packet.connect(_on_emote_packet)


func _get_configuration_warnings() -> PackedStringArray:
	if type == null and catalog == null:
		return PackedStringArray(["Assign a PawnType (type) or a PawnCatalog (catalog)."])
	return PackedStringArray()


func _apply_type() -> void:
	if not is_node_ready() or Engine.is_editor_hint():
		return
	_type = type if type != null else (catalog.type_for_slot(player_slot) if catalog != null else null)
	if _type == null:
		push_error("Pawn2D '%s': assign type or catalog." % name)
		return
	_visual.modulate = _type.tint
	_badge.text = _type.badge


func try_move(dir: Vector2) -> void:
	if MpAuthority.should_send_command():
		submit_move.rpc_id(1, dir)
	else:
		apply_move(dir)


@rpc("any_peer", "call_remote", "reliable")
func submit_move(dir: Vector2) -> void:
	if not MpAuthority.accept_command(self, player_slot):
		return
	apply_move(dir)


func apply_move(dir: Vector2) -> void:
	velocity = dir.limit_length(1.0) * _type.speed_2d_px_s
	move_and_slide()


func try_emote() -> void:
	var data := {"slot": player_slot, "msg": tr("EMOTE_MSG")}
	if not MpKit.is_networked() or not MpKit.is_server():
		_pipe.send(data)
		return
	_pipe.broadcast(data)


func _on_emote_packet(data: Dictionary, from_peer: int) -> void:
	if int(data.get("slot", 0)) != player_slot:
		return
	if MpKit.is_networked() and MpKit.is_server() and from_peer != 1:
		return
	_flash()


func _flash() -> void:
	var tween := create_tween()
	tween.tween_property(_visual, "modulate", Color.WHITE, _type.flash_in_s)
	tween.tween_property(_visual, "modulate", _type.tint, _type.flash_out_s)
