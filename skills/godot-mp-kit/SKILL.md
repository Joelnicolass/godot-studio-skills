---
name: godot-mp-kit
description: >-
  Implement host-authoritative multiplayer in Godot 4 with the informal MpKit
  addon (ENet, slots, handshake, snapshots) plus game glue. Use when copying
  addons/mp_kit, hosting/joining LAN, submit_* RPCs, MultiplayerSpawner, 1P
  offline, rejoin, RigidBody authority, or extracting netcode to another
  project.
---

# Godot — MpKit and multiplayer

Listen-server pattern: **one simulator (host)**. The guest sends intents and paints copies. The addon is small on purpose: reusable pipe, zero gameplay.

Architecture: [godot-layered-architecture](../godot-layered-architecture/SKILL.md) (**ask** Clean vs standard; do not assume layers). Nodes/FX/Resources: [godot-composition-first](../godot-composition-first/SKILL.md).

Pawn/projectile/enemy types: Resource `.tres` on the actor, not an RPC per `kind` string.

## Priorities (always)

Always prioritize:

- architecture that is easy to scale and clean in layers
- composition structures always take priority
- nodes and editor configuration always take priority
- component reusability always takes priority

On the network that means:

| Priority | In MpKit / glue |
|-----------|-----------------|
| Layers | `addons/mp_kit` does not name session, scenes, copy, or score. Future dedicated server = replace the addon. |
| Composition | Transport (kit) + glue (when the round starts) + `GameSession` + pawns with `submit_*`. Not a 2000-line `NetworkManager.gd`. |
| Editor | Spawners, replication config, and pawn scenes are built as nodes. The kit does not generate the world. |
| Reuse | Copy this framework’s canonical addon. The game writes glue + domain; no per-title forks of the kit. |

## Canonical source

The plugin is `addons/mp_kit/` **inside the Godot project**. Copy that folder as-is to another title. Do not fork it per game.

If the project addon and a loose copy diverge, `res://addons/mp_kit/` in this project wins.

API: [kit-api.md](kit-api.md). Glue: [game-glue.md](game-glue.md). Generic code: [examples.md](examples.md).

## What the kit is / is not

Copy `addons/mp_kit/` → autoload `MpKit`.

**Does:** ENet host/join/leave, slot ↔ peer map, capacity, `world_ready` handshake, opaque `Dictionary` push, session signals.

**Does not:** score, combo, `change_scene`, copy, pawn input, advanced interpolation, Steam/WebRTC, “when the match starts”.

If you put score in `mp_kit.gd`, the kit stops being portable.

## Required model

```
[Play solo]    do not call host(); OfflineMultiplayerPeer; local_slot() == host_slot
[LAN host]     MpKit.host()
[Client]       MpKit.join(ip)
```

- Stable **slot**: key for lives/score/HUD. Slot 1 = listen-server.
- Volatile **peer id**: validate RPCs with `MpKit.peer_id_for(slot)`. Never `get_unique_id()` as player id.

Client: `apply_snapshot` **turns off** the session simulation tick. The guest does not tick the clock.

## Input and authority

Pawns: the server is authority. `RigidBody2D` proxies freeze kinematic (`MpAuthority.freeze_rigid_proxy`).

```
if MpAuthority.should_send_command():
    pawn.submit_x.rpc_id(1, payload)
else:
    pawn.apply_x(payload)
```

RPC on **your** pawn, not the kit:

```gdscript
@rpc("any_peer", "call_remote", "reliable")
func submit_x(payload) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != MpKit.peer_id_for(player_slot):
		return
	apply_x(payload)
```

- Allowlist of `submit_*`. No `rpc add_score`.
- No `call_local` on client commands (duplicates spawn/damage).
- Damage areas: `monitoring = is_multiplayer_authority()`.

## Spawn handshake (required)

`MultiplayerSpawner` drops packets if the client has not registered spawnable scenes yet.

```
Host broadcast_load_world()
  → client loads scene, registers spawners, MpKit.request_world_ready()
  → host waits for client_world_ready
  → only then add_child(pawn, true)
```

Local FX (post-process, atmosphere) is built in `_ready` **on the client too**, before the guest `return`.

Rejoin: do not reset score; snapshot + `load_world_to` + re-parent spawner children if spawn must be resent.

## Snapshots vs transforms

- Position/rotation/visible: `MultiplayerSynchronizer` (`MpAuthority.ensure_sync`).
- Timer/score/lives: `GameSession.to_snapshot()` at 2–10 Hz via `MpKit.push_snapshot`.
- Discrete events (floating `+N`): `authority` RPC on a node **of yours**, not MpKit.

Do not put 40 prop positions in the dict if they already go through a synchronizer.

## 1P

Same collision and `submit_*` code (the local host does not send RPC). Always test play-solo **without** `create_server`.

## Dedicated server later

Replace this addon (or the transport inside `host()`/`join()`). Domain and pawn `submit_*` RPCs stay.

## Anti-patterns

- Client spawns / `queue_free` / adds points.
- `PlayerId` or `GameSession` imported from `mp_kit.gd`.
- Starting spawn on the same frame as the guest’s `change_scene`.
- `leave()` leaving `multiplayer_peer = null` (the kit sets `OfflineMultiplayerPeer`).
- A third peer accepted silently (the kit must `disconnect_peer` over capacity; “room full” policy is glue + kit).
- HUD that shows the host score because it used peer id 1.

## Checklist

- [ ] Autoload `MpKit` **before** glue. `configure(port, max_players)` before host/join.
- [ ] Own glue: when `start_match`, copy, scenes. Kit untouched.
- [ ] Slots in domain; peers only in RPC/authority.
- [ ] `world_ready` handshake before the first replicated `add_child`.
- [ ] Guest does not simulate rules; host validates sender.
- [ ] 1P offline verified.
- [ ] Pawns are composable packed scenes, not netcode baked into the kit.
