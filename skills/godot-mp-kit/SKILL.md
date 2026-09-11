---
name: godot-mp-kit
description: >-
  Implementa multiplayer host-authoritative en Godot 4 con el addon informal
  MpKit (ENet, slots, handshake, snapshots) más glue del juego. Usar al copiar
  addons/mp_kit, host/join LAN, RPCs submit_*, MultiplayerSpawner, 1P offline,
  rejoin, autoridad de RigidBody, o al extraer netcode a otro proyecto.
---

# Godot — MpKit y multiplayer

Patrón listen-server: **un simulador (host)**. El invitado manda intenciones y pinta copias. El addon es pequeño a propósito: tubería reusable, cero gameplay.

Arquitectura de capas: [godot-layered-architecture](../godot-layered-architecture/SKILL.md). Nodos/FX: [godot-composition-first](../godot-composition-first/SKILL.md).

## Prioridades (siempre)

Siempre se priorice:

- arquitectura facil de escalar y limpia en capas
- siempre tienen prioridad las estructuras de composicion
- siempre tienen prioirdad los nodos y las configuraciones sobre el editor
- siempre se debe dar prioridad a la reusabilidad de los componenetes

En red eso se traduce a:

| Prioridad | En MpKit / glue |
|-----------|-----------------|
| Capas | `addons/mp_kit` no nombra sesión, escenas, copy ni puntaje. Dedicated server futuro = reemplazar el addon. |
| Composición | Transport (kit) + glue (cuándo empieza la ronda) + `GameSession` + pawns con `submit_*`. No un `NetworkManager.gd` de 2000 líneas. |
| Editor | Spawners, replication config y escenas de pawn se arman como nodos. El kit no genera el mundo. |
| Reuso | Copiar `addons/mp_kit/` tal cual. El juego nuevo escribe glue + dominio, no fork del kit “porque este título dispara”. |

## Qué es el kit / qué no

Copiar `addons/mp_kit/` → autoload `MpKit`. API: [kit-api.md](kit-api.md). Glue: [game-glue.md](game-glue.md).

**Hace:** ENet host/join/leave, mapa slot ↔ peer, cupo, handshake `world_ready`, push de `Dictionary` opaco, signals de sesión.

**No hace:** score, combo, `change_scene`, copy, input de pawn, interpolación avanzada, Steam/WebRTC, “cuándo empieza la partida”.

Si metés puntaje en `mp_kit.gd`, el kit deja de ser portable.

## Modelo obligatorio

```
[Jugar solo]   no llames host(); OfflineMultiplayerPeer; local_slot() == host_slot
[Host LAN]     MpKit.host()
[Cliente]      MpKit.join(ip)
```

- **Slot** estable: key de vidas/score/HUD. Slot 1 = listen-server.
- **Peer id** volátil: validar RPCs con `MpKit.peer_id_for(slot)`. Nunca `get_unique_id()` como id de jugador.

Cliente: `apply_snapshot` **apaga** el tick de simulación de la sesión. El guest no tiquea el reloj.

## Input y autoridad

Pawns: el servidor es authority. Proxies `RigidBody2D` se freezan en kinematic (`MpAuthority.freeze_rigid_proxy`).

```
if MpAuthority.should_send_command():
    pawn.submit_x.rpc_id(1, payload)
else:
    pawn.apply_x(payload)
```

RPC en **tu** pawn, no en el kit:

```gdscript
@rpc("any_peer", "call_remote", "reliable")
func submit_x(payload) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != MpKit.peer_id_for(player_slot):
		return
	apply_x(payload)
```

- Allowlist de `submit_*`. No `rpc add_score`.
- No `call_local` en comandos de cliente (duplica spawn/daño).
- Áreas de daño: `monitoring = is_multiplayer_authority()`.

## Handshake de spawn (obligatorio)

`MultiplayerSpawner` tira paquetes si el cliente aún no registró spawnable scenes.

```
Host broadcast_load_world()
  → cliente carga escena, registra spawners, MpKit.request_world_ready()
  → host espera client_world_ready
  → recién ahí add_child(pawn, true)
```

FX locales (post-process, atmósfera) se arman en `_ready` **también en el cliente**, antes del `return` del guest.

Rejoin: no resetear score; snapshot + `load_world_to` + re-parent de hijos del spawner si hace falta reenviar.

## Snapshots vs transforms

- Posición/rotación/visible: `MultiplayerSynchronizer` (`MpAuthority.ensure_sync`).
- Timer/score/vidas: `GameSession.to_snapshot()` a 2–10 Hz vía `MpKit.push_snapshot`.
- Eventos discretos (`+N` flotante): RPC `authority` en un nodo **vuestro**, no en MpKit.

No metas 40 posiciones de asteroides en el dict si ya van por synchronizer.

## 1P

Mismo código de colisión y `submit_*` (el host local no manda RPC). Probar siempre jugar solo **sin** `create_server`.

## Dedicated server más adelante

Reemplazar este addon (o el transport dentro de `host()`/`join()`). Dominio y RPCs `submit_*` de los pawns se quedan.

## Anti-patrones

- Cliente spawnea / `queue_free` / suma puntos.
- `PlayerId` o `GameSession` importados desde `mp_kit.gd`.
- Arrancar spawn en el mismo frame que `change_scene` del invitado.
- `leave()` dejando `multiplayer_peer = null` (el kit pone `OfflineMultiplayerPeer`).
- Tercer peer aceptado en silencio (el kit debe `disconnect_peer` al exceder cupo; la política de “sala llena” es glue + kit).
- HUD que muestra el score del host porque usó peer id 1.

## Checklist

- [ ] Autoload `MpKit` **antes** del glue. `configure(port, max_players)` antes de host/join.
- [ ] Glue propio: cuándo `start_match`, copy, escenas. Kit intocado.
- [ ] Slots en dominio; peers solo en RPC/authority.
- [ ] Handshake `world_ready` antes del primer `add_child` replicado.
- [ ] Guest no simula reglas; host valida sender.
- [ ] 1P offline verificado.
- [ ] Pawns son packed scenes componibles, no lógica de red incrustada en el kit.
