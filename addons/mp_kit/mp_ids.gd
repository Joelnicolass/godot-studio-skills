class_name MpIds
extends RefCounted

## Logical player slots vs ENet peer ids.
## Slot 1 is the listen-server player (peer 1). Clients occupy 2..max_players.
## Disconnect clears the peer but keeps the slot so a rejoin can bind again.

var max_players: int = 2
var host_slot: int = 1
var local_slot: int = 1

var _peer_of_slot: Dictionary = {}
var _slot_of_peer: Dictionary = {}


func reset_host() -> void:
	_peer_of_slot.clear()
	_slot_of_peer.clear()
	local_slot = host_slot
	bind(host_slot, 1)


func reset_offline() -> void:
	_peer_of_slot.clear()
	_slot_of_peer.clear()
	local_slot = host_slot


func bind(slot: int, peer_id: int) -> void:
	_peer_of_slot[slot] = peer_id
	_slot_of_peer[peer_id] = slot


func unbind_peer(peer_id: int) -> int:
	var slot := int(_slot_of_peer.get(peer_id, 0))
	_slot_of_peer.erase(peer_id)
	if slot != 0:
		_peer_of_slot[slot] = 0
	return slot


func assign_client(peer_id: int) -> int:
	var existing := int(_slot_of_peer.get(peer_id, 0))
	if existing != 0:
		bind(existing, peer_id)
		return existing
	for slot in range(host_slot + 1, max_players + 1):
		if int(_peer_of_slot.get(slot, 0)) == 0:
			bind(slot, peer_id)
			return slot
	return 0


func peer_id_for(slot: int) -> int:
	if slot == host_slot:
		return 1
	return int(_peer_of_slot.get(slot, 0))


func slot_for_peer(peer_id: int) -> int:
	return int(_slot_of_peer.get(peer_id, 0))
