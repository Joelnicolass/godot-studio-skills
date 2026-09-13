# Examples — MpKit (genéricos)

Nada de un título concreto. El kit no nombra estas clases.

## RPC de intención en el actor

```gdscript
@rpc("any_peer", "call_remote", "reliable")
func submit_action(dir: Vector2, strength: float) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != MpKit.peer_id_for(player_slot):
		return
	apply_action(dir, strength)


func try_action(dir: Vector2, strength: float) -> void:
	if MpAuthority.should_send_command():
		submit_action.rpc_id(1, dir, strength)
	else:
		apply_action(dir, strength)
```

## Glue: arranque al segundo peer

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

## Snapshot periódico (solo host, 2–10 Hz)

```gdscript
func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = 0.2
	timer.timeout.connect(_push_if_host)
	add_child(timer)
	timer.start()


func _push_if_host() -> void:
	if not MpKit.is_server() or not game_session.is_running:
		return
	MpKit.push_snapshot(game_session.to_snapshot())
```
