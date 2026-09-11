class_name MpAuthority
extends RefCounted

const SERVER_PEER: int = 1


static func claim_server(node: Node) -> void:
	node.set_multiplayer_authority(SERVER_PEER)


static func freeze_rigid_proxy(body: RigidBody2D) -> void:
	if body.is_multiplayer_authority():
		return
	body.freeze = true
	body.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC


static func should_send_command() -> bool:
	return MpKit.is_networked() and not MpKit.is_server()


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
