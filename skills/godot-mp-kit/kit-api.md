# MpKit — addon API

Files (`res://addons/mp_kit/`):

| File | Role |
|---------|-----|
| `mp_kit.gd` | Autoload. ENet + session RPCs + signals. **No** `class_name` (the autoload is already `MpKit`). |
| `mp_ids.gd` | `class_name MpIds` — slot ↔ peer; rejoin reuses slot |
| `mp_boot.gd` | `class_name MpBoot` — `dedicated_server` / `--dedicated` |
| `mp_lan.gd` | `class_name MpLan` — IPv4 + `advertise` / `browse` |
| `mp_lan_beacon.gd` | `class_name MpLanBeacon` — UDP `MPKIT1` |
| `mp_authority.gd` | `class_name MpAuthority` — authority, freeze 2D/3D, synchronizer |
| `mp_custom_pipe.gd` | `class_name MpCustomPipe` — one tunnel channel |
| `mp_replicate.gd` | `class_name MpReplicate` — authority / sync / freeze / optional lerp |
| `mp_spawner.gd` | `class_name MpSpawner` — MultiplayerSpawner that waits for `world_ready` |
| `mp_slot_spawner.gd` | `class_name MpSlotSpawner` — one packed pawn per occupied slot |
| `mp_boot_menu.gd` | `class_name MpBootMenu` — drop-in lobby (`mp_boot_menu.tscn`) |
| `mp_flow.gd` | `class_name MpFlow` — optional flow (scenes, host/join/1P, world catalog) |
| `mp_world_ref.gd` | `class_name MpWorldRef` — one catalog world (`id` + scene) |
| `mp_world_ready.gd` | `class_name MpWorldReady` — leftover; unused if an `MpSpawner` is present |
| `plugin.cfg` | Editor: Tools, scaffold, snippets, autoload on Enable. |

These files **do not** name `GameSession`, `SceneDirector`, copy, `PlayerId`, or `submit_action`.

## Install

Copy `addons/mp_kit/` to `res://addons/mp_kit/` in the project. Autoload, **before** glue:

```
MpKit="*res://addons/mp_kit/mp_kit.gd"
```

`MpKit.configure(port, max_players, host_slot, custom_channels)` before `host()` / `host_dedicated()` / `join()`. Empty `custom_channels` = every tunnel channel.

## Signals (the game listens)

- `peer_joined(peer_id, slot)` — accepted and slotted
- `peer_left(peer_id, slot)` — mapping cleared; the slot stays reserved for rejoin
- `join_failed` — the client never arrived
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

Pawn input and custom-dict meaning **outside** the kit.

## Useful methods

- `host(dedicated=false) -> Error` / `host_dedicated() -> Error` / `join(address) -> Error` / `leave()`
- `is_networked()` / `is_server()` / `is_dedicated()` / `is_listen_host()`
- `local_slot()` — `0` on dedicated (no local player)
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
MpBoot.is_dedicated_process()   # dedicated_server feature or --dedicated (user args)
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
```

## MpSpawner

Extends the native `MultiplayerSpawner`. Uses the `MultiplayerSynchronizer` **per-peer visibility** mechanism: Godot does not send a spawn to a peer until the actor's synchronizer is visible to it, and on reveal it delivers spawn + sync, paired.

Default `hold_until_world_ready = true` (server side only):

1. Every actor entering under `spawn_path` starts hidden (`public_visibility = false` on its synchronizers).
2. On `client_world_ready`, `set_visibility_for(peer, true)` → Godot delivers spawn + sync to that peer.
3. `peer_left` → visibility off for that peer (clean for rejoin).

- Inspector: `spawn_path` = parent of the actors (stays untouched; the client needs it to instantiate). `extra_scenes` = packed scenes.
- Glue: `add_child(node, true)` under that parent, whenever. Identity (`player_slot`, etc.) goes on the `MultiplayerSynchronizer` with `spawn = true`, not an RPC.
- `hold_until_world_ready = false` only if every peer already has this scene.
- Client: this same node calls `request_world_ready()` deferred. One `MpSpawner` is enough.

## MpSlotSpawner

Extends `MpSpawner`. `@export pawn_scene`, `spawn_points`, `actor_name_prefix` (`Pawn_`). Listen host spawns the local slot in `_ready`. Joiners on `client_world_ready`. Dedicated does not spawn slot 0. Identity: name `Pawn_<n>` and `player_slot` if the actor exports it.

## MpWorldReady

Optional leftover. If the scene already has an `MpSpawner`, this node is a no-op. Old scenes may keep it.

## MpReplicate

Child of the actor. Inspector: `interpolate` (default on) + `interpolate_speed`. Proxies only; authority does not interpolate.

## MpBootMenu

Scene `res://addons/mp_kit/mp_boot_menu.tscn`. Copy via `@export`. If an `MpFlow` autoload is present, it uses it. Otherwise assigned `world_scene` = loop without glue (host `broadcast_load_world` + late join). Empty = UI only; your glue listens to the signals.

## MpFlow

Autoload **after** `MpKit` (Tools → **New session flow...**, or `extends MpFlow`). Not score or rules: boot/world, `play_solo` / `host_lan` / `join_lan` / `return_to_boot`, LAN advertise, late join, dedicated on first client.

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
MpLan.browse(parent)              # signal rooms_changed(rooms: Array)
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
| Spawn before client scene | `MpSpawner.hold_until_world_ready` + `request_world_ready` |
| Client RigidBody fights sync | `freeze_rigid_proxy` |
| `leave()` with null peer | `OfflineMultiplayerPeer` |
| Host drops | `server_lost` |
| Garbage IP | `join_failed` |
| Capacity | `create_server` max_clients + `disconnect_peer` |
