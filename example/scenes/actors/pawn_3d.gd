extends CharacterBody3D

@export var player_slot: int = 1
@export var look: ActorLook:
	set(value):
		look = value
		if is_node_ready():
			_apply_look()

@onready var _visual: MeshInstance3D = %Visual
@onready var _badge: Label3D = %Badge
@onready var _pipe: MpCustomPipe = %MpCustomPipe

const LOOK_PATHS: Array[String] = [
	"res://resources/looks/look_a.tres",
	"res://resources/looks/look_b.tres",
	"res://resources/looks/look_c.tres",
	"res://resources/looks/look_d.tres",
]

var _speed: float = 6.0


func _ready() -> void:
	if name.begins_with("Pawn_"):
		var parsed := int(name.get_slice("_", 1))
		if parsed > 0:
			player_slot = parsed
	if look == null:
		look = load(LOOK_PATHS[(maxi(player_slot, 1) - 1) % LOOK_PATHS.size()]) as ActorLook
	_apply_look()
	_pipe.packet.connect(_on_emote_packet)
	if get_tree().current_scene == self:
		_standalone_preview()


func _apply_look() -> void:
	var tint := Color(0.35, 0.65, 1, 1)
	if look != null:
		_badge.text = look.badge
		_speed = look.move_speed * 0.04
		tint = look.tint
	else:
		_badge.text = str(player_slot)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	_visual.material_override = mat


func try_move(dir: Vector2) -> void:
	if MpAuthority.should_send_command():
		submit_move.rpc_id(1, dir)
	else:
		apply_move(dir)


@rpc("any_peer", "call_remote", "reliable")
func submit_move(dir: Vector2) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != MpKit.peer_id_for(player_slot):
		return
	apply_move(dir)


func apply_move(dir: Vector2) -> void:
	var wish := Vector3(dir.x, 0.0, dir.y).limit_length(1.0) * _speed
	velocity.x = wish.x
	velocity.z = wish.z
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
	else:
		var g := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
		velocity.y -= g * get_physics_process_delta_time()
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
	var mat := _visual.material_override as StandardMaterial3D
	if mat == null:
		return
	var base := mat.albedo_color
	tween.tween_property(mat, "albedo_color", Color.WHITE, 0.08)
	tween.tween_property(mat, "albedo_color", base, 0.2)


func _standalone_preview() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 4.0, 8.0)
	add_child(cam)
	cam.look_at(Vector3.ZERO)
	var floor_body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(12.0, 0.2, 12.0)
	col.shape = box
	col.position = Vector3(0.0, -0.7, 0.0)
	floor_body.add_child(col)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(12.0, 0.2, 12.0)
	mesh.mesh = bm
	mesh.position = Vector3(0.0, -0.7, 0.0)
	floor_body.add_child(mesh)
	add_child(floor_body)
