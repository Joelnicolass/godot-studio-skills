# FEATURES — MpKit Example

**Producto (según PRD):** demo Godot 4.7 que enseña MpKit + skills (estándar, composición, Resources) con 1P, listen-server y dedicated; match 2D y 3D con placeholders. No es un juego real.

Los IDs son **permanentes**. No renumerar.

## Resumen (recontado del listado)

| Prioridad | Cantidad |
|-----------|----------|
| Must have | 16 |
| Should have | 2 |
| Could have | 0 |
| Won't have | 5 |
| **Total** | **23** (F1–F23) |

| Categoría | Must | Should | Could | Won't | IDs |
|-----------|------|--------|-------|-------|-----|
| Lobby / flow | 5 | 0 | 0 | 0 | F1, F2, F9, F10, F16 |
| Mundo 2D | 2 | 0 | 0 | 0 | F3, F4 |
| Mundo 3D | 2 | 0 | 0 | 0 | F6, F7 |
| Composición / datos | 2 | 0 | 0 | 0 | F5, F8 |
| Red | 5 | 0 | 0 | 0 | F11–F15 |
| Guía | 0 | 2 | 0 | 0 | F17, F18 |
| Fuera de alcance | 0 | 0 | 0 | 5 | F19–F23 |

Persona: desarrollador que aprende el framework (todas las Must).

---

## Must have

### F1 — Lobby (boot)

UI de entrada: título, toggle 2D/3D, Jugar solo, Host LAN, campo IP, Unirse, IP local LAN, estado. Copy vía `DemoCopy` (idioma del producto).

- **Aceptación:** F5 abre `boot.tscn`. Los botones no crashean sin red. Dedicated headless no muestra el lobby (NetGlue host_dedicated y espera).
- **Técnico:** `scenes/ui/boot.tscn` + `boot.gd`. Input no se lee aquí.
- **Límites:** sin menús extra (opciones, créditos).

### F2 — Jugar solo (1P)

No llama `MpKit.host()`. `MpKit.leave()` deja `OfflineMultiplayerPeer`. Carga el match del `world_kind` actual.

- **Aceptación:** un pawn en slot `MpKit.local_slot()` (host_slot, default 1). Movimiento local sin RPC.
- **Técnico:** `NetGlue.play_solo()`.
- **Límites:** no hay “servidor fantasma”.

### F3 — Match 2D

Escena 2D con fondo placeholder, `Camera2D`, contenedor `Actors`, `MpSpawner` (`spawn_path` → Actors), `MpWorldReady` **después** del spawner, markers de spawn, HUD canvas.

- **Aceptación:** F6 instancia un pawn offline. No depende de un autoload de puntaje.
- **Técnico:** `scenes/world/match_2d.tscn`.
- **Límites:** sin tilemaps ni enemigos.

### F4 — Pawn 2D

`CharacterBody2D` delgado: visual `Sprite2D` + `PlaceholderTexture2D`, colisión, `MpReplicate`, hijo de input, badge. Movimiento WASD/flechas.

- **Aceptación:** F6 mueve el pawn. `player_slot` `@export`. Look inyectado (`ActorLook`).
- **Técnico:** `scenes/actors/pawn_2d.tscn`. InputMap, no `KEY_*`.
- **Límites:** sin salto complejo ni armas.

### F5 — Resource `ActorLook`

`class_name ActorLook` + `.tres` por slot (tint, badge, `move_speed`). Una escena de pawn, N looks. No `if kind`.

- **Aceptación:** slot 1 y 2 se distinguen de color/badge sin ramas en el pawn.
- **Técnico:** `resources/looks/actor_look.gd` + `look_a.tres`…`look_d.tres`.
- **Límites:** no mutar el `.tres` en runtime.

### F6 — Match 3D

Igual contrato que F3 en 3D: piso `BoxMesh`/`StaticBody3D`, `Camera3D`, luz, `Actors`, `MpSpawner`, `MpWorldReady`, markers.

- **Aceptación:** F6 muestra el piso y un pawn (si el match spawnea offline). Placeholders, no `.glb`.
- **Técnico:** `scenes/world/match_3d.tscn`.
- **Límites:** sin animación de cámara.

### F7 — Pawn 3D

`CharacterBody3D` + `BoxMesh` + colisión + `MpReplicate` + input. Movimiento en XZ. Gravedad simple.

- **Aceptación:** F6 añade cámara/piso de preview si la escena es current. WASD mueve.
- **Técnico:** `scenes/actors/pawn_3d.tscn`.
- **Límites:** sin mesh de personaje.

### F8 — Nodo `DemoMatch` (spawn / handshake)

Componente hijo de ambos mundos: spawnea `occupied_slots()` (o slot local en 1P), coloca en markers, asigna look, `add_child(..., true)`. Listen host spawnea su pawn en `_ready`. Clientes: al `client_world_ready`. Dedicated: **no** pawn para slot 0.

- **Aceptación:** 1P y listen-solo-host ven un pawn; dedicated sin clientes no spawnea; cada cliente listo recibe su pawn.
- **Técnico:** `scenes/world/demo_match.gd`. `@export` pawn_scene, actors, spawn_points, looks.
- **Límites:** no puntúa.

### F9 — Host LAN

`MpKit.host()` listen-server. El proceso host **es** jugador (slot 1 / peer 1). Arranca el match de inmediato (política de demo).

- **Aceptación:** el host entra al mundo y controla un pawn. `broadcast_load_world` + glue `goto_world` (el server no recibe el RPC).
- **Técnico:** `NetGlue.host_lan()`.
- **Límites:** no es “online”.

### F10 — Join

`MpKit.join(ip)` tras validar IPv4 con `MpLan`. Espera `load_world`.

- **Aceptación:** IP inválida → mensaje, no `join`. Join ok → misma escena que el host. Late join con match vivo → `load_world_to`.
- **Técnico:** `NetGlue.join_lan(ip)`.
- **Límites:** sin scan de red.

### F11 — Autoridad `submit_*` / `apply_*`

Cliente: `submit_move.rpc_id(1, dir)` si `MpAuthority.should_send_command()`. Server / 1P: `apply_move`. RPC `any_peer` + `call_remote`; validar `get_remote_sender_id() == MpKit.peer_id_for(player_slot)`. Solo el pawn de `local_slot` lee input.

- **Aceptación:** el guest no mueve un pawn ajeno; el dedicated no manda submit (no hay jugador local).
- **Técnico:** en `pawn_2d.gd` / `pawn_3d.gd`.
- **Límites:** sin predicción.

### F12 — Replicación de transform

Hijo `MpReplicate` (authority peer 1, sync position/rotation/visible). El kit puede crear `MultiplayerSynchronizer` en runtime.

- **Aceptación:** el pawn del host se ve mover en el cliente (LAN).
- **Técnico:** nodo kit, no un `NetworkPlayer` monolítico.
- **Límites:** no clonar el dock Replication de Godot.

### F13 — Dedicated

`MpBoot.is_dedicated_process()` → `MpKit.host_dedicated()`. Peer 1 no es jugador. Arranque al primer cliente. Args: `--dedicated`, opcional `--world=2d|3d`, `--mp-port=`.

- **Aceptación:** `local_slot() == 0`; `occupied_slots()` no incluye al server; HUD no asume “soy player 1” por peer 1.
- **Técnico:** `NetGlue._ready`. Documentar comando en README (F17).
- **Límites:** sin preset de export VPS en este repo.

### F14 — Túnel emote

Canal `emote` (allowlist en `configure`). `MpCustomPipe` en el pawn. Cliente/`send`; server/`broadcast`. Glue refleja **solo** si `from_peer != 1`. 1P: emit local. E = one-shot `_unhandled_input`.

- **Aceptación:** el emote del cliente lo ven todos; el del listen host también; no hay recursión infinita de `broadcast_custom`.
- **Técnico:** pipe + `NetGlue._on_custom`. Payload `{slot, msg}` opaco para el kit.
- **Límites:** no usar el túnel para movimiento ni looks (eso es Resource + submit).

### F15 — Snapshot elapsed + HUD

Solo server (y 1P) tiquea `elapsed`. 2–10 Hz `push_snapshot({elapsed})`. Cliente `apply_snapshot` y **no** tiquea. HUD: modo (1P / listen / dedicated / client slot), elapsed, slots, último paquete de túnel.

- **Aceptación:** dos clientes muestran el mismo elapsed (aprox.) sin simular el reloj local.
- **Técnico:** `DemoMatch` + `scenes/ui/match_hud.gd` (`CanvasLayer`).
- **Límites:** elapsed no es condición de victoria.

### F16 — Salir y pérdida de servidor

Salir → `leave` + boot. `server_lost` / `join_failed` → boot + mensaje `DemoCopy`. `peer_left`: borrar pawn de ese slot (rejoin = nuevo spawn).

- **Aceptación:** matar el host devuelve al cliente al lobby sin stack de errores.
- **Técnico:** `NetGlue.return_to_boot()`.
- **Límites:** dedicated headless: Ctrl+C; no botón Salir.

---

## Should have

### F17 — README de la demo

Cómo abrir el proyecto, 1P, dos instancias LAN, dedicated headless, F6, que el addon se re-copia con `install.sh --addon-only example`.

- **Aceptación:** un extraño puede seguir la guía sin este chat.
- **Complejidad:** Low.

### F18 — Artefactos de producto en `example/`

`PRD.md`, `PRD-REVIEW.md`, `FEATURES.md`, `RULES.md`, `RFCS.md`, `RFCs/`, `reviews/` — el flujo completo del estudio como parte de la guía.

- **Aceptación:** `/workflow-status` puede leer estos archivos.
- **Complejidad:** Low.

---

## Could have

Ninguna en este lanzamiento.

---

## Won't have (anotado)

### F19 — [WON'T] Loop de juego real

Puntaje, vidas, win/lose, armas, enemigos. No entra en `addons/mp_kit` ni en la demo.

### F20 — [WON'T] Steam / WebRTC / matchmaking

Fuera del kit. Dedicated + IP + UDP es “online” aquí.

### F21 — [WON'T] Predicción / interpolación avanzada

Synchronizer de Godot alcanza para la guía.

### F22 — [WON'T] Arte de producción

Sin Aseprite ni Blender. Placeholders.

### F23 — [WON'T] Tests automatizados

No pedidos. Sin GUT/GdUnit4.

---

## Complejidad relativa (Must + Should)

| ID | Complejidad | Notas |
|----|-------------|-------|
| F1, F2, F5, F17, F18 | Low | UI / Resource / docs |
| F3, F4, F6, F7, F16 | Medium | Escenas + F6 |
| F8, F9, F10, F11, F12 | Medium | Handshake y autoridad |
| F13, F14, F15 | Medium | Dedicated + túnel + snapshot |

Integración de terceros: solo Godot 4.7 + addon del mismo repo.

## Autochequeo

- Resumen: Must 16 (F1–F16), Should 2 (F17–F18), Could 0, Won't 5 (F19–F23). Total 23. La tabla por categoría suma 5+2+2+2+5+2+5 = 23.
- F11–F15 son cinco IDs de red Must. Lobby Must = F1, F2, F9, F10, F16 (5).
- Ningún ID reciclado. Referencias a MpKit/MpBoot/MpLan/MpReplicate coinciden con el addon.
- Sin tabla que contradiga el PRD (política dedicated = 1 cliente).
