extends Node

## Informal MP kit autoload. ENet + slots + session RPCs. No game rules.
## Dedicated server later: replace this Node; keep domain and pawn submit_* RPCs.

signal peer_joined(peer_id: int, slot: int)
signal peer_left(peer_id: int, slot: int)
signal join_failed
signal server_lost
signal client_world_ready(peer_id: int)
signal load_world
signal snapshot_received(data: Dictionary)
signal session_ended(data: Dictionary)
signal slot_assigned(slot: int)

var port: int = 7777
var max_players: int = 2
var ids: MpIds = MpIds.new()

var _peer: ENetMultiplayerPeer
var _world_ready: Dictionary = {}


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func configure(p_port: int, p_max_players: int, host_slot: int = 1) -> void:
	port = p_port
	max_players = p_max_players
	ids.max_players = p_max_players
	ids.host_slot = host_slot


func is_networked() -> bool:
	return _peer != null and multiplayer.multiplayer_peer == _peer


func is_server() -> bool:
	return is_networked() and multiplayer.is_server()


func local_slot() -> int:
	if not is_networked():
		return ids.host_slot
	if multiplayer.is_server():
		return ids.host_slot
	if ids.local_slot != 0:
		return ids.local_slot
	return ids.host_slot + 1


func peer_id_for(slot: int) -> int:
	return ids.peer_id_for(slot)


func slot_for_peer(peer_id: int) -> int:
	return ids.slot_for_peer(peer_id)


func exceeds_max_players(player_count: int) -> bool:
	return player_count > max_players


func is_peer_world_ready(peer_id: int) -> bool:
	return bool(_world_ready.get(peer_id, false))


func host() -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, max_players)
	if err != OK:
		return err
	_peer = peer
	multiplayer.multiplayer_peer = peer
	ids.reset_host()
	_world_ready.clear()
	return OK


func join(address: String) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	_peer = peer
	multiplayer.multiplayer_peer = peer
	ids.reset_offline()
	ids.local_slot = 0
	_world_ready.clear()
	return OK


func leave() -> void:
	_world_ready.clear()
	ids.reset_offline()
	if _peer == null:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		return
	var closing := _peer
	_peer = null
	closing.close()
	if multiplayer.multiplayer_peer == closing:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func request_world_ready() -> void:
	if not is_networked() or multiplayer.is_server():
		return
	rpc_world_ready.rpc_id(1)


func push_snapshot(data: Dictionary) -> void:
	if not is_server():
		return
	rpc_snapshot.rpc(data)


func push_snapshot_to(peer_id: int, data: Dictionary) -> void:
	if not is_server():
		return
	rpc_snapshot.rpc_id(peer_id, data)


func broadcast_load_world() -> void:
	if not is_server():
		return
	rpc_load_world.rpc()


func load_world_to(peer_id: int) -> void:
	if not is_server():
		return
	rpc_load_world.rpc_id(peer_id)


func broadcast_session_ended(data: Dictionary) -> void:
	if not is_server():
		return
	rpc_session_ended.rpc(data)


func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	var player_count := 1 + multiplayer.get_peers().size()
	if exceeds_max_players(player_count):
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	var slot := ids.assign_client(id)
	if slot == 0:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	rpc_assign_slot.rpc_id(id, slot)
	peer_joined.emit(id, slot)


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	_world_ready.erase(id)
	var slot := ids.unbind_peer(id)
	peer_left.emit(id, slot)


func _on_connection_failed() -> void:
	leave()
	join_failed.emit()


func _on_server_disconnected() -> void:
	if _peer == null:
		return
	leave()
	server_lost.emit()


@rpc("authority", "call_remote", "reliable")
func rpc_assign_slot(slot: int) -> void:
	ids.local_slot = slot
	ids.bind(slot, multiplayer.get_unique_id())
	slot_assigned.emit(slot)


@rpc("authority", "call_remote", "reliable")
func rpc_load_world() -> void:
	load_world.emit()


@rpc("any_peer", "call_remote", "reliable")
func rpc_world_ready() -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	ids.assign_client(sender)
	_world_ready[sender] = true
	client_world_ready.emit(sender)


@rpc("authority", "call_remote", "reliable")
func rpc_snapshot(data: Dictionary) -> void:
	snapshot_received.emit(data)


@rpc("authority", "call_remote", "reliable")
func rpc_session_ended(data: Dictionary) -> void:
	session_ended.emit(data)
