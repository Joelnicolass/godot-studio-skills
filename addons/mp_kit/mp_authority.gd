class_name MpAuthority
extends RefCounted

const SERVER_PEER: int = 1


static func claim_server(node: Node) -> void:
	node.set_multiplayer_authority(SERVER_PEER)


static func freeze_rigid_proxy(body: Node) -> void:
	if body.is_multiplayer_authority():
		return
	if body is RigidBody2D:
		var body_2d := body as RigidBody2D
		body_2d.freeze = true
		body_2d.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	elif body is RigidBody3D:
		var body_3d := body as RigidBody3D
		body_3d.freeze = true
		body_3d.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC


static func should_send_command() -> bool:
	return MpKit.is_networked() and not MpKit.is_server()


## Call from submit_* RPCs: `if not MpAuthority.accept_command(self, player_slot): return`
static func accept_command(node: Node, player_slot: int) -> bool:
	if node == null or not MpKit.is_networked():
		return false
	if not node.multiplayer.is_server():
		return false
	return node.multiplayer.get_remote_sender_id() == MpKit.peer_id_for(player_slot)


## Call from room-scoped submit_* RPCs: server + sender == peer seated at (room_id, seat).
static func accept_room_command(node: Node, room_id: StringName, seat: int) -> bool:
	if node == null or not MpKit.is_networked():
		return false
	if not node.multiplayer.is_server():
		return false
	if MpKit.rooms == null:
		return false
	return node.multiplayer.get_remote_sender_id() == MpKit.rooms.peer_for_seat(room_id, seat)


static func ensure_sync(node: Node, properties: PackedStringArray) -> MultiplayerSynchronizer:
	if node.has_node("MultiplayerSynchronizer"):
		return node.get_node("MultiplayerSynchronizer") as MultiplayerSynchronizer
	var sync := MultiplayerSynchronizer.new()
	sync.name = "MultiplayerSynchronizer"
	var cfg := SceneReplicationConfig.new()
	for property in properties:
		cfg.add_property(NodePath(property))
	sync.replication_config = cfg
	node.add_child(sync)
	return sync
