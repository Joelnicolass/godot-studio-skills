# PRD — MpKit Example

**Tipo de producto:** juego Godot (demo / guía de framework). El archivo se llama `PRD.md` porque el resto del flujo lo busca; el contenido es un **GDD corto**.

**Controles omitidos (no aplican a este producto):** modelo de negocio, SQL/inyección, autenticación de usuarios, diseño responsive web, APIs REST, personas de marketing, compliance, accesibilidad WCAG web, infraestructura cloud de SaaS. En su lugar: loop, feel, tipos como datos, qué queda fuera del slice.

**Decisiones ya tomadas en el chat de producto (no re-entrevistar):**

| Tema | Elección |
|------|----------|
| Arquitectura | **Estándar Godot** (`scenes/` + script junto a la escena). No Clean, no `src/domain/`. |
| Multiplayer | **Los tres modos** en la misma demo: 1P (sin `host()`), local/WiFi (`MpKit.host()`), online (`MpKit.host_dedicated()` + `join`). |
| Dimensión | **2D y 3D** (dos escenas de match). |
| Arte | **Placeholders** (`PlaceholderTexture2D`, `BoxMesh`). Sin Aseprite, sin Blender MCP. |
| Tests | No se piden. Sin GUT/GdUnit4 en este slice. |

**Implementación de referencia (extraída de):** el addon canónico `../addons/mp_kit/` de este repo (Godot studio kit). El proyecto vacío ya existe en `example/project.godot` (Godot **4.7**, renderer mobile, Jolt 3D).

---

## Resumen

Demo mínima y jugable que enseña cómo usar **MpKit** y las skills del estudio (arquitectura estándar, composición, Resources, host-authoritative) **sin ser un juego real**. Hay un lobby, un pawn placeholder que se mueve, un emote por túnel `Dictionary`, y el mismo árbol sirve en 1P, listen-server LAN y servidor dedicado.

Propuesta de valor: quien clone el kit abre `example/`, corre el flujo de producto (este PRD → RFCs → código) y entiende dónde termina el addon y dónde empieza el glue del título.

## Metas y objetivos

1. Una persona puede **jugar sola** (F5 / Play solo) y mover un pawn 2D o 3D en menos de un minuto.
2. Dos instancias en la misma máquina demuestran **Host LAN + Join** (`127.0.0.1`) con pawns replicados (no duplicados).
3. Un proceso `--headless -- --dedicated` + un cliente demuestra **online** (dedicated, peer 1 no es jugador).
4. El código no mete puntaje, copy de un título, ni reglas de ronda dentro de `addons/mp_kit`.
5. Cada packed scene relevante corre con **F6** (o advierte). Tipos de look = `.tres`, no `if kind`.

## Alcance

### Incluido (primer slice)

- Lobby: Jugar solo, Host LAN, Unirse (IP), toggle mundo 2D/3D, IP local, Salir.
- Match 2D y Match 3D con placeholders, `MpSpawner`, `MpWorldReady`, spawn por slot.
- Pawn 2D (`CharacterBody2D`) y pawn 3D (`CharacterBody3D`): movimiento host-authoritative (`submit_*` / `apply_*`), `MpReplicate`, look por Resource.
- Túnel `MpCustomPipe` canal `emote` (servidor decide broadcast; no auto-reflect).
- Snapshot mínimo (tiempo transcurrido) para mostrar `push_snapshot` / `apply_snapshot` (el cliente no tiquea el reloj).
- Boot dedicated vía `MpBoot` (`--dedicated` o feature `dedicated_server`).
- Copy de UI en el idioma del producto (`DemoCopy`); IDs de código en inglés.
- README de la demo: cómo correr cada modo.

### Fuera (Won't)

- Juego real (score, vidas, win/lose, armas, enemigos, niveles).
- Steam, WebRTC, matchmaking, NAT traversal más allá de IP pública + UDP.
- Interpolación avanzada, client-side prediction, lag compensation.
- Arte de producción, shaders custom, AnimationPlayer de personaje.
- Clean Architecture / `GameSession` autoload / `src/domain/`.
- Tests automatizados (no pedidos).
- Export presets de VPS en este repo (se documenta el comando headless; el binario dedicated lo hace el usuario en su título).

## Personas / audiencia

1. **Desarrollador Godot** que copia MpKit a su título y necesita un árbol de referencia, no un paper.
2. **Agente / humano en Cursor** que sigue skills + commands: este proyecto es el resultado visible del flujo PRD → RFC.

## Requisitos funcionales

Prioridad MoSCoW detallada en `FEATURES.md`. Resumen:

| Prioridad | Capacidad |
|-----------|-----------|
| Must | Lobby + 1P + match 2D/3D + pawns placeholder + InputMap + Resources de look |
| Must | Listen-server: host es jugador (slot 1); handshake spawn; `submit_move` |
| Must | Dedicated: `local_slot() == 0`, sin pawn de servidor; clientes `join` |
| Must | Túnel emote + snapshot de elapsed + HUD de modo/slots |
| Must | Desconexión: `server_lost` / `join_failed` vuelven al lobby |
| Should | README + artefactos de producto (este PRD, FEATURES, RULES, RFCs) como guía |
| Won't | Ver Alcance / Fuera |

## Requisitos no funcionales

- Godot **4.7** (el `project.godot` existente). GDScript. Física 3D: Jolt (ya configurado).
- Autoload: `MpKit` **antes** de `NetGlue`. Plugin MpKit habilitado.
- Puerto default **7777**; override `MpBoot.user_value("mp-port", "7777")`.
- Máximo **4** jugadores.
- El kit se **copia** con `./install.sh --addon-only example` desde la raíz del studio kit; no se forkear.
- UI en español en esta edición del kit; la edición en inglés lleva el mismo example traducido.
- Sin secretos, sin red fuera de ENet UDP.

## Jornadas de usuario

1. **1P:** abre el proyecto → F5 → Jugar solo → elige 2D o 3D → mueve con WASD/flechas → E emote local → Salir.
2. **LAN:** instancia A Host LAN → instancia B Unirse `127.0.0.1` → ambos ven dos pawns de color distinto → se mueven → emote se replica.
3. **Dedicated:** terminal `godot --headless --path example -- --dedicated` → cliente Join `127.0.0.1` → el servidor no tiene pawn → el cliente sí.
4. **F6:** abre `pawn_2d.tscn` o `match_2d.tscn` y corre sola (offline).

## Feel

- Cámara 2D fija / 3D orbital simple sobre el origen. Sin juicy de título.
- How-to-fail: IP inválida, puerto ocupado, servidor caído → mensaje en lobby, no crash.
- Sesión: minutos; no hay ronda con timer de victoria (elapsed es solo demo de snapshot).

## Plataformas e input

- Desktop (editor Godot / export local). Teclado. Acciones: `move_left`, `move_right`, `move_up`, `move_down`, `emote`.

## Métricas de éxito

- Los tres modos se pueden demostrar en una máquina.
- Un lector distingue `addons/mp_kit` (transporte) de `glue/` + `scenes/` (juego).
- No hay `if look_id ==` ni puntaje en el addon.

## Cronograma

| Hito | Entrega |
|------|---------|
| RFC-001 | Slice 1P 2D jugable |
| RFC-002 | Match 3D + runtime de spawn compartido |
| RFC-003 | Listen-server + autoridad + handshake |
| RFC-004 | Dedicated + túnel + snapshot + README |

Implementación: `/implement-rfc` por RFC, en orden.

## Preguntas abiertas / supuestos

| Ítem | Resolución |
|------|------------|
| ¿Clean o estándar? | Estándar. |
| ¿Un tipo de MP o los tres? | Los tres, como guía. Política: listen arranca al hostear (el host juega solo en red); dedicated arranca al **primer** cliente (no espera 2: es una demo). |
| ¿Arte? | Placeholders. |
| ¿Tests? | No. |
| ¿Dónde viven los artefactos de producto? | En `example/` (el proyecto Godot es el título de muestra). |
| Rejoin | Slot se reserva (kit). Pawn se destruye al `peer_left` y se vuelve a spawnar si re-entra con world_ready. |
