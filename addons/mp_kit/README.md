# MpKit — informal multiplayer kit (Godot 4)

Canonical copy: this repo (`addons/mp_kit`). Host-authoritative LAN helpers. **No gameplay.** No scores, scenes, copy, or pawns.

Cursor skill: `skills/godot-mp-kit/`. Glue and rules stay in the game.

## Install

From the repo root, into a Godot 4 project:

```bash
./install.sh --addon /path/to/godot-project
```

Or copy this folder to `res://addons/mp_kit/`. Then add the autoload **before** game glue:

```
MpKit="*res://addons/mp_kit/mp_kit.gd"
```

Enable the plugin in the editor for visibility; headless/CI still need the autoload in `project.godot`.

1. Call `MpKit.configure(port, max_players)` before `host()` / `join()`.
2. Connect signals. Do **not** put rules in `mp_kit.gd`.

## What you get

| Piece | Role |
|-------|------|
| `mp_kit.gd` | ENet transport + slot map + session RPCs |
| `mp_ids.gd` | logical slot ↔ ENet peer id (rejoin keeps the slot) |
| `mp_lan.gd` | IPv4 helpers |
| `mp_authority.gd` | server authority, freeze proxies, `MultiplayerSynchronizer` |

## Signals (game listens)

- `peer_joined(peer_id, slot)` — after a client is accepted and slotted
- `peer_left(peer_id, slot)` — mapping cleared; slot stays reserved for rejoin
- `join_failed` — client never reached the server
- `server_lost` — listen-server gone; kit already `leave()`s
- `client_world_ready(peer_id)` — client finished loading spawners (`request_world_ready`)
- `load_world` — host told everyone (or you) to open the match scene
- `snapshot_received(data)` — Dictionary you defined
- `session_ended(data)` — Dictionary you defined
- `slot_assigned(slot)` — this client learned its slot

## RPCs (closed list)

Client → server: `rpc_world_ready`  
Server → clients: `rpc_assign_slot`, `rpc_load_world`, `rpc_snapshot`, `rpc_session_ended`

Pawn input (`submit_impulse`, `submit_fire`, …) stays on **your** nodes.

## Handshake (spawn)

1. Host `broadcast_load_world()` / `load_world_to(peer)`.
2. Each client scene `_ready` registers `MultiplayerSpawner` scenes, then `MpKit.request_world_ready()`.
3. Host waits for `client_world_ready` **before** `add_child` of replicated actors.

## 1P

Do not call `host()`. Offline peer is enough. `local_slot()` returns `host_slot` (1).

## Dedicated server later

Replace only this addon (or swap ENet inside `host()`/`join()`). Game domain and `submit_*` RPCs stay.
