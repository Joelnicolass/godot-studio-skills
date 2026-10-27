---
name: godot-mp-kit
description: >-
  Implement host-authoritative multiplayer in Godot 4 with the informal MpKit
  addon (ENet, slots, handshake, snapshots) plus game glue. Ask the MP type
  first: none (do not copy the addon), local/Wi-Fi (listen-server), or online
  (dedicated server, same project, VPS). Use when copying addons/mp_kit,
  host/host_dedicated/join, submit_* RPCs, Dictionary tunnel, MultiplayerSpawner,
  1P offline, rejoin, dedicated export, feature scaffold, or extracting netcode
  to another project.
---

# Godot — MpKit and multiplayer

One simulator (the server). Clients send intents and paint copies. The addon is small on purpose: reusable pipe, zero gameplay.

Architecture: [godot-layered-architecture](../godot-layered-architecture/SKILL.md) (**ask** Clean vs standard; do not assume layers). Nodes/FX/Resources: [godot-composition-first](../godot-composition-first/SKILL.md). Dedicated / VPS: [dedicated.md](dedicated.md).

## Network scope (required)

**Always ask** (`AskUserQuestion` in Claude Code / `AskQuestion` in Cursor, if available) **before** copying the addon or writing RPCs. Do not assume LAN.

| Choice | What to do |
|----------|-----------|
| **No multiplayer** | Do not install MpKit. No autoload, no RPC, no `MultiplayerSpawner`. |
| **Local / Wi-Fi** (same device or same LAN) | `MpKit.host()` listen-server. The host process **is** a player (slot 1 / peer 1). |
| **Online** (internet, VPS) | **Dedicated server** in the **same project**. `MpKit.host_dedicated()`; clients `join(ip)`. Peer 1 is **not** a player. Develop that way from day one (headless + clients to `127.0.0.1`); the VPS is the same binary with a public IP and open UDP. Rooms and several matches: **room server** (lobby + one dedicated per match, see below) for the internet, or in-process rooms (`MpKit.rooms` / `MpKit.matchmaker`) on one dedicated. Steam / WebRTC: only if the product asks, **later**, not instead of dedicated. |

Do not ask again if the user already chose in this chat or PRD/RULES declares it.

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
| Layers | `addons/mp_kit` does not name session, scenes, copy, or score. Online = dedicated in the addon, not a title `NetworkManager`. |
| Composition | Transport (kit) + glue + (`GameSession` **or** Match node) + actors with `submit_*`. |
| Editor | Spawners, replication config, and pawn scenes are built as nodes. The kit does not generate the world. |
| Reuse | Copy this framework’s canonical addon. The game writes glue + domain; no per-title forks of the kit. |

## Canonical source

The plugin is `addons/mp_kit/` **inside the Godot project**. Copy that folder as-is to another title. Do not fork it per game.

If the project addon and a loose copy diverge, `res://addons/mp_kit/` in this project wins.

API: [kit-api.md](kit-api.md). Glue: [game-glue.md](game-glue.md). Dedicated: [dedicated.md](dedicated.md). Editor / tunnel / scaffold: [editor.md](editor.md). Generic code: [examples.md](examples.md).

Human guide (inspector, step-by-step, custom tunnel, room server, hub rooms and queue): `addons/mp_kit/README.md`.

## Nodes first (human first)

A person must be able to use the kit **without AI**. So in new code always prefer the node layer; hand-written `@rpc` / `submit_*` is the low-level path (it keeps working and is not removed).

| Need | Use | Do not write |
|------|-----|--------------|
| Start an MP game | Tools → **MpKit: Setup game...** (shows `[+]`/`[~]`, never overwrites) | boot/world scenes from scratch by hand |
| The game in one place | **`MpGame`** (`game.tres`: the network and the scenes) in `MpFlow.game`; the menu, the lobby and the room server read it from the flow | scattered `configure()` calls, paths repeated on every node |
| A networked world | one **`MpWorld`** node with `player_scene` (it builds `SpawnPoints`, `Actors`, `Players`, `State`, `Match`, `Hud/Leave`, `Hud/Invite`, `Hud/Start`, `Hud/Waiting`) | wiring the spawner, state and match by hand |
| The match's verbs from any script | **`Mp`**: `play_solo`, `host`, `join`, `leave`, `open_rooms`, `is_server`, `me`, `player`, `state`, `finish`, `net_quality` | finding the `MpFlow` or the `MpMatch` by hand |
| Replicated actor | an **`MpActor`** child (Sync in the inspector; it builds and saves `MpSync`) | a hand-built `MultiplayerSynchronizer`, `MpReplicate` in new code |
| Who simulates, inside a node | `is_multiplayer_authority()` (the kit keeps authority on the server: true solo, host, dedicated) or `MpKit.is_authority()` / `Mp.is_server()` | `MpKit.is_server()` for rules (false solo: it is for network-only work) |
| Who looks at this screen | an **`MpLocalSeat`** in the world, handed by `@export` to HUD / audio / orders (`slot`, `is_mine`, `preview_slot` solo) | `local_slot()` spread over every UI script |
| Something that must last (marks, doors, score) vs a one-off effect | state in Sync / `MpState` / a spawned node (it reaches whoever loads later); effects by `to_all`, or your `@rpc` to `MpKit.ready_peers()` | a one-off RPC for something that must stay, or a "donor" that resends it to whoever comes back |
| A loading screen that waits for the world (shaders, warm-up) | `MpFlow.world_reports_loaded` + `report_world_loaded()` in the world, `world_load_progressed(ratio, phase)` for the screen; the gate counts each peer once its world reported (solo too) | a screen that only covers the scene swap while the match already runs |
| A match value from the start and each change | `MpState.watch(key, cb)` | `changed` + a manual first read, order-dependent |
| Spawn from any peer | `MpSpawner.spawn_here(data)` (null on a client) | `if MpKit.is_server(): spawn(...)` everywhere |
| Player input | an **`MpInput`** child + `input.get_vector(...)` on the server | a `submit_move` per frame |
| Lag-free movement | `MpActor.predict` + `func mp_move(input, delta)` (movement only; effects behind `not input.is_replaying()`) | your own prediction or rollback |
| Stun, slow, knockback on a predicted player | the server writes values `mp_move` reads (`stun_ticks`, `knock`) listed in `sync_extra`; corrections fade by themselves (`correction_smoothing_s`), a warp: `net.snap()` on the server after moving it | moving the owner's node from the server by hand, smoothing corrections yourself |
| Smooth objects (creatures, other players) | `MpActor` with `smoothing = BUFFERED` (default) | a `MultiplayerSynchronizer` on `position` + your own lerp |
| A one-off order from the owner | `net.to_server(&"x", args)` → `func mp_sv_x(args)` | `@rpc("any_peer")` + `accept_command` |
| An effect on everyone | `net.to_all(&"x", args)` → `func mp_all_x(args)` (server only) | your own `@rpc("authority")` |
| Score, clock, round | **`MpState`** (`set_value`, `add`, `changed` signal) | `push_snapshot` + `snapshot_for_joiner` by hand |
| Match start and end | **`MpMatch`** (`all_loaded`, `player_abandoned`, `finish(result)`) | your own ticket and abandon glue |
| Online rooms | **`MpRoomServer`** + `MpLobbyConfig` + `MpRoomRules`; client **`MpLobbyScreen`** | lobby `Callable`s wired by hand |
| A private match on the PC | `MpLocalServer` / `MpBootMenu.offer_private_server`; the HUD shows `ip:port#CODE` (`MpInviteLabel`) | your own launcher |
| Shots with ping | `MpActor.lag_compensate` + `net.rewound(func)` / `net.seen_position_of(node)` / `net.view_lag()` | checking against the present |
| Showing the connection's quality | `Mp.net_quality()` (RTT, jitter, loss, `grade_name`) | your own pings |
| No public IP | `transport = relay` + `relay/server.mjs` (Railway or another host), the secret in `MPKIT_RELAY_SECRET` | opening ports or a tunnel of your own |
| Put it on a VPS | `addons/mp_kit/deploy/deploy.sh user@vps build --rooms 7700` | systemd units per game |
| A server without a VPS | `addons/mp_kit/deploy/fly.sh --app NAME --relay-url wss://…` (Fly.io, behind the relay, no export; GUIDE 13.6) | a Dockerfile of your own |
| Test with a bad network | `--net-lag-ms=100 --net-jitter-ms=30 --net-loss=0.05` on every process | assuming a perfect LAN |

Human guide: `addons/mp_kit/QUICKSTART.md` (the short one), `addons/mp_kit/GUIDE.md` (step by step), `addons/mp_kit/deploy/README.md` and `addons/mp_kit/relay/README.md`. A lab without a game: `mpkit_lab/run/all.sh` and `mpkit_lab/CASES.md`. The kit's own tests: `godot --headless --path <project> --script res://addons/mp_kit/tests/mp_test_runner.gd`.

Rules that do not bend:

- Web and desktop do not mix: a web export uses WebSocket (direct, or through the relay) and never hosts; its server is a `ws` dedicated or any server through the relay.
- The network buffers are adaptive (the 97th percentile of the measured network): do not fix them by hand except to bound them (`buffer_delay_s` is the cap).
- `MpFlow` and world nodes never name lobby classes (`MpMatchAgent`...): group or `load()` by path. Otherwise a game with the lobby as an autoload forms a load cycle.
- Do not add a member to `MpFlow` / `MpSpawner` with the name of one in a game subclass: grep the subclasses first.

## Quickstart (5 steps)

1. Copy `addons/mp_kit/` and enable **MpKit** (the `MpKit` autoload).
2. Tools → **MpKit: Setup game...**, or by hand: an **`MpGame`** (`game.tres`, network and scenes) and an **`MpFlow`** node in the boot scene with `game` = that `.tres` (it moves itself under the root), plus `mp_boot_menu.tscn`.
3. In the world: one **`MpWorld`** node with `player_scene` (it builds the spawner, `MpState` and `MpMatch`). By hand, when the world already has its structure: `MpSlotSpawner` (`spawn_path`, `pawn_scene`, `spawn_points`), `MpState` and `MpMatch`. The spawner holds the synchronizers until each client is ready.
4. Player: `MpActor` (predict) + `MpInput` children; movement in `mp_move`, rules behind `net.is_authority()`, `mp_sv_*` / `mp_all_*` calls.
5. LAN: Host LAN / Join. Online: a dedicated (`--dedicated`) or rooms (`MpRoomServer`, `--room-server`), with a public IP or through the relay; never `host()` behind NAT without the relay.

## What the kit is / is not

Copy `addons/mp_kit/` → autoload `MpKit`.

**Does:** ENet listen or dedicated, slot ↔ peer map, capacity, `world_ready` handshake, opaque `Dictionary` push (snapshot **and** `send_custom` tunnel), signals, replication nodes, `MpBoot`. Optional: `MpFlow` (boot/world scenes, not rules). Optional: in-process hub rooms (`MpRoomDirectory` + FIFO `MpMatchmaker`) on a dedicated. Optional: room server (`lobby/`), ticket admission and WebSocket transport.

**Does not:** score, title copy, actor input, prediction, Steam/WebRTC, “who wins”. `MpReplicate.interpolate` is an optional proxy lerp, not rollback.

If you put score in `mp_kit.gd`, the kit stops being portable.

## Room server (online, one dedicated per match)

Lives in `addons/mp_kit/lobby/`, generic (no game rules or text). Short form:

- **Room server** process (`--room-server`): `MpLobby.start_server(config, launcher)`. Clients `MpLobby.connect_to(host, port, name)`, create/join rooms, pick, ready, chat; the client never picks slot, port or seed. `MpLobbyConfig` (`.tres`, every number overridable with `--field-name=N`) holds limits and times.
- **Tickets**: when the countdown ends the game's `ticket_builder` returns the ticket; `MpMatchLauncher.launch(id, ticket)` picks a free port, stores only `sha256(token)` and starts a dedicated with `--match-ticket-file`. The client gets `match_ready(host, port, token)` and does `MpKit.join(host, port, token)`. In the dedicated `MpMatchAgent` sets `MpKit.admission` from the ticket: foreign, made-up, expired or already-connected tickets are rejected.
- **Launcher**: one process per match, `max_matches` cap (`ERR_BUSY`), heartbeat in `state.json`, result in `result.json` (`MpMatchAgent.report_result`), kills stale/over-long/orphan matches. The game injects `meta_validator`, `options_validator` and `ticket_builder`; the kit stays free of rules and text.
- **Rejoin**: lobby `MpLobbyClient.resume()` / `auto_resume` (same session and seat, `resume_grace_s`); match: same ticket (rooms) or the seat credential the server gave (LAN, dedicated by hand) within `rejoin_grace_s` gets the slot back (the game decides what it keeps). A credential back after a drop wins over the stale connection. No late join by default: the start gate (`MpMatchGate`) turns away whoever arrives after the start (`match_started`); `late_join` (`MpFlow`, `--late-join`) keeps free seats open. A dedicated by hand serves one match after another (fresh world once the match ended and everyone left, or `all_gone`).
- **Transport**: `--transport=enet|ws` (`MpLobbyConfig.transport`), the same in client, room server and dedicated. ENet is UDP (default); WebSocket is TCP (web, TCP tunnels). `wss://` through a reverse proxy.
- Local check: two parallel 1v1 rooms with two real dedicated, headless, then repeat (soak) and look for orphan processes. Details: `addons/mp_kit/README.md` (Room server).

## Required model

```
[Play alone]     do not call host(); OfflineMultiplayerPeer; local_slot() == host_slot
[Host LAN]       MpKit.host()
[Dedicated]      MpKit.host_dedicated()     local_slot() == 0
[Client]         MpKit.join(ip)
```

- Stable **slot**: key for lives/score/HUD. Listen: slot 1 = hosting player. Dedicated: slots 1..N = clients only.
- Volatile **peer id**: validate RPCs with `MpKit.peer_id_for(slot)`. Never `get_unique_id()` as a player id. Peer 1 on dedicated is **not** a slot.

Client: `apply_snapshot` **turns off** the session simulation tick. The guest does not tick the clock. Dedicated does simulate (it is the server).

## Input and authority

Actors: the server is authority. If the body is `RigidBody2D`/`RigidBody3D`, freeze proxies (`MpAuthority.freeze_rigid_proxy`). Do not assume RigidBody on every pawn.

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
	if not MpAuthority.accept_command(self, player_slot):
		return
	apply_x(payload)
```

- Allowlist of `submit_*`. No `rpc add_score`.
- No `call_local` on client commands (duplicates spawn/damage).
- Damage areas: `monitoring = is_multiplayer_authority()`.
- Dedicated never sends `submit_*` (no local player).

## Spawn handshake (required)

Godot’s `MultiplayerSpawner` replicates children on `peer_connected`, while the client is **still on the lobby**; the path fails and Godot never retries it, so that spawner (or synced static node) stays dead for the peer. `MpSpawner` (default `hold_until_world_ready`) uses the `MultiplayerSynchronizer` per-peer visibility: everything it owns in the scene stays hidden and each peer is revealed when its own copy of the spawner reports ready; only then does Godot deliver spawn + sync, paired. Actors with no synchronizer get an empty `MpSpawnGate` (otherwise Godot sends them to everyone).

```
Server broadcast_load_world() + glue loads the world on the server process
  → listen host add_child(local pawn) in _ready; hidden to not-ready peers
  → client loads scene; MpSpawner calls request_world_ready() + rpc_spawner_ready (deferred)
  → server MpSpawner reveals the peer (set_visibility_for) → Godot sends spawn + sync
  → MpSlotSpawner (or glue) spawns the slot that just joined
```

Do not unparent actors in glue: the kit already reveals per peer. Synchronizers go in the scene (or are added before `add_child` / in the actor's own `_ready`), never deferred. Hub rooms: one subtree + `MpSpawner` per room with `room_id` (README → Actors per room).

Actor identity (`player_slot`, etc.): `MultiplayerSynchronizer` properties with `spawn = true`, or the node name (`Pawn_2` / `Ship_2`).

Local FX (post-process, atmosphere) are built in `_ready` **on the client too**, before the guest `return`.

Rejoin: do not reset score; snapshot + `load_world_to`. `MpSpawner` reveals again for the new peer id.

## Snapshots vs transforms

- Position/rotation/visible: an `MpActor` (its `MpSync` is built in the scene; Tools → Make selection a network actor), or `MpAuthority.ensure_sync` before `add_child`.
- Timer/score/lives: `to_snapshot()` at 2–10 Hz via `MpKit.push_snapshot` (Timer, not every `_process` frame).
- Discrete events (floating `+N`): `authority` RPC on a node **of yours**, not MpKit.

Do not put 40 prop positions in the dict if they already go through a synchronizer.

## 1P

Same collision and `submit_*` code (the local host does not send an RPC). Always test play-alone **without** `create_server`.

## Anti-patterns

- Client spawns / `queue_free` / adds points.
- `PlayerId` or `GameSession` imported from `mp_kit.gd`.
- Starting spawn on the same frame as the guest’s `change_scene` (the kit covers this; do not “fix” it by unparenting in glue).
- `leave()` leaving `multiplayer_peer = null` (the kit sets `OfflineMultiplayerPeer`).
- A third peer accepted silently (the kit must `disconnect_peer` when over capacity; “room full” policy is glue + kit).
- HUD that shows the host score because it used peer id 1.
- Dedicated with a pawn for itself, or developing online as a listen-server.
- Pretending a LAN `host()` behind NAT is online.
- Auto-broadcast of the custom tunnel (the server must choose).
- Putting game rules or bullet `kind` in the tunnel dict.

## Checklist

- [ ] MP type declared (none / local-Wi-Fi / online). No MP: this checklist does not apply.
- [ ] Autoload `MpKit` **before** glue. `configure(port, max_players)` before host/join.
- [ ] `MpFlow` (a node in the boot, an autoload or `extends MpFlow`) with an `MpGame` (`game.tres`), or an `MpNetConfig` plus paths. The world with an `MpWorld` unless it already has its own structure. Several maps: `add_world` + `select_world`. Extra glue only for copy or a tunnel.
- [ ] New actors with `MpActor` + `MpInput` (predict for the player); match state in `MpState`; the end with `MpMatch.finish`. No hand-written `@rpc` unless the node layer does not cover the case (write down why).
- [ ] Online: `MpBoot` + `host_dedicated()`; clients `join`; dedicated export; spawn only `occupied_slots()`. Several players per match over the internet: room server + tickets (`MpMatchLauncher`), not a free-for-all `join(ip)`. Optional hub: `MpKit.rooms` / `MpKit.matchmaker` on the same process; score still stays out of the addon.
- [ ] Slots in domain; peers only in RPC/authority.
- [ ] `MpSpawner` or `MpSlotSpawner` with `hold_until_world_ready` (default). The client does not need `MpWorldReady`. No pawn restage in glue.
- [ ] Guest does not simulate rules; server validates sender.
- [ ] 1P offline verified.
- [ ] Pawns are composable packed scenes, not netcode embedded in the kit.
- [ ] New features: Tools scaffold or `/new-mp-feature`; tunnel only for what is not `submit_*` / Resource.
