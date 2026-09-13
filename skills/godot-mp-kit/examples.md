# Examples — MpKit (generic)

No specific title. The kit does not name these classes.

## Intent RPC on the pawn

```gdscript
@rpc("any_peer", "call_remote", "reliable")
func submit_impulse(dir: Vector2, force: float) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != MpKit.peer_id_for(player_slot):
		return
	apply_impulse(dir, force)


func try_impulse(dir: Vector2, force: float) -> void:
	if MpAuthority.should_send_command():
		submit_impulse.rpc_id(1, dir, force)
	else:
		apply_impulse(dir, force)
```

## Glue: start on second peer

```gdscript
func _on_peer_joined(peer_id: int, slot: int) -> void:
	if game_session.is_running:
		MpKit.push_snapshot_to(peer_id, game_session.to_snapshot())
		MpKit.load_world_to(peer_id)
		return
	game_session.start([1, 2])
	MpKit.push_snapshot_to(peer_id, game_session.to_snapshot())
	MpKit.broadcast_load_world()
	flow.goto_world()
```

## Periodic snapshot (host only)

```gdscript
func _process(_delta: float) -> void:
	if not MpKit.is_server() or not game_session.is_running:
		return
	MpKit.push_snapshot(game_session.to_snapshot())
```
