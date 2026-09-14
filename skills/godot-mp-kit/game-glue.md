# Game glue (what you write)

The kit is not your game. Minimum two pieces (autoloads or a single `NetGlue.gd` on a small title):

1. **Flow** — listens to `load_world`, `snapshot_received`, `session_ended`, `server_lost`. Changes scenes.
2. **Lobby / policy** — `host()` / `host_dedicated()` / `join()`, when the round starts, spawn handshake.

Clean: `GameSession` + `SceneDirector`. Standard: a `Match` node in the world (or one glue). The kit does not change.

Suggested autoload order: `MpKit` → (session if Clean) → flow → net glue.

Dedicated / VPS: [dedicated.md](dedicated.md).

## Configure

```gdscript
func _ready() -> void:
	var port := int(MpBoot.user_value("mp-port", "7777"))
	MpKit.configure(port, 4, 1)
	MpKit.peer_joined.connect(_on_peer_joined)
	MpKit.peer_left.connect(_on_peer_left)
	MpKit.client_world_ready.connect(_on_client_world_ready)
	MpKit.join_failed.connect(_on_join_failed)

	if MpBoot.is_dedicated_process():
		var err := MpKit.host_dedicated()
		if err != OK:
			push_error("dedicated bind failed: %s" % err)
			get_tree().quit(1)
		return
```

Play solo: `MpKit.leave()` (goes offline) and load the world **without** `host()`.

LAN lobby: `"%s:%d" % [MpLan.get_local_ipv4(), port]`. After a successful `host()`: `MpLan.advertise(self, "My room")` on an autoload (the boot scene is destroyed on change_scene). On the menu: `MpLan.browse(self)`. Online: IP field (dev: `127.0.0.1`). Validate IP before `join`.

Shortcut: `MpBootMenu` scene (`drive_kit`, optional `world_scene`). The demo uses its own glue + browse; it does not instance the drop-in.

## Start policy (product, not kit)

Listen: a valid policy is start when the 2nd peer connects (the host is already there). Dedicated: the server starts empty; start on the Nth client or on “ready”.

```gdscript
func _on_peer_joined(peer_id: int, slot: int) -> void:
	if game_session.is_running:
		MpKit.push_snapshot_to(peer_id, game_session.to_snapshot())
		MpKit.load_world_to(peer_id)
		return
	var slots := MpKit.occupied_slots()
	if MpKit.is_dedicated() and slots.size() < 2:
		return  # example: wait for 2 clients
	game_session.start(slots)
	MpKit.push_snapshot_to(peer_id, game_session.to_snapshot())
	MpKit.broadcast_load_world()
	flow.goto_world()  # the server does not receive rpc_load_world
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

On server end: `broadcast_session_ended` + go to results.  
`apply_snapshot` on client: `set_process(false)` on the session.

## World (`_ready`)

Prefer an `MpSlotSpawner` in the scene (`pawn_scene`, `spawn_path`, markers). Then glue **does not** call `ensure_pawn` or `request_world_ready`.

Manual spawn (projectiles, enemies, or a custom pawn):

```gdscript
func _ready() -> void:
	# local FX here (client too)

	if not MpKit.is_networked():
		_spawn_world()
		game_session.start([MpKit.local_slot()])
		return

	if not MpKit.is_server():
		# Only if this scene has no MpSpawner:
		# MpKit.request_world_ready()
		return

	# Listen host: local pawn in _ready. MpSpawner does not send it until world_ready.
	if MpKit.is_listen_host():
		_ensure_pawn(MpKit.local_slot())
```

`add_child(node, true)` — stable name. Set position/slot **before** `add_child`.

```gdscript
func _on_client_world_ready(peer_id: int) -> void:
	_ensure_pawn(MpKit.slot_for_peer(peer_id))
```

Dedicated: **do not** spawn a pawn for `local_slot() == 0`.

`MpSpawner` reveals the actors to the ready peer (native synchronizer visibility). Do not `remove_child` + `add_child` in glue.

## Disconnect (define product)

| Signal | The kit | You |
|--------|--------|-----|
| `peer_left` | Clears mapping | Keep going? Pause? Mark absent? Dedicated with 0 clients: end the round? |
| `server_lost` | Already `leave()` | Notice + menu |
| `join_failed` | Nothing else | Notice + menu |

A valid policy: guest drop does not pause the timer and leaves the pawn absent. Another genre may pause. Do not put that in the kit.

## Pawns

Prefer a child `MpReplicate` (Tools → Wire replication, or the scaffold). Equivalent to:

```gdscript
MpAuthority.claim_server(self)
MpAuthority.ensure_sync(self, PackedStringArray([".:position", ".:rotation", ".:visible"]))
MpAuthority.freeze_rigid_proxy(self)
```

Compose trail/FSM/FX as children. Networking does not justify a monolithic pawn. Manual tunnel: [editor.md](editor.md).

## Periodic snapshot

A node of yours in the world, server only, 2–10 Hz:

```gdscript
if MpKit.is_server() and game_session.is_running:
	MpKit.push_snapshot(game_session.to_snapshot())
```
