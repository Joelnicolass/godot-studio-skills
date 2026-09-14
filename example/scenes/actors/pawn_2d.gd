extends CharacterBody2D

@export var player_slot: int = 1
@export var look: ActorLook:
	set(value):
		look = value
		if is_node_ready():
			_apply_look()

@onready var _visual: Sprite2D = %Visual
@onready var _badge: Label = %Badge
@onready var _pipe: MpCustomPipe = %MpCustomPipe

const LOOK_PATHS: Array[String] = [
	"res://resources/looks/look_a.tres",
	"res://resources/looks/look_b.tres",
	"res://resources/looks/look_c.tres",
	"res://resources/looks/look_d.tres",
]

var _speed: float = 180.0


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	if name.begins_with("Pawn_"):
		var parsed := int(name.get_slice("_", 1))
		if parsed > 0:
			player_slot = parsed
	if look == null:
		look = load(LOOK_PATHS[(maxi(player_slot, 1) - 1) % LOOK_PATHS.size()]) as ActorLook
	_apply_look()
	_pipe.packet.connect(_on_emote_packet)


func _apply_look() -> void:
	if look == null:
		return
	_visual.modulate = look.tint
	_badge.text = look.badge
	_speed = look.move_speed


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
	velocity = dir.limit_length(1.0) * _speed
	move_and_slide()


func try_emote() -> void:
	var data := {"slot": player_slot, "msg": DemoCopy.EMOTE_MSG}
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
	var base := _visual.modulate
	tween.tween_property(_visual, "modulate", Color.WHITE, 0.08)
	tween.tween_property(_visual, "modulate", base, 0.2)
