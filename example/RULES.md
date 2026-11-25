# RULES — MpKit Example

## Dónde está cada cosa

**Tamaño:** por entidad (una carpeta por tema en la raíz; ver `godot-layered-architecture`).

```
example/
├── main/            boot.tscn, boot.gd                  # entrada
├── player/          pawn_2d.*, pawn_3d.*, pawn_type.gd, pawn_{a,b,c,d}_type.tres, pawn_catalog.*, pawn_material.tres
├── match/           demo_match.tscn, demo_match.gd      # estado de la partida
├── levels/
│   ├── match_2d/    match_2d.tscn
│   └── match_3d/    match_3d.tscn, floor_material.tres
├── ui/hud/          match_hud.tscn, match_hud.gd
├── shared/components/   pawn_input.gd                   # lo usan pawn_2d y pawn_3d
├── locale/          texts.csv                           # textos del jugador (es, en)
├── autoloads/       net_session.tscn, net_session.gd          # conecta MpKit con el juego
├── debug/           pawn_3d_preview.tscn, spawn_lab/    # fuera del export
├── agent/           flows/, scripts de playtest
├── docs/            architecture.md, tuning.md, .gdignore
└── addons/          mp_kit/, agent_kit/
```

| Sufijo | Qué es | Aquí |
|---|---|---|
| `_type.tres` | Datos de un tipo | `player/pawn_a_type.tres` … `pawn_d_type.tres` (`PawnType`) |
| `_catalog.tres` | Lista tipada de Resources | `player/pawn_catalog.tres` (`PawnCatalog`) |
| `_material.tres` | Material | `player/pawn_material.tres`, `levels/match_3d/floor_material.tres` |
| `_config.tres`, `_env.tres`, `_theme.tres`, `_layout.tres`, `_curve.tres` | Balance global, `Environment`, tema, mapa guardado, curva | no hay en este ejemplo |

Un `.tres` sin sufijo no pasa. Cada perilla de diseño y dónde cambiarla: [`docs/tuning.md`](docs/tuning.md).

**Tipo de producto:** juego Godot (demo / guía).  
**Controles omitidos (auditables):** responsive web, auth, SQL, REST, semver de librería, bundle size, WCAG web, infra SaaS. No rellenar esas secciones con “N/A tranquilizador” en forma de falso hallazgo.

**Anclaje en código existente:** `example/project.godot` (Godot 4.7, Jolt, mobile) y `addons/mp_kit` (la versión de su `plugin.cfg`, hoy 0.20.1) del repo padre. Gana la consistencia con ese addon, no un patrón inventado.

---

## 1. Stack

| Pieza | Versión | Fuente |
|-------|---------|--------|
| Godot | 4.7 | `example/project.godot` `config/features` (no inventada) |
| GDScript | el del editor 4.7 | mismo proyecto |
| Física 3D | Jolt Physics | `example/project.godot` |
| Renderer | mobile | mismo |
| MpKit | 0.20.1 | `example/addons/mp_kit/plugin.cfg` (copia de `addons/mp_kit`) |
| Tests | no hay runner (PRD: F23 Won't); chequeos de red: `debug/spawn_lab/run_lab.sh`, `agent/run_mp_playtest.sh` (AgentKit) | README → Chequeos de red |

Copiar el addon: desde la raíz del studio kit, `./install.sh --addon-only example`. No forkear archivos del kit dentro del juego (`autoloads/`, `player/`…).

## 2. Arquitectura (ya elegida)

**Por entidad** — skill `godot-layered-architecture`, `by-entity.md` (el árbol real está arriba).  
Skills obligatorias: `godot-composition-first`, `godot-mp-kit` (hay MP).  
No citar `godot-testing` como exigencia (F23).  
No scaffoldear `src/domain/`, `core/`, ni `GameSession` autoload.

Estado de **esta** partida: nodo `DemoMatch` en el mundo, no un singleton eterno.  
Autoloads: `MpKit` **antes** de `NetSession`; `AgentKit` al final (inerte sin `--agent=`).

## 3. Composición y editor

- Actor = contenedor flaco + hijos (visual, colisión, `MpReplicate`, `MpCustomPipe`, input).
- Tipos = `PawnType` Resource (`type`). Una escena, varios `_type.tres`, un catálogo por slot. No `if kind`. Un dueño por número: el tipo.
- Knobs en `@export` / inspector. No pisar en `_ready` los valores de la escena: el tipo se lee, no se escribe.
- Internos: `%UniqueName`. Entre escenas: socket `@export`.
- Escenas autónomas (F6). Si falta el mundo, preview local o `_get_configuration_warnings()`.
- InputMap semántico. Hold → `_physics_process`. Emote → `_unhandled_input`.
- UI: los textos están en `locale/texts.csv` (un `Control` usa la clave, el código usa `tr()`). IDs de código: inglés.

Sprites 2D / 3D: **placeholders** (PRD). No MCP Aseprite ni Blender. Shaders: no hay pases custom en este slice.

## 4. Multiplayer (skill `godot-mp-kit`)

| Modo | API | Jugador local |
|------|-----|----------------|
| 1P | no `host()` | `local_slot()` = host_slot (1) |
| LAN | `MpKit.host()` | host es slot 1 / peer 1 |
| Online | `MpKit.host_dedicated()` | `local_slot() == 0`, sin pawn |

- Preguntar tipo de MP ya está resuelto: los tres, como guía.
- `submit_*` en el **pawn**, no en el kit. Allowlist. `call_remote`. Validar sender vs `peer_id_for(slot)`.
- Handshake: registrar spawnable **antes** de `add_child(pawn, true)`. `MpWorldReady` después de `MpSpawner`.
- Túnel: opaco. **No** `broadcast_custom` incondicional desde `custom_received` (recursión). Reflejar solo `from_peer != 1`. Listen host: `pipe.broadcast` / `broadcast_custom`.
- Dedicated: no tratar `--headless` solo como dedicated. `MpBoot.is_dedicated_process()`.
- Política de arranque (producto): listen al hostear; dedicated al primer cliente.
- Cero puntaje/copy/escenas de título dentro de `addons/mp_kit`. Si hay que parchear el kit (bugs), hacerlo en el addon canónico del repo padre y re-copiar.

## 5. Naming

| Qué | Convención |
|-----|------------|
| Archivos / nodos / vars | snake_case / PascalCase de Godot |
| `class_name` | PascalCase (`PawnType`, `PawnCatalog`, `DemoMatch`) |
| Señales | pasado, tipadas (`peer_left`, no `onPeer`) |
| RPCs de intención | `submit_*` / `try_*` / `apply_*` |
| Canales túnel | `StringName` (`emote`) |

## 6. Errores y logging

- Host/join: `Error` de ENet → `tr("STATUS_*")` en el lobby, `push_error` si dedicated no bindea y `quit(1)`.
- IP: `MpLan.is_valid_ipv4` antes de `join`.
- No `assert` como único control de sockets en release; warnings de inspector en `@tool` si aplica.

## 7. Tests y calidad

- **No** hay umbral de cobertura (F23). Verificar a mano los tres modos + F6.
- Completitud: sin `TODO` de producto en el slice. Placeholders de **arte** sí (PRD).
- Un RFC a la vez. Orden de autoridad: PRD > FEATURES > RULES > RFC > plan.

## 8. MoSCoW (este proyecto)

Must F1–F16. Should F17–F18. Won't F19–F23. No implementar Won't “por si acaso”.

Fases = RFC-001 → 004 (ver `RFCS.md`).

## 9. Agente

Cablear este archivo: `example/AGENTS.md` apunta a `RULES.md` y `example/CLAUDE.md` importa los dos. Quien implemente (Claude Code o Cursor) debe leerlo.

## Autochequeo

- Tabla stack: 6 filas, versiones ancladas a archivos (Godot 4.7, MpKit según `plugin.cfg`).
- Features citadas F1–F23 coinciden con FEATURES.md (Must 16, Should 2, Won't 5).
- No contradice el PRD (por entidad, tres modos de MP, placeholders, dedicated al 1.er cliente).
