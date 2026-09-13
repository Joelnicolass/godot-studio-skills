# Game glue (what you write)

The kit is not your game. Minimum two pieces (autoloads or a single `NetGlue.gd` on a small title):

1. **Flow** — listens to `load_world`, `snapshot_received`, `session_ended`, `server_lost`. Changes scenes.
2. **Lobby / policy** — `host()`/`join()`, when the round starts, spawn handshake.

Clean: `GameSession` + `SceneDirector`. Standard: a `Match` node in the world (or one glue). The kit does not change.

Suggested autoload order: `MpKit` → (session if Clean) → flow → net glue.

## Configure

```gdscript
func _ready() -> void:
	MpKit.configure(7777, 2, 1)
	MpKit.peer_joined.connect(_on_peer_joined)
	MpKit.peer_left.connect(_on_peer_left)
	MpKit.client_world_ready.connect(_on_client_world_ready)
	MpKit.join_failed.connect(_on_join_failed)
```

Play solo: `MpKit.leave()` (goes offline) and load the world **without** `host()`.

Host lobby: `"%s:%d" % [MpLan.get_local_ipv4(), port]`. Validate IP before `join`.

## Start policy (product, not kit)

A valid policy: start when the 2nd peer connects. A shooter may wait for “ready”. That lives in glue.

```gdscript
func _on_peer_joined(peer_id: int, slot: int) -> void:
	if game_session.is_running:
		MpKit.push_snapshot_to(peer_id, game_session.to_snapshot())
		MpKit.load_world_to(peer_id)
		return
	game_session.start([1, 2])  # or 1..N
	MpKit.push_snapshot_to(peer_id, game_session.to_snapshot())
	MpKit.broadcast_load_world()
	flow.goto_world()  # host does not receive rpc_load_world
```

## Flow

```gdscript
func _ready() -> void:
	game_session.finished.connect(_on_finished)
	MpKit.load_world.connect(goto_world)
	MpKit.snapshot_received.connect(game_session.apply_snapshot)
	MpKit.session_ended.connect(_on_remote_ended)
	MpKit.server_lost.connect(_on_server_lost)
```

On host end: `broadcast_session_ended` + go to results.  
`apply_snapshot` on client: `set_process(false)` on the session.

## World (`_ready`)

```gdscript
func _ready() -> void:
	$PawnSpawner.add_spawnable_scene("res://pawns/pawn.tscn")
	# local FX here (client too)

	if not MpKit.is_networked():
		_spawn_world()
		game_session.start([MpKit.local_slot()])
		return

	if not MpKit.is_server():
		MpKit.request_world_ready()
		return

	# Host: spawn in _on_client_world_ready, not here
```

`add_child(node, true)` — stable name for the spawner.

Rejoin with a live world: `remove_child` + `add_child(..., true)` to resend spawn.

## Disconnect (define product)

| Signal | The kit | You |
|--------|--------|-----|
| `peer_left` | Clears mapping | Keep 1P? Pause? Mark absent? |
| `server_lost` | Already `leave()` | Notice + menu |
| `join_failed` | Nothing else | Notice + menu |

A valid policy: guest drop does not pause the timer and leaves the pawn absent. Another genre may pause. Do not put that in the kit.

## Pawns

In `_ready` of the replicated actor:

```gdscript
MpAuthority.claim_server(self)
MpAuthority.ensure_sync(self, PackedStringArray([".:position", ".:rotation", ".:visible"]))
MpAuthority.freeze_rigid_proxy(self)
```

Compose trail/FSM/FX as children. Networking does not justify a monolithic pawn.

## Periodic snapshot

A node of yours in the world, host only, 2–10 Hz:

```gdscript
if MpKit.is_server() and game_session.is_running:
	MpKit.push_snapshot(game_session.to_snapshot())
```
