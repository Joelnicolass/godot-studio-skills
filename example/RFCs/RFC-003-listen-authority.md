# RFC-003 — Listen-server y autoridad

**Complejidad:** Medium  
**Predecesores:** RFC-002  
**Sucesores:** RFC-004  
**Features:** F9, F10, F11, F12, F16

**Tipo:** juego Godot. Omitido: SQL, auth, browsers.

## Resumen

Host LAN y Join. Handshake de spawn. `submit_move` / `apply_move` host-authoritative. `MpReplicate` ya en pawns. Salir y `server_lost` / `join_failed`.

Dedicated **no** se implementa aquí (RFC-004). El botón Host usa `MpKit.host()`, no `host_dedicated()`.

## Archivos

```
example/glue/net_glue.gd           # host_lan, join_lan, peer_joined, load_world, signals
example/scenes/ui/boot.gd          # Host, Join, IP, mensajes error
example/scenes/ui/boot.tscn
example/glue/demo_copy.gd          # HOST, JOIN, BAD_IP, JOINING, JOIN_FAIL, SERVER_LOST, HOST_FAIL
example/scenes/world/demo_match.gd # world_ready, peer_left, listen host spawn
example/scenes/actors/pawn_2d.gd   # submit_move
example/scenes/actors/pawn_3d.gd   # submit_move
example/scenes/ui/match_hud.gd     # Salir (mínimo; HUD rico es RFC-004)
example/scenes/ui/match_hud.tscn   # o Control en cada match
```

## Política de arranque (PRD)

```
host_lan → MpKit.host() → match_running=true → broadcast_load_world → goto_world
peer_joined + match_running → load_world_to(peer)
join → MpKit.join(ip) → esperar load_world
```

Listen host spawnea su pawn en `DemoMatch._ready`. Clientes: `MpWorldReady` → `client_world_ready` → `ensure_pawn(slot)`.

## RPCs (en el pawn, no en el kit)

```gdscript
func try_move(dir: Vector2) -> void:
	if MpAuthority.should_send_command():
		submit_move.rpc_id(1, dir)
	else:
		apply_move(dir)

@rpc("any_peer", "call_remote", "reliable")
func submit_move(dir: Vector2) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != MpKit.peer_id_for(player_slot):
		return
	apply_move(dir)
```

Input solo si `player_slot == MpKit.local_slot()` y `local_slot() != 0`.

## Criterios de aceptación

1. Host LAN: el host entra al mundo y controla pawn slot 1.
2. Segundo proceso Join `127.0.0.1`: carga el mismo `world_kind`, dos pawns, looks distintos, sin actor duplicado por peer.
3. El cliente **no** aplica movimiento local como autoridad: el cuerpo se mueve porque el server `apply_move` + `MpReplicate`/synchronizer.
4. IP inválida no llama `join`; muestra `DemoCopy.STATUS_BAD_IP`.
5. `join_failed` y `server_lost` vuelven a boot con mensaje.
6. Botón Salir en match: `leave` + boot (1P y listen).
7. `peer_left`: el pawn de ese slot se `queue_free`; el slot queda reservado por el kit.
8. Late join: si `match_running`, solo `load_world_to` ese peer; no se reinicia el host.
9. `MpSpawner` tiene la packed scene del pawn en spawnables **antes** del primer `add_child`.
10. No `call_local` en `submit_move`. No RPC de score.
11. No `host_dedicated`, no `--dedicated`, no snapshot periódico, no emote de red (RFC-004).

## Errores

Puerto ocupado → `STATUS_HOST_FAIL`. No crash.

## Testing manual

Dos instancias editor: Host + Join. Mover ambos. Matar host → cliente a lobby. 1P sigue funcionando.

## Reglas aplicables

RULES §4 listen, handshake, submit, F9–F12, F16.
