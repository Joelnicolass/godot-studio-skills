---
name: godot-mp-kit
description: >-
  Implementa multiplayer host-authoritative en Godot 4 con el addon informal
  MpKit (ENet, slots, handshake, snapshots) más el código del juego. Preguntá
  antes el tipo: sin MP (no copies el addon), local/WiFi (listen-server), u
  online (dedicated server, mismo proyecto, VPS). Usar al copiar addons/mp_kit,
  host/host_dedicated/join, RPCs submit_*, túnel Dictionary, MultiplayerSpawner,
  1P offline, rejoin, un juego por turnos o de cartas sin peones (MpOrders),
  export dedicated, scaffold de feature, o al extraer netcode a otro proyecto.
---

# Godot — MpKit y multiplayer

Un simulador (servidor). Los clientes mandan intenciones y pintan copias. El addon es pequeño a propósito: tubería reusable, cero gameplay.

Arquitectura: [godot-layered-architecture](../godot-layered-architecture/SKILL.md) (**preguntar** el tamaño: por entidad, el default, o sistemas + contenido; no crear carpetas sin respuesta). Nodos/FX/Resources: [godot-composition-first](../godot-composition-first/SKILL.md). Dedicated / VPS: [dedicated.md](dedicated.md).

## Alcance de red (obligatorio)

**Preguntar siempre** (`AskUserQuestion` en Claude Code / `AskQuestion` en Cursor, si está) **antes** de copiar el addon o de escribir RPCs. No asumas LAN.

| Elección | Qué hacer |
|----------|-----------|
| **Sin multiplayer** | No instales MpKit. Sin autoload, sin RPC, sin `MultiplayerSpawner`. |
| **Local / WiFi** (mismo dispositivo o misma LAN) | `MpKit.host()` listen-server. El proceso host **es** un jugador (slot 1 / peer 1). |
| **Online** (internet, VPS) | **Dedicated server** en el **mismo proyecto**. `MpKit.host_dedicated()`; clientes `join(ip)`. Peer 1 **no** es jugador. Desarrollá así desde el día uno (headless + clientes a `127.0.0.1`); la VPS es el mismo binario con IP pública y UDP abierto. Salas y varias partidas: **servidor de salas** (lobby + un dedicado por partida, ver abajo) para internet, o salas in-process (`MpKit.rooms` / `MpKit.matchmaker`) en un dedicated. Steam / WebRTC: solo si el producto los pide, **después**, no en lugar de dedicated. |

No preguntar de nuevo si el usuario ya eligió en este chat o el PRD/RULES lo declara.

Tipos de pawn/proyectil/enemigo: Resource `.tres` en el actor, no un RPC por `kind` string.

## Prioridades (siempre)

Siempre se priorice:

- arquitectura fácil de escalar, una carpeta por tema
- siempre tienen prioridad las estructuras de composicion
- siempre tienen prioirdad los nodos y las configuraciones sobre el editor
- siempre se debe dar prioridad a la reusabilidad de los componenetes

En red eso se traduce a:

| Prioridad | En MpKit / código del juego |
|-----------|-----------------|
| Capas | `addons/mp_kit` no nombra sesión, escenas, copy ni puntaje. Online = dedicated en el addon, no un `NetworkManager` del título. |
| Composición | Transport (kit) + código del juego + (`GameSession` **o** nodo Match) + actores con `submit_*`. |
| Editor | Spawners, replication config y escenas de pawn se arman como nodos. El kit no genera el mundo. |
| Reuso | Copiar el addon canónico. El juego escribe código del juego + dominio; no forks del kit por título. |

## Fuente canónica

El plugin es `addons/mp_kit/` **dentro del proyecto Godot**. Copiá esa carpeta tal cual a otro título. No forkearla por juego.

Si el addon del proyecto y una copia suelta divergen, gana `res://addons/mp_kit/` de este proyecto.

API: [kit-api.md](kit-api.md). Código del juego: [game-glue.md](game-glue.md). Dedicated: [dedicated.md](dedicated.md). Editor / túnel / scaffold: [editor.md](editor.md). Código genérico: [examples.md](examples.md).

Ejemplos del addon: `addons/mp_kit/examples/minimal_2d/` (lo que escribe *Setup game*: un menú, un mundo y un jugador predicho; abrí `boot.tscn` y F6), `examples/arena_2d/` (el completo) y `examples/sports_2d/` (un deportivo en tiempo real: dos contra dos, pelota, barrida predicha, quite con compensación de lag; GUIDE §7.8). Partí del mínimo y sumá lo que pide la feature; para un juego de pocos jugadores con pelota y contacto, partí de `sports_2d`.

Guía humana (inspector, paso a paso, túnel custom, servidor de salas, salas hub y cola): `addons/mp_kit/README.md`.

## Primero los nodos (human first)

El kit tiene que poder usarlo una persona **sin IA**. Por eso, en código nuevo, preferí siempre la capa de nodos; los `@rpc` / `submit_*` escritos a mano son el camino de bajo nivel (siguen funcionando y no se borran).

| Necesidad | Usá | No escribas |
|-----------|-----|-------------|
| Arrancar un juego MP | Tools → **MpKit: Setup game...** (muestra `[+]`/`[~]`, nunca pisa) | escenas de boot/mundo a mano desde cero |
| El juego en un lugar | **`MpGame`** (`game.tres`: la red y las escenas) en `MpFlow.game`; el menú, el lobby y el servidor de salas lo leen del flow | `configure()` sueltos, rutas repetidas en cada nodo |
| El mundo en red | un nodo **`MpWorld`** con `player_scene` (arma `SpawnPoints`, `Actors`, `Players`, `State`, `Match`, `Hud/Leave`, `Hud/Invite`, `Hud/Start`, `Hud/Waiting`) | cablear spawner, estado y partida a mano |
| Verbos de la partida desde cualquier script | **`Mp`**: `play_solo`, `host`, `join`, `leave`, `open_rooms`, `is_server`, `me`, `player`, `state`, `finish`, `net_quality` | buscar el `MpFlow` o el `MpMatch` a mano |
| Actor replicado | hijo **`MpActor`** (Sync en el inspector, arma y guarda `MpSync`) | `MultiplayerSynchronizer` armado a mano, `MpReplicate` en código nuevo |
| Quién simula, dentro de un nodo | `is_multiplayer_authority()` (el kit deja la autoridad en el servidor: verdadero en solo, host, dedicado) o `MpKit.is_authority()` / `Mp.is_server()` | `MpKit.is_server()` para reglas (falso en solo: es para lo que solo existe en red) |
| Quién mira esta pantalla | un **`MpLocalSeat`** en el mundo, pasado por `@export` a HUD / audio / órdenes (`slot`, `is_mine`, `preview_slot` en solo) | `local_slot()` repartido en cada script de UI |
| Algo que tiene que quedar (marcas, puertas, puntaje) vs un efecto de un instante | estado en Sync / `MpState` / un nodo spawneado (le llega al que carga después); efectos por `to_all`, o tu `@rpc` a `MpKit.ready_peers()` | un RPC de un instante para algo que tiene que quedar, o un «donante» que se lo reenvía al que vuelve |
| Una pantalla de carga que espera al mundo (shaders, precalentado) | `MpFlow.world_reports_loaded` + `report_world_loaded()` en el mundo, `world_load_progressed(ratio, phase)` para la pantalla; la puerta cuenta a cada peer cuando su mundo avisó (solo también) | una pantalla que solo tapa el cambio de escena mientras la partida ya corre |
| Un valor de la partida desde el inicio y en cada cambio | `MpState.watch(key, cb)` | `changed` + una primera lectura a mano, dependiente del orden |
| Spawnear desde cualquier peer | `MpSpawner.spawn_here(data)` (null en un cliente) | `if MpKit.is_server(): spawn(...)` por todos lados |
| Input del jugador | hijo **`MpInput`** + `input.get_vector(...)` en el servidor | un `submit_move` por frame |
| Movimiento sin lag | `MpActor.predict` + `func mp_move(input, delta)` (solo movimiento; efectos detrás de `not input.is_replaying()`) | predicción o rollback propios |
| Animación desde el movimiento (clip de correr, salto y caída, pasos) | `net.motion_speed()` / `net.motion_velocity()` (Vector2 en 2D, Vector3 en 3D; lo mismo en servidor, dueño y proxies; nunca una corrección que se desvanece) | velocidad estimada desde la pose del nodo frame a frame, una velocity sincronizada solo para animar |
| Una acción que mueve (dash, barrida, salto con contador) sin correcciones | dentro de `mp_move`: arranca con `keys.is_action_just_pressed`, cuenta sus ticks ahí, y todo lo que `mp_move` lee va en `sync_extra` (con predicción viaja con la pose) | arrancarla en `_physics_process`, o dejar su contador fuera de `sync_extra` |
| Un deportivo en tiempo real (pelota, quites, pocos jugadores) | `examples/sports_2d` y GUIDE §7.8: cada cosa que se mueve es un `MpActor` (la pelota del servidor, `BUFFERED`), la pelota propia dibujada en los pies predichos, el quite con `seen_position_of`, `start_seats` en 0 | un snapshot propio del estado entero cada N ticks con extrapolación, un `mp_move` que aproxima al motor o vuelve en el servidor, contactos contra el presente |
| Stun, ralentización, empujón sobre un jugador predicho | el servidor escribe valores que `mp_move` lee (`stun_ticks`, `knock`) listados en `sync_extra`; las correcciones se desvanecen solas (`correction_smoothing_s`), un warp: `net.snap()` en el servidor después de moverlo | mover el nodo del dueño desde el servidor a mano, suavizar correcciones por tu cuenta |
| Un juego de pelota donde el ping se siente como lag de las teclas, sin saltos | `predict` apagado en el jugador (el servidor lo mueve), `shared_timeline` en todo lo que se mueve, `adaptive_buffer` prendido, `max_extrapolate_s` en 0 si preferís una frenadita a una adivinanza (GUIDE §7.8, «Sin predicción») | un buffer fijo grande, actores con retrasos distintos, una cola de teclas propia |
| Objetos suaves (criaturas, otros jugadores) | `MpActor` con `smoothing = BUFFERED` (por defecto) | un `MultiplayerSynchronizer` sobre `position` + un lerp propio |
| Orden puntual del dueño | `net.to_server(&"x", args)` → `func mp_sv_x(args)` | `@rpc("any_peer")` + `accept_command` |
| Efecto en todos | `net.to_all(&"x", args)` → `func mp_all_x(args)` (solo el servidor) | `@rpc("authority")` propio |
| Score, reloj, ronda | **`MpState`** (`set_value`, `add`, señal `changed`) | `push_snapshot` + `snapshot_for_joiner` a mano |
| Un juego por turnos, de cartas o de tablero (sin peones), o las órdenes de un RTS | un `MpWorld` **sin Player Scene** + un **`MpOrders`**: `submit(name, args)`, `judge` en el servidor (`""` o el motivo), `applied(seq, slot, name, args)` en todos, `rejected` solo al que la mandó, `begin(start)` con la semilla; el que carga tarde o vuelve recibe todas las jugadas (`is_replaying()`); `state_hash` → `desynced`. `examples/turns_2d`, GUIDE §7.9 | un `MpActor` invisible por asiento con su spawner, un historial y una reconexión propios sobre el túnel |
| Algo que solo ve un jugador (su mano, su munición, su objetivo) | **`MpSeatState`**: `set_value(slot, key, value)` en el servidor, `watch(key, cb)` en la máquina del asiento; le vuelve a llegar al que carga o vuelve y lo hereda quien tome el asiento (GUIDE §7.12) | un canal privado propio sobre el túnel, o datos secretos en `MpState` (los ven todos) |
| Probar online en tu PC (emisor y relay locales) | `bash addons/mp_kit/deploy/online_local.sh <game_id>`; cada copia con `--issuer-url=` y su `--issuer-install=`; el build web con `?issuer=http://127.0.0.1:8891` (GUIDE §10.4) | apuntar pruebas al emisor de producción, o un script propio que levanta los dos |
| Saber qué pasó con cada asiento (depurar) | `--seat-log` en el servidor (o `MpMatch.log_seats`): «MpKit seats: seat 2 in / loaded / away / back / abandoned» | prints propios escuchando la puerta |
| Que un jugador de LAN vuelva a su asiento después de cerrar el juego | `MpFlow.remember_seats` (o `--remember-seats`; dos copias en una PC: `--seat-file=`) | guardar la credencial a mano |
| Bots en los asientos libres | **`MpSeatBots`** con tu `bot_scene` (declara `slot`, `pawn`, `input`): bots al arrancar y al abandonarse un asiento, se van cuando entra un jugador, nunca en un asiento cerrado (GUIDE §7.5) | un relleno propio que escucha la puerta |
| Mandarle algo propio al que carga tarde o vuelve | `MpKit.client_world_ready(peer_id)` + `MpKit.push_custom_to(peer_id, canal, datos)` (GUIDE §7.10) | `to_all` / `broadcast_custom` para algo que tiene que quedar: no le llega al que carga |
| Quién mandó un mensaje del túnel | `MpKit.slot_of_sender(from_peer)` (igual en solo, host y cliente) | `slot_for_peer(from_peer)` (da 0 en solo) o un asiento dentro de los datos |
| Inicio y fin de partida | **`MpMatch`** (`all_loaded`, `player_abandoned`, `finish(result)`) | código propio de tickets y abandonos |
| Salas online | **`MpRoomServer`** + `MpLobbyConfig` + `MpRoomRules`; cliente **`MpLobbyScreen`** | `Callable`s del lobby cableados a mano |
| Partida privada en la PC | `MpLocalServer` / `MpBootMenu.offer_private_server`; el HUD muestra `ip:puerto#CÓDIGO` (`MpInviteLabel`) | un launcher propio |
| Que los jugadores hospeden partidas online, sin servidor tuyo (también web) | `flow.host_online()` / `join_online(code)` / `online_rooms()` + el emisor (`addons/mp_kit/issuer`) y el relay; `issuer_url` + `game_id` en `MpNetConfig` (GUIDE 10.3) | meter el secreto del relay en los clientes, un matchmaker propio |
| Saber que el host se congeló o se le trabó la conexión | `MpKit.host_silent(seconds)` / `host_back` (`MpFlow.host_silent_status`) | pings propios |
| Disparos con ping | `MpActor.lag_compensate` + `net.rewound(func)` / `net.seen_position_of(nodo)` / `net.view_lag()` | validar contra el presente |
| Mostrar la calidad de la conexión | `Mp.net_quality()` (RTT, jitter, pérdida, `grade_name`) | pings propios |
| Sin IP pública | `transport = relay` + `relay/server.mjs` (Railway u otro host), secreto en `MPKIT_RELAY_SECRET` | abrir puertos o un túnel propio |
| Subir a un VPS | `addons/mp_kit/deploy/deploy.sh usuario@vps build --rooms 7700` | unidades systemd por juego |
| Un servidor sin VPS | `addons/mp_kit/deploy/fly.sh --app NOMBRE --relay-url wss://…` (Fly.io, detrás del relay, sin export; GUIDE 13.6) | un Dockerfile propio |
| Probar con red mala | `--net-lag-ms=100 --net-jitter-ms=30 --net-loss=0.05` en cada proceso | suponer LAN perfecta |

Guía humana: `addons/mp_kit/QUICKSTART.md` (la corta), `addons/mp_kit/GUIDE.md` (paso a paso), `addons/mp_kit/deploy/README.md`, `addons/mp_kit/relay/README.md` y `addons/mp_kit/issuer/README.md`. Laboratorio sin juego: `mpkit_lab/run/all.sh` y `mpkit_lab/CASES.md`. Tests propios del kit: `godot --headless --path <proyecto> --script res://addons/mp_kit/tests/mp_test_runner.gd`.

Reglas que no se rompen:

- Web y escritorio no se mezclan: un export web usa WebSocket (directo, o por el relay); nunca hostea una partida LAN ni un servidor de salas. Sí puede hospedar una sala de jugadores (`host_online()` por el emisor y el relay; `MpWebKeepAlive` la mantiene corriendo con la pestaña oculta).
- El secreto del relay nunca viaja en un cliente: un jugador que hospeda recibe un token de un solo uso del emisor (salas `p-<código>`).
- Los buffers de red son adaptativos (percentil 97 de la red medida): no los fijes a mano salvo para acotarlos (`buffer_delay_s` es el tope).
- `MpFlow` y los nodos del mundo nunca nombran clases del lobby (`MpMatchAgent`...): grupo o `load()` por ruta. Si no, un juego con el lobby como autoload forma un ciclo de carga.
- No agregues un miembro a `MpFlow` / `MpSpawner` con el nombre de uno de una subclase del juego: grepeá las subclases antes.

## Arranque en 5 pasos

1. Copiá `addons/mp_kit/` y enable **MpKit** (autoload `MpKit`).
2. Tools → **MpKit: Setup game...**, o a mano: un **`MpGame`** (`game.tres`, red y escenas) y un nodo **`MpFlow`** en la escena de boot con `game` = ese `.tres` (se muda solo a la raíz), más `mp_boot_menu.tscn`.
3. En el mundo: un nodo **`MpWorld`** con `player_scene` (arma spawner, `MpState` y `MpMatch`). A mano, si el mundo ya tiene su estructura: `MpSlotSpawner` (`spawn_path`, `pawn_scene`, `spawn_points`), `MpState` y `MpMatch`. El spawner retiene los synchronizers hasta que cada cliente está listo.
4. Jugador: hijos `MpActor` (predict) + `MpInput`; movimiento en `mp_move`, reglas detrás de `net.is_authority()`, llamadas `mp_sv_*` / `mp_all_*`.
5. LAN: Host LAN / Unirse. Online: dedicated (`--dedicated`) o salas (`MpRoomServer`, `--room-server`), con IP pública o por el relay; no `host()` detrás de NAT sin relay.

## Qué es el kit / qué no

Copiar `addons/mp_kit/` → autoload `MpKit`.

**Hace:** ENet listen o dedicated, mapa slot ↔ peer, cupo, handshake `world_ready`, push de `Dictionary` opaco (snapshot **y** túnel `send_custom`), signals, nodos de replicación, `MpBoot`. Opcional: `MpFlow` (escenas host/join/1P, no reglas). Opcional: salas hub in-process (`MpRoomDirectory` + cola FIFO `MpMatchmaker`) en un dedicated. Opcional: servidor de salas (`lobby/`), admisión por ticket y transporte WebSocket.

**No hace:** score, copy de un título, input de actor, predicción, Steam/WebRTC, “cuándo gana alguien”. `MpReplicate.interpolate` es un lerp opcional de proxy, no rollback.

Si metés puntaje en `mp_kit.gd`, el kit deja de ser portable.

## Servidor de salas (online, un dedicado por partida)

Vive en `addons/mp_kit/lobby/`, genérico (sin reglas ni textos de juego). Resumen:

- **Servidor de salas** (`--room-server`): `MpLobby.start_server(config, launcher)`. Los clientes hacen `MpLobby.connect_to(host, port, nombre)`, crean o se unen a salas, eligen, marcan listo y chatean; el cliente nunca elige slot, puerto ni semilla. `MpLobbyConfig` (`.tres`, cada número se pisa con `--nombre-con-guiones=N`) guarda límites y tiempos.
- **Tickets**: al terminar la cuenta regresiva el `ticket_builder` del juego devuelve el ticket; `MpMatchLauncher.launch(id, ticket)` elige un puerto libre, guarda solo `sha256(token)` y lanza un dedicado con `--match-ticket-file`. El cliente recibe `match_ready(host, port, token)` y hace `MpKit.join(host, port, token)`. En el dedicado `MpMatchAgent` fija `MpKit.admission` desde el ticket: un ticket ajeno, inventado, vencido o ya conectado se rechaza.
- **Launcher**: un proceso por partida, tope `max_matches` (`ERR_BUSY`), latido en `state.json`, resultado en `result.json` (`MpMatchAgent.report_result`), mata partidas sin latido, demasiado largas o huérfanas. El juego inyecta `meta_validator`, `options_validator` y `ticket_builder`; el kit queda sin reglas ni textos.
- **Reconexión**: lobby `MpLobbyClient.resume()` / `auto_resume` (misma sesión y asiento, `resume_grace_s`); partida: el mismo ticket (salas) o la credencial de asiento que dio el servidor (LAN, dedicado a mano) dentro de `rejoin_grace_s` devuelve el slot (el juego decide qué conserva). Una credencial que vuelve tras una caída gana sobre la conexión vieja. Sin late join por defecto: la puerta de arranque (`MpMatchGate`) rechaza al que llega después del arranque (`match_started`); `late_join` (`MpFlow`, `--late-join`) deja abiertos los asientos que nadie ocupa, también en una sala online o privada en la PC del host (`joined_late(slot)` avisa). `start_on_timeout` apagado: la partida espera a todos o a que el host la arranque (Start now, `MpStartButton`; en una partida en la PC del host, con `host_can_start`). `pause_while_waiting` apagado (`--pause-while-waiting=false`): un lobby que se camina; nadie se pausa mientras espera, los que cargaron mueven su peón con predicción, y el juego frena sus propios sistemas (reloj, amenazas, bots) hasta el arranque con `MpMatch.waiting` / `waiting_changed` / `all_loaded`. `Mp.gate().close_seat(slot)`: el peón de ese asiento murió o escapó, nadie vuelve a sentarse ahí (ni su jugador: `seat_closed`). `stay_after_finish_s` (`MpFlow`, grupo Match end): una partida terminada en la PC del host espera a que sus jugadores salgan de la pantalla de fin (`leave_match()`); el servidor que se va después del final es `MpKit.server_closed`, nunca `server_lost`. Todo apagado por defecto. Ejemplo: `examples/bots_2d/`. Bots en asientos libres: tu IA en el servidor, con `Mp.gate().vacant_slots()`, `MpSlotSpawner.spawn_slot(slot)` y las teclas de `MpInput.bot_press` (mismo `mp_move` que un jugador; el que entra toma ese peón tal cual). Un dedicado a mano sirve una partida tras otra (mundo nuevo cuando la partida terminó y se fueron todos, o `all_gone`).
- **Transporte**: `--transport=enet|ws` (`MpLobbyConfig.transport`), igual en cliente, servidor de salas y dedicado. ENet es UDP (por defecto); WebSocket es TCP (web, túneles TCP). `wss://` con proxy inverso.
- Prueba local: dos salas 1v1 en paralelo con dos dedicados reales, headless, repetida (soak) y buscando procesos huérfanos. Detalle: `addons/mp_kit/README.md` (Servidor de salas).

## Modelo obligatorio

```
[Jugar solo]     no llames host(); OfflineMultiplayerPeer; local_slot() == host_slot
[Host LAN]       MpKit.host()
[Dedicated]      MpKit.host_dedicated()     local_slot() == 0
[Cliente]        MpKit.join(ip)
```

- **Slot** estable: key de vidas/score/HUD. Listen: slot 1 = jugador host. Dedicated: slots 1..N = solo clientes.
- **Peer id** volátil: validar RPCs con `MpKit.peer_id_for(slot)`. Nunca `get_unique_id()` como id de jugador. Peer 1 en dedicated **no** es un slot.

Cliente: `apply_snapshot` **apaga** el tick de simulación de la sesión. El guest no tiquea el reloj. Dedicated sí simula (es el servidor).

## Input y autoridad (bajo nivel)

En código nuevo, la entrada del jugador es su `MpInput` y una orden puntual es `net.to_server(&"x")` (tabla de [Primero los nodos](#primero-los-nodos-human-first)). Esto es el camino a mano, para lo que los nodos no cubren.

Actores: el servidor es authority. Si el body es `RigidBody2D`/`RigidBody3D`, los proxies se freezan (`MpAuthority.freeze_rigid_proxy`). No asumas RigidBody en todo pawn.

```
if MpAuthority.should_send_command():
    pawn.submit_x.rpc_id(1, payload)
else:
    pawn.apply_x(payload)
```

RPC en **tu** pawn, no en el kit: el cliente pide algo y el servidor lo valida antes de aplicarlo:

```gdscript
@rpc("any_peer", "call_remote", "reliable")
func submit_x(payload) -> void:
	if not MpAuthority.accept_command(self, player_slot):
		return
	apply_x(payload)
```

- Allowlist de `submit_*`. No `rpc add_score`.
- No `call_local` en comandos de cliente (duplica spawn/daño).
- Áreas de daño: `monitoring = is_multiplayer_authority()`.
- Dedicated nunca manda `submit_*` (no hay jugador local).

## Handshake de spawn (obligatorio)

El `MultiplayerSpawner` de Godot replica hijos en `peer_connected`, cuando el cliente **sigue en el lobby**; la ruta falla y Godot no la reintenta, así que ese spawner (o nodo estático con sync) queda muerto para ese peer. `MpSpawner` (default `hold_until_world_ready`) usa la visibilidad por peer del `MultiplayerSynchronizer`: todo lo que le pertenece en la escena queda oculto y cada peer se revela cuando su propia copia del spawner avisa que está lista; recién ahí Godot manda spawn + sync emparejados. Los actores sin synchronizer reciben un `MpSpawnGate` vacío (si no, Godot los manda a todos).

```
Server broadcast_load_world() + el código del juego carga el mundo en el proceso servidor
  → listen host add_child(pawn local) en _ready; nace oculto para peers no listos
  → cliente carga escena; MpSpawner pide request_world_ready() + rpc_spawner_ready (deferred)
  → el MpSpawner del servidor revela al peer (set_visibility_for) → Godot manda spawn + sync
  → MpSlotSpawner (o el código del juego) spawnea el slot que acaba de entrar
```

No desparentes actors en el código del juego: el kit ya revela por peer. Los synchronizers van en la escena (o se agregan antes del `add_child` / en el `_ready` del actor), nunca diferidos. Salas hub: un subárbol + `MpSpawner` por sala con `room_id` (README → Actores por sala).

Identidad del actor (`player_slot`, etc.): propiedades del `MultiplayerSynchronizer` con `spawn = true`, o el nombre (`Pawn_2` / `Ship_2`).

FX locales (post-process, atmósfera) se arman en `_ready` **también en el cliente**, antes del `return` del guest.

Rejoin: no resetear score; snapshot + `load_world_to`. `MpSpawner` revela de nuevo al nuevo peer id.

## Snapshots vs transforms

- Posición/rotación/visible: `MultiplayerSynchronizer` en la escena (Wire replication), o `MpAuthority.ensure_sync` antes del `add_child`.
- Timer/score/vidas: `to_snapshot()` a 2–10 Hz vía `MpKit.push_snapshot` (Timer, no cada frame de `_process`).
- Eventos discretos (`+N` flotante): RPC `authority` en un nodo **vuestro**, no en MpKit.

No metas 40 posiciones de props en el dict si ya van por synchronizer.

## 1P

Mismo código de colisión y `submit_*` (el host local no manda RPC). Probar siempre jugar solo **sin** `create_server`.

## Anti-patrones

- Cliente spawnea / `queue_free` / suma puntos.
- `PlayerId` o `GameSession` importados desde `mp_kit.gd`.
- Arrancar spawn en el mismo frame que `change_scene` del invitado (el kit lo cubre; no lo “arregles” unparenteando en el código del juego).
- `leave()` dejando `multiplayer_peer = null` (el kit pone `OfflineMultiplayerPeer`).
- Tercer peer aceptado en silencio (el kit debe `disconnect_peer` al exceder cupo; la política de “sala llena” es código del juego + kit).
- HUD que muestra el score del host porque usó peer id 1.
- Dedicated con pawn para sí, o desarrollar online como listen-server.
- Fingir que `host()` LAN detrás de NAT es online.
- Auto-broadcast del túnel custom (el servidor debe elegir).
- Meter reglas de juego o `kind` de bala en el dict del túnel.
- Un RPC propio que manda el estado entero del partido cada N ticks y un cliente que lo pega y lo extrapola: los cuerpos y la pelota son `MpActor` y se dibujan `BUFFERED`.
- Un `mp_move` que aproxima el movimiento del servidor, o que vuelve sin mover en el servidor mientras otro código lee las teclas en vivo: la predicción y el servidor nunca coinciden. El movimiento es uno solo, en `mp_move`, también en el servidor.
- Leer la pose de un nodo de red en `_process` antes que el kit (`process_priority` de 10000 o menos): se ve sin la corrección suavizada, a saltos.
- Arrancar el partido a mano cuando carga el host, o `start_seats` en 1 en una partida por equipos: la puerta ya espera a todos (`MpMatch.all_loaded`).

## Checklist

- [ ] Tipo de MP declarado (ninguno / local-WiFi / online). Sin MP: este checklist no aplica.
- [ ] Autoload `MpKit` **antes** del código del juego. `configure(port, max_players)` antes de host/join.
- [ ] `MpFlow` (nodo en el boot, autoload o `extends MpFlow`) con un `MpGame` (`game.tres`), o un `MpNetConfig` más rutas. El mundo con un `MpWorld`, salvo que ya tenga su estructura. Varios mapas: `add_world` + `select_world`. Código extra solo si hay copy o túnel.
- [ ] Actores nuevos con `MpActor` + `MpInput` (predict para el jugador); estado de partida en `MpState`; fin en `MpMatch.finish`. Sin `@rpc` a mano salvo un caso que la capa de nodos no cubra (anotalo).
- [ ] Online: `MpBoot` + `host_dedicated()`; clientes `join`; export dedicated; spawn solo `occupied_slots()`. Varios jugadores por partida por internet: servidor de salas + tickets (`MpMatchLauncher`), no un `join(ip)` libre. Hub opcional: `MpKit.rooms` / `MpKit.matchmaker` en el mismo proceso; el puntaje sigue fuera del addon.
- [ ] Slots en dominio; peers solo en RPC/authority.
- [ ] `MpSpawner` o `MpSlotSpawner` con `hold_until_world_ready` (default). El cliente no necesita `MpWorldReady`. No restage de pawns en el código del juego.
- [ ] Guest no simula reglas; servidor valida sender.
- [ ] 1P offline verificado.
- [ ] Pawns son packed scenes componibles, no lógica de red incrustada en el kit.
- [ ] Features nuevas: un actor con `MpActor` (+ `MpInput`), con Tools › *Make selection a network actor* o `/new-mp-feature`; jugadas de un juego sin peones con `MpOrders`; túnel solo para lo que no cubren `to_server` / `to_all` / `Mp.state()` / `MpOrders`.
