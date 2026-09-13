# MpKit — addon API

Files (`res://addons/mp_kit/`):

| File | Role |
|---------|-----|
| `mp_kit.gd` | Autoload. ENet + session RPCs + signals. **No** `class_name` (the autoload is already `MpKit`). |
| `mp_ids.gd` | `class_name MpIds` — slot ↔ peer; rejoin reuses slot |
| `mp_lan.gd` | `class_name MpLan` — IPv4 |
| `mp_authority.gd` | `class_name MpAuthority` — authority, freeze, synchronizer |
| `plugin.cfg` | Editor visibility. The real autoload lives in `project.godot`. |

These files **do not** name `GameSession`, `SceneDirector`, copy, `PlayerId`, or `submit_action`.

## Install

Copy `addons/mp_kit/` to `res://addons/mp_kit/` in the project. Autoload, **before** glue:

```
MpKit="*res://addons/mp_kit/mp_kit.gd"
```

`MpKit.configure(port, max_players, host_slot)` before `host()` / `join()`.

## Signals (the game listens)

- `peer_joined(peer_id, slot)` — accepted and slotted
- `peer_left(peer_id, slot)` — mapping cleared; the slot stays reserved for rejoin
- `join_failed` — the client never arrived
- `server_lost` — listen-server down; the kit already called `leave()`
- `client_world_ready(peer_id)` — the client registered spawners
- `load_world` — open the match scene
- `snapshot_received(data)` — your `Dictionary`
- `session_ended(data)` — your `Dictionary`
- `slot_assigned(slot)` — this client learned its slot

## Kit RPCs (closed list)

Client → server: `rpc_world_ready`  
Server → clients: `rpc_assign_slot`, `rpc_load_world`, `rpc_snapshot`, `rpc_session_ended`

Pawn input **outside** the kit.

## Useful methods

- `host() -> Error` / `join(address) -> Error` / `leave()`
- `is_networked()` / `is_server()`
- `local_slot()` / `peer_id_for(slot)` / `slot_for_peer(peer_id)`
- `request_world_ready()`
- `broadcast_load_world()` / `load_world_to(peer)`
- `push_snapshot(data)` / `push_snapshot_to(peer, data)`
- `broadcast_session_ended(data)`
- `is_peer_world_ready(peer_id)`

`rpc_load_world` is `call_remote`: the **host does not receive it**. The host enters the world via glue.

## MpAuthority

```gdscript
MpAuthority.claim_server(node)           # authority = peer 1
MpAuthority.ensure_sync(node, PackedStringArray([".:position", ".:rotation"]))
MpAuthority.freeze_rigid_proxy(body)     # no-op if you are authority
MpAuthority.should_send_command()        # networked and not server
```

## MpLan

`MpLan.get_local_ipv4()` / `MpLan.is_valid_ipv4(ip)` for the host lobby.

## MpIds (contract)

- Slot 1 = listen-server = ENet peer 1.
- Clients: first hole in `2..max_players`.
- `unbind_peer` sets the slot to `0` (free to rebind), does not delete the seat.
- `assign_client` reuses the slot if the peer was already there, or rebinds an empty slot.

## Failures the kit already covers

| Typical failure | Mitigation |
|--------------|------------|
| 1P opens a port | `is_networked()` false until `host()`/`join()` |
| HUD uses unique_id | `local_slot()` |
| Spawn before client scene | `request_world_ready` |
| Client RigidBody fights sync | `freeze_rigid_proxy` |
| `leave()` with null peer | `OfflineMultiplayerPeer` |
| Host drops | `server_lost` |
| Garbage IP | `join_failed` |
