# MpKit — API del addon

Archivos (`res://addons/mp_kit/`):

| Archivo | Rol |
|---------|-----|
| `mp_kit.gd` | Autoload. ENet + RPCs de sesión + signals. **Sin** `class_name` (el autoload ya se llama `MpKit`). |
| `mp_ids.gd` | `class_name MpIds` — slot ↔ peer; rejoin reusa slot |
| `mp_lan.gd` | `class_name MpLan` — IPv4 |
| `mp_authority.gd` | `class_name MpAuthority` — authority, freeze, synchronizer |
| `plugin.cfg` | Visibilidad en el editor. El autoload real vive en `project.godot`. |

Estos archivos **no** nombran `GameSession`, `SceneDirector`, copy, `PlayerId` ni `submit_impulse`.

## Install

Canónico: `addons/mp_kit/` en [Joelnicolass/godot-studio-skills](https://github.com/Joelnicolass/godot-studio-skills).

```bash
./install.sh --addon /path/to/godot-project
```

O copiar esa carpeta a `res://addons/mp_kit/`. Autoload, **antes** del glue:

```
MpKit="*res://addons/mp_kit/mp_kit.gd"
```

`MpKit.configure(port, max_players, host_slot)` antes de `host()` / `join()`.

## Signals (el juego escucha)

- `peer_joined(peer_id, slot)` — aceptado y sloteado
- `peer_left(peer_id, slot)` — mapping limpio; el slot queda reservado para rejoin
- `join_failed` — el cliente no llegó
- `server_lost` — listen-server caído; el kit ya hizo `leave()`
- `client_world_ready(peer_id)` — el cliente registró spawners
- `load_world` — hay que abrir la escena de match
- `snapshot_received(data)` — `Dictionary` vuestro
- `session_ended(data)` — `Dictionary` vuestro
- `slot_assigned(slot)` — este cliente aprendió su slot

## RPCs del kit (lista cerrada)

Cliente → servidor: `rpc_world_ready`  
Servidor → clientes: `rpc_assign_slot`, `rpc_load_world`, `rpc_snapshot`, `rpc_session_ended`

Input de pawn **fuera** del kit.

## Métodos útiles

- `host() -> Error` / `join(address) -> Error` / `leave()`
- `is_networked()` / `is_server()`
- `local_slot()` / `peer_id_for(slot)` / `slot_for_peer(peer_id)`
- `request_world_ready()`
- `broadcast_load_world()` / `load_world_to(peer)`
- `push_snapshot(data)` / `push_snapshot_to(peer, data)`
- `broadcast_session_ended(data)`
- `is_peer_world_ready(peer_id)`

`rpc_load_world` es `call_remote`: el **host no lo recibe**. El host entra al mundo por glue.

## MpAuthority

```gdscript
MpAuthority.claim_server(node)           # authority = peer 1
MpAuthority.ensure_sync(node, PackedStringArray([".:position", ".:rotation"]))
MpAuthority.freeze_rigid_proxy(body)     # no-op si sos authority
MpAuthority.should_send_command()        # networked y no server
```

## MpLan

`MpLan.get_local_ipv4()` / `MpLan.is_valid_ipv4(ip)` para el lobby host.

## MpIds (contrato)

- Slot 1 = listen-server = ENet peer 1.
- Clientes: primer hueco en `2..max_players`.
- `unbind_peer` deja el slot en `0` (libre para rebind), no borra el cupo.
- `assign_client` reusa slot si el peer ya estaba, o rebind de slot vacío.

## Fallos que el kit ya cubre

| Fallo típico | Mitigación |
|--------------|------------|
| 1P abre puerto | `is_networked()` false hasta `host()`/`join()` |
| HUD usa unique_id | `local_slot()` |
| Spawn antes de escena cliente | `request_world_ready` |
| RigidBody cliente pelea con sync | `freeze_rigid_proxy` |
| `leave()` con peer null | `OfflineMultiplayerPeer` |
| Host se cae | `server_lost` |
| IP basura | `join_failed` |
