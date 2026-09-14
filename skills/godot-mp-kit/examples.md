# Examples — MpKit (generic)

Nothing from a concrete title. The kit does not name these classes.

## Intent RPC on the actor

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

## Glue: listen (2nd peer) vs dedicated (N clients)

```gdscript
func _on_peer_joined(peer_id: int, slot: int) -> void:
	if game_session.is_running:
		MpKit.push_snapshot_to(peer_id, game_session.to_snapshot())
		MpKit.load_world_to(peer_id)
		return
	var slots := MpKit.occupied_slots()
	if MpKit.is_dedicated() and slots.size() < 2:
		return
	game_session.start(slots)
	MpKit.push_snapshot_to(peer_id, game_session.to_snapshot())
	MpKit.broadcast_load_world()
	flow.goto_world()
```

## Dedicated boot

```gdscript
if MpBoot.is_dedicated_process():
	MpKit.configure(int(MpBoot.user_value("mp-port", "7777")), 4)
	var err := MpKit.host_dedicated()
	if err != OK:
		get_tree().quit(1)
```

## Periodic snapshot (server only, 2–10 Hz)

```gdscript
func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = 0.2
	timer.timeout.connect(_push_if_server)
	add_child(timer)
	timer.start()


func _push_if_server() -> void:
	if not MpKit.is_server() or not game_session.is_running:
		return
	MpKit.push_snapshot(game_session.to_snapshot())
```

## Dictionary tunnel (does not reflect by itself)

```gdscript
# Client or 1P
MpKit.send_custom(&"emote", {"id": "wave"})
# Listen host / server origin (everyone must see it): broadcast_custom, not send_custom

# Server (glue): reflect client packets only. from_peer == 1 is already a server emit
# (broadcast or local send). Without this check, broadcast_custom calls itself.
func _on_custom(channel: StringName, data: Dictionary, from_peer: int) -> void:
	if channel != &"emote":
		return
	if MpKit.is_server() and from_peer != 1:
		MpKit.broadcast_custom(channel, data)
```

Or a child `MpCustomPipe` with `channel` in the inspector.

## Spawn identity (actor, not kit)

Put `player_slot` (or another id) on the `MultiplayerSynchronizer` with `spawn = true`, like Asteroidcitos’ `player_id`. Stable name (`Pawn_2`) as fallback.

```gdscript
MpAuthority.ensure_sync(self, PackedStringArray([
	".:position",
	".:rotation",
	".:visible",
	".:player_slot",
]))
```

`add_child` under `spawn_path`. `MpSpawner` reveals the actor to the peer on `world_ready` (Godot sends spawn + sync).
