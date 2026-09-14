class_name MpSpawner
extends MultiplayerSpawner

## Native MultiplayerSpawner + world_ready gating via synchronizer visibility.
##
## Problem: Godot sends spawn packets on peer_connected, while the guest is
## still on the lobby scene → "spawner is null" errors and the spawn is lost.
## Engine mechanism: a MultiplayerSpawner only sends spawn (and starts sync)
## to a peer once that node's MultiplayerSynchronizer is visible to it.
##
## Server: actors under spawn_path start hidden; each peer is revealed on
## MpKit.client_world_ready. Client: this node requests world_ready (deferred).
## No extra MpWorldReady node is required.

@export var extra_scenes: Array[PackedScene] = []
## Hold spawn/sync per peer until MpKit.client_world_ready (server only).
## Turn off only if every peer already has this scene when actors are added
## (no lobby → match change_scene).
@export var hold_until_world_ready: bool = true

var _root: Node


func _ready() -> void:
	for scene in extra_scenes:
		if scene == null:
			continue
		var path := scene.resource_path
		if path.is_empty():
			continue
		add_spawnable_scene(path)

	if spawn_path.is_empty() or spawn_path == NodePath("."):
		push_warning("MpSpawner '%s': set spawn_path to the parent of replicated actors" % name)
		return

	_root = get_node_or_null(spawn_path)
	if _root == null:
		push_warning("MpSpawner '%s': spawn_path does not resolve" % name)
		return

	if not MpKit.is_networked():
		return

	if not MpKit.is_server():
		call_deferred("_request_world_ready")
		return

	if not hold_until_world_ready:
		return

	for child in _root.get_children():
		_hold(child)
	_root.child_entered_tree.connect(_on_child_entered)
	MpKit.client_world_ready.connect(_on_client_world_ready)
	MpKit.peer_left.connect(_on_peer_left)


func _exit_tree() -> void:
	if MpKit.client_world_ready.is_connected(_on_client_world_ready):
		MpKit.client_world_ready.disconnect(_on_client_world_ready)
	if MpKit.peer_left.is_connected(_on_peer_left):
		MpKit.peer_left.disconnect(_on_peer_left)


func _request_world_ready() -> void:
	if not is_inside_tree():
		return
	if not MpKit.is_networked() or MpKit.is_server():
		return
	MpKit.request_world_ready()


func _on_child_entered(node: Node) -> void:
	if node.get_parent() != _root:
		return
	_hold(node)


## Hidden by default; already-ready peers are revealed immediately.
## Runs before the deferred spawn flush, so the engine never sends the spawn
## to a peer that is still on the lobby.
func _hold(node: Node) -> void:
	for sync in _syncs_in(node):
		sync.public_visibility = false
		for peer in multiplayer.get_peers():
			if MpKit.is_peer_world_ready(peer):
				sync.set_visibility_for(peer, true)


func _on_client_world_ready(peer_id: int) -> void:
	if _root == null:
		return
	for child in _root.get_children():
		for sync in _syncs_in(child):
			sync.set_visibility_for(peer_id, true)


func _on_peer_left(peer_id: int, _slot: int) -> void:
	if _root == null or not is_inside_tree():
		return
	for child in _root.get_children():
		for sync in _syncs_in(child):
			sync.set_visibility_for(peer_id, false)


func _syncs_in(node: Node) -> Array[MultiplayerSynchronizer]:
	var out: Array[MultiplayerSynchronizer] = []
	_collect_syncs(node, out)
	return out


func _collect_syncs(node: Node, out: Array[MultiplayerSynchronizer]) -> void:
	if node is MultiplayerSynchronizer:
		out.append(node as MultiplayerSynchronizer)
	for child in node.get_children():
		_collect_syncs(child, out)
