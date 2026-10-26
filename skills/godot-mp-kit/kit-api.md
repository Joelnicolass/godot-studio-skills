# MpKit — addon API

Files (`res://addons/mp_kit/`):

| File | Role |
|---------|-----|
| `mp_kit.gd` | Autoload. ENet + session RPCs + signals. Children `Rooms` / `Matchmaker`. **No** `class_name` (the autoload is already `MpKit`). |
| `mp_ids.gd` | `class_name MpIds` — slot ↔ peer; rejoin reuses slot |
| `mp_room_directory.gd` | `class_name MpRoomDirectory` — hub rooms (opt-in); room seat ≠ hub slot |
| `mp_matchmaker.gd` | `class_name MpMatchmaker` — FIFO queue; `create_room` when `party_size` is reached |
| `mp_boot.gd` | `class_name MpBoot` — `dedicated_server` / `--dedicated` |
| `mp_lan.gd` | `class_name MpLan` — IPv4 + `advertise` / `browse` |
| `mp_lan_beacon.gd` | `class_name MpLanBeacon` — UDP `MPKIT1` |
| `mp_authority.gd` | `class_name MpAuthority` — authority, freeze 2D/3D, synchronizer, `accept_room_command` |
| `mp_custom_pipe.gd` | `class_name MpCustomPipe` — one tunnel channel |
| `mp_replicate.gd` | `class_name MpReplicate` — authority / sync / freeze / optional lerp |
| `mp_spawner.gd` | `class_name MpSpawner` — MultiplayerSpawner that holds its scope per peer until that peer's spawner is ready |
| `mp_slot_spawner.gd` | `class_name MpSlotSpawner` — one packed pawn per occupied slot |
| `mp_boot_menu.gd` | `class_name MpBootMenu` — drop-in lobby (`mp_boot_menu.tscn`) |
| `mp_flow.gd` | `class_name MpFlow` — optional flow (scenes, host/join/1P, world catalog) |
| `mp_world_ref.gd` | `class_name MpWorldRef` — one catalog world (`id` + scene) |
| `mp_world_ready.gd` | `class_name MpWorldReady` — leftover; unused if an `MpSpawner` is present |
| `plugin.cfg` | Editor: Tools, scaffold, snippets, autoload on Enable. |

These files **do not** name `GameSession`, `SceneDirector`, copy, `PlayerId`, or `submit_action`.

## High-level layer (what a person uses first)

| Piece | What for |
|---|---|
| `mp.gd` (`Mp`) | The match's verbs from any script: `play_solo`, `host`, `join(address)`, `leave`, `open_rooms`, `is_server`, `is_online`, `me`, `player(slot)`, `state`, `current_match`, `finish(result)`, `net_quality(slot)` |
| `mp_game.gd` (`MpGame`) | The game in one `.tres`: an `MpNetConfig` plus `boot_scene`, `world_scene`, `lobby_scene`, `rooms_scene`. In `MpFlow.game` it fills `net_config` and every empty path |
| `nodes/mp_world.gd` (`MpWorld`) | One node in the world; in the editor it builds `SpawnPoints`, `Actors`, `Players`, `State`, `Match`, `Hud/Leave`, `Hud/Invite` |
| `nodes/mp_actor.gd` (`MpActor`) | Sync, owner, `to_server` → `mp_sv_*`, `to_all` → `mp_all_*`, prediction (`mp_move`), adaptive smoothing, lag compensation (`rewound`, `seen_position_of`, `view_lag`) |
| `nodes/mp_input.gd` (`MpInput`) | The owner's keys with the `Input` API; an adaptive server buffer and the owner's pace |
| `nodes/mp_state.gd`, `nodes/mp_match.gd` | Match values; start, waiting for seats, absences, end |
| `nodes/mp_leave_button.gd`, `nodes/mp_invite_label.gd` | Leaving (it works while the world is paused); a private match's invite |
| `core/mp_net_quality.gd` | RTT, jitter (97th percentile), loss and a grade per connection |
| `core/mp_lag_comp.gd` | A second of poses per actor on the server; `rewind(stamp, callable)` |
| `core/mp_relay_peer.gd` + `relay/server.mjs` | The `relay` transport (WebSocket to a Node relay, no public IP); a room with a live host is taken |

The detail of every piece: `addons/mp_kit/README.md`. What follows is the low level (it keeps working).

## Install

Copy `addons/mp_kit/` to `res://addons/mp_kit/` in the project. Autoload, **before** glue:

```
MpKit="*res://addons/mp_kit/mp_kit.gd"
```

`MpKit.configure(port, max_players, host_slot, custom_channels)` before `host()` / `host_dedicated()` / `join()`. Empty `custom_channels` = every tunnel channel.

ENet's own peer cap is `max_players + max_pending_admission` (at most `MpKit.ENET_MAX_PEERS`, 4095), so a peer past the seats still connects and is turned away with a reason (`full`) instead of timing out.

## Signals (the game listens)

- `peer_joined(peer_id, slot)` — accepted and slotted
- `peer_left(peer_id, slot)` — mapping cleared; the slot stays reserved for rejoin
- `join_failed` — the client never arrived
- `admission_rejected(reason)` — client: the server turned it away (`match_started`, `full`, `grace_over`, `slot_taken`, `rejected`)
- `server_lost` — server down; the kit already called `leave()`
- `client_world_ready(peer_id)` — the client registered spawners
- `load_world` — open the match scene (the server process does not receive this RPC)
- `snapshot_received(data)` — your `Dictionary`
- `session_ended(data)` — your `Dictionary`
- `slot_assigned(slot)` — this client learned its slot
- `custom_received(channel, data, from_peer)` — opaque tunnel (`from_peer` is `1` if the server pushed)

## Kit RPCs (closed list)

Client → server: `rpc_world_ready`, `rpc_custom_to_server`  
Server → clients: `rpc_assign_slot`, `rpc_load_world`, `rpc_snapshot`, `rpc_session_ended`, `rpc_custom_from_server`  
`MpRoomDirectory`: `rpc_assign_room` (authority → that peer; `room_id` travels as `String`)

Pawn input and custom-dict meaning **outside** the kit.

## Useful methods

- `host(dedicated=false) -> Error` / `host_dedicated() -> Error` / `join(address) -> Error` / `leave()`
- `rooms` / `matchmaker` — children `Rooms` and `Matchmaker`. `leave()` **resets** them (closes rooms, clears the queue), does not `queue_free` them.
- `is_networked()` / `is_server()` / `is_dedicated()` / `is_listen_host()`
- `local_slot()` — `0` on dedicated (no local player). **Not** a hub-room seat.
- `occupied_slots()` / `peer_id_for(slot)` / `slot_for_peer(peer_id)`
- `request_world_ready()`
- `broadcast_load_world()` / `load_world_to(peer)`
- `push_snapshot(data)` / `push_snapshot_to(peer, data)`
- `broadcast_session_ended(data)`
- `is_peer_world_ready(peer_id)`
- `send_custom(channel, data)` / `broadcast_custom` / `push_custom_to` / `is_custom_channel_allowed`

Editor: [editor.md](editor.md).

`rpc_load_world` is `call_remote`: the **server does not receive it**. It enters the world via glue (listen host and dedicated).

## MpBoot

```gdscript
MpBoot.is_dedicated_process()   # dedicated_server / dedicated feature, or --dedicated in cmdline or user args
MpBoot.user_flag("dedicated")
MpBoot.user_value("mp-port", "7777")
```

Do not treat `--headless` alone as dedicated.

## MpAuthority

```gdscript
MpAuthority.claim_server(node)           # authority = peer 1
MpAuthority.ensure_sync(node, PackedStringArray([".:position", ".:rotation"]))
MpAuthority.freeze_rigid_proxy(body)     # RigidBody2D/3D; no-op if you are authority
MpAuthority.should_send_command()        # networked and not server
MpAuthority.accept_command(self, player_slot)  # in submit_*: server + sender == slot peer
MpAuthority.command_slot(self)                 # in submit_* on a shared node: sender's slot (0 = reject)
MpAuthority.accept_room_command(self, room_id, seat)  # server + sender == peer_for_seat
```

`accept_command` does not change: it still validates the **hub slot**. `accept_room_command` validates the **seat in that room**.

| Method | Condition |
|--------|-----------|
| `accept_command(node, player_slot)` | Server and `get_remote_sender_id() == MpKit.peer_id_for(player_slot)` |
| `command_slot(node)` | Server: slot of the sender (`0` off the server, offline, or unknown peer) |
| `accept_room_command(node, room_id, seat)` | Server and `get_remote_sender_id() == MpKit.rooms.peer_for_seat(room_id, seat)` |

## MpRoomDirectory

Child `Rooms` of the autoload (`MpKit.rooms`). Mutators **server only** (client: no-op, `FAILED`, empty id). Empty rooms count toward `max_rooms` until `close_room`.

`@export`: `max_rooms` (16), `seats_per_room` (2), `code_length` (4). Code alphabet: `A-Z0-9` without `0O1I`.

Identity: ENet `peer_id` = RPC; hub **slot** (`MpIds` / `local_slot()`) = connection to the process; room **id** (`StringName`, e.g. `r_1`); room **seat** = `0..seats-1` in that room.

| Method | What it does |
|--------|----------|
| `create_room(seats=-1) -> StringName` | Empty room. `-1` → `seats_per_room`. Empty id if at cap. Unique code. Seats **nobody**. |
| `join_room(peer_id, room_id) -> Error` | Next free seat; `room_assigned` RPC to that peer. If already in another room: `leave_room` then seat. Same room: idempotent `OK`. |
| `join_room_by_code(peer_id, code) -> Error` | Normalizes to uppercase. |
| `leave_room(peer_id)` | Frees the seat. Does not close the room. |
| `close_room(room_id)` | Unseats everyone and deletes the room. |
| `reset()` | Clears maps **without** RPC (`MpKit.leave()`). |
| `room_id_for_peer` / `seat_for_peer` | Room / seat (`-1` if not seated). |
| `peer_for_seat(room_id, seat)` | Peer in that seat (`0` if empty). |
| `peers_in_room` / `code_for_room` / `is_room_full` / `room_count` | Queries. |
| `push_snapshot_to_room` / `push_custom_to_room` | `MpKit.push_snapshot_to` / `push_custom_to` **per member**. Never `push_snapshot` to the whole hub. |

Signals (server): `room_created(room_id, code)`, `peer_seated(room_id, peer_id, seat)`, `room_ready(room_id)` (every seat taken), `peer_unseated(...)`, `room_closed(room_id)`.

Client: `room_assigned(room_id, seat)` from `rpc_assign_room`.

`MpKit.peer_left` → `leave_room`. No forfeit rules.

## MpMatchmaker

Child `Matchmaker` (`MpKit.matchmaker`). **No** RPCs. Uses `MpKit.rooms`, not paths. `@export party_size = 2`.

| Method | What it does |
|--------|----------|
| `enqueue(peer_id)` | Ignores if already queued **or** already seated. |
| `dequeue(peer_id)` | Idempotent. |
| `queued_count()` / `is_queued(peer_id)` | Queries. |
| `reset()` | Clears the queue (`MpKit.leave()`). |

When `queued_count() >= party_size`: FIFO takes `party_size`, `create_room(party_size)`, `join_room` each, emits `match_assembled(room_id, peer_ids: PackedInt32Array)`. Instant (no Accept). If `create_room` fails: they stay queued and it does not emit.

`MpKit.peer_left` → `dequeue`. No theme, nick, or `change_scene`.

## MpSpawner

Extends the native `MultiplayerSpawner`. Uses the `MultiplayerSynchronizer` **per-peer visibility**: Godot sends a spawned node to a peer once any of its synchronizers is visible to it (a node with none goes to everyone), and a static synced node syncs only where visible.

Default `hold_until_world_ready = true`:

1. Server: every synchronizer the spawner owns starts hidden, including ones added later. Owner: the spawners whose parent is the synchronizer's nearest ancestor with an `MpSpawner` child; none → every `MpSpawner` of the scene. Under `spawn_path` → this spawner.
2. Client: the spawner calls `MpKit.request_world_ready()` and `rpc_spawner_ready` on itself (deferred).
3. Server: on `rpc_spawner_ready` from a peer, `set_visibility_for(peer, true)` on what it holds → Godot delivers spawn + sync.
4. `room_id` (optional, set on the server): reveal only to peers seated in that room; `peer_seated` / `peer_unseated` reveal / hide (unseat despawns on that client).
5. `gate_unsynced_spawns` (default on): an actor with no synchronizer gets an empty `MpSpawnGate` synchronizer on every peer as it enters `spawn_path`.

- Inspector: `spawn_path` = parent of the actors. `extra_scenes` = packed scenes.
- Glue: `add_child(node, true)` under that parent, whenever. Identity (`player_slot`, etc.) goes on the `MultiplayerSynchronizer` with `spawn = true`, not an RPC.
- Synchronizers: in the scene, or `MpAuthority.ensure_sync` before `add_child` / in the actor's own `_ready`. Later ones miss the spawn packet (a peer that comes back: `ERR_INVALID_DATA`); the spawner `push_error`s them.
- `spawn_function`: set it in any `_ready` of the scene (the spawner's, a sibling's or the parent's); the spawner wraps it at the end of that frame (deferred), before anything spawns. Set later, it warns and the first node counts as added by hand.
- `is_revealed_to(peer_id)` (server): this peer has the spawner and passes `room_id`.
- `hold_until_world_ready = false` only if every peer already has this scene.
- Cost: per reveal / seat change one walk of the scene; per node added to the tree a type check. Nothing per frame.

## MpSlotSpawner

Extends `MpSpawner`. `@export pawn_scene`, `spawn_points`, `actor_name_prefix` (`Pawn_`). Listen host spawns the local slot in `_ready`. Joiners on `client_world_ready`. Dedicated does not spawn slot 0. Identity: name `Pawn_<n>` and `player_slot` if the actor exports it.

## MpWorldReady

Optional leftover. If the scene already has an `MpSpawner`, this node is a no-op. Old scenes may keep it.

## MpReplicate

Child of the actor. Inspector: `interpolate` (default on) + `interpolate_speed`. Proxies only; authority does not interpolate. `sync_properties` is what Wire replication puts on the new synchronizer; the synchronizer lives in the scene (no runtime creation; `push_error` if missing).

## MpBootMenu

Scene `res://addons/mp_kit/mp_boot_menu.tscn`. Copy via `@export`. If an `MpFlow` autoload is present, it uses it. Otherwise assigned `world_scene` = loop without glue (`drive_kit`: the host arms the start gate with `start_seats` and sends the world to every seat it admits). Empty = UI only; your glue listens to the signals.

## MpFlow

Autoload **after** `MpKit` (Tools → **New session flow...**, or `extends MpFlow`). Not score or rules: boot/world, `play_solo` / `host_lan` / `join_lan` / `return_to_boot`, LAN advertise, the start gate on every path that hosts (**Match start** group: `rejoin_grace_s`, `load_timeout_s`, `start_seats`, `dedicated_start_seats`; `--start-seats=N`), dedicated on first client.

## MpMatchGate

`/root/MpKit/Gate` (`MpKit.gate`, `Mp.gate()`). One owner for who sits and when the match starts: `IDLE` (not armed: solo or a server without a flow) → `FILLING` (free seats open; the world paused on every peer until the expected seats load or `load_timeout_s`) → `RUNNING` (only a seat that left comes back within `rejoin_grace_s`; anyone else is turned away with `match_started` / `grace_over` / `slot_taken` / `full`). A seat credential per seat in open mode (LAN, dedicated by hand), the ticket in rooms. `loaded_count()` / `expected_count()` are valid on the client too (for a "waiting" HUD). Host LAN: `can_start_now()` / `start_now()`. `MpMatch` re-emits its signals in the world.

One world:

```gdscript
extends MpFlow

func _ready() -> void:
	boot_path = "res://scenes/ui/boot.tscn"
	world_path = "res://scenes/world/match.tscn"
	start_when = StartWhen.DEDICATED_FIRST_CLIENT
	super._ready()
```

Several worlds — `MpWorldRef` catalog (inspector `worlds`, or `add_world`). The lobby calls `select_world(&"2d")`. Joiners get `world_id` in the snapshot. `--world=3d` (user arg) selects the id if it exists.

```gdscript
func _ready() -> void:
	boot_path = "res://scenes/ui/boot.tscn"
	add_world(&"2d", "res://scenes/world/match_2d.tscn")
	add_world(&"3d", "res://scenes/world/match_3d.tscn")
	start_when = StartWhen.DEDICATED_FIRST_CLIENT
	super._ready()

# lobby
MpFlow.select_world(&"3d")
```

`snapshot_for_joiner()` already sends `world_id`. Override and call `super.snapshot_for_joiner()` if you need more state.

`MpFlow.find_in_tree(self)` finds the autoload even if it is not named `MpFlow` (the demo is `NetGlue`).

## MpLan

`MpLan.get_local_ipv4()` / `MpLan.is_valid_ipv4(ip)` for the listen lobby. Online: VPS IP (or `127.0.0.1` in dev), not the client’s LAN address.

```gdscript
MpLan.advertise(parent, "Room")   # UDP; parent to a node that survives change_scene (autoload)
MpLan.browse(parent)              # signal rooms_changed(rooms: Array) — **LAN browse**, not hub rooms
```

## MpIds (contract)

- Listen: slot `host_slot` (1) = hosting player = ENet peer 1. Clients: `host_slot+1..max_players`.
- Dedicated: peer 1 has no slot. Clients: `host_slot..max_players`.
- `unbind_peer` sets the slot to `0` (free to rebind), does not delete the seat.
- `assign_client` reuses the slot if the peer was already there, or rebinds an empty slot.
- `occupied_slots()` = slots whose peer ≠ 0.

## Failures the kit already covers

| Typical failure | Mitigation |
|--------------|------------|
| 1P opens a port | `is_networked()` false until `host()`/`join()` |
| HUD uses unique_id | `local_slot()` (0 = dedicated) |
| Spawn before client scene | `MpSpawner.hold_until_world_ready` + `rpc_spawner_ready` |
| Client RigidBody fights sync | `freeze_rigid_proxy` |
| `leave()` with null peer | `OfflineMultiplayerPeer` |
| Host drops | `server_lost` |
| Garbage IP | `join_failed` |
| Capacity | `create_server` max_clients + `disconnect_peer` |
