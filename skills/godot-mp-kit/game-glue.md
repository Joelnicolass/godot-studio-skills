# Game glue (what you write)

For a one-world title, **you do not need a `NetGlue`**. Tools → **MpKit: New session flow...** writes an `extends MpFlow` autoload. The lobby is `MpBootMenu` or buttons that call `play_solo` / `host_lan` / `join_lan`.

Write your own glue only if:

1. Copy or a tunnel (like the demo: emote) → `extends MpFlow` and override.
2. Clean: `GameSession` + `SceneDirector` on top of `MpFlow`, or skip it if the director already changes scenes.
3. The round waits for N players / a “ready” → `start_when` is not enough; call `start_match()` yourself.

Several maps are not glue: `add_world` / `worlds` + `select_world(&"id")`.

Autoload order: `MpKit` → `MpFlow` (or your subclass) → the rest.

Dedicated / VPS: [dedicated.md](dedicated.md).

## MpFlow (default)

```gdscript
extends MpFlow

func _ready() -> void:
	boot_path = "res://scenes/ui/boot.tscn"
	world_path = "res://scenes/world/match.tscn"
	room_name = "My room"
	start_when = StartWhen.DEDICATED_FIRST_CLIENT
	super._ready()
```

Several worlds:

```gdscript
add_world(&"2d", "res://scenes/world/match_2d.tscn")
add_world(&"3d", "res://scenes/world/match_3d.tscn")
select_world(&"2d")
```

Play solo / host / join / back to boot: `MpFlow` methods. LAN advertise lives on the autoload (survives `change_scene`). Browse on the menu: `MpLan.browse(self)`.

UI shortcut: `MpBootMenu`. If it finds an `MpFlow` in the tree, it uses it.

Online: IP field (dev: `127.0.0.1`). `join_lan` already validates IPv4.

## Custom policy (N clients, not MpFlow alone)

Listen: a valid policy is start when the 2nd peer connects. Dedicated: the server starts empty; start on the Nth client or on “ready”. Then do not use `DEDICATED_FIRST_CLIENT`; call `MpFlow.start_match()` or change scenes yourself.

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
