# RULES — MpKit Example

**Tipo de producto:** juego Godot (demo / guía).  
**Controles omitidos (auditables):** responsive web, auth, SQL, REST, semver de librería, bundle size, WCAG web, infra SaaS. No rellenar esas secciones con “N/A tranquilizador” en forma de falso hallazgo.

**Anclaje en código existente:** `example/project.godot` (Godot 4.7, Jolt, mobile) y `addons/mp_kit` v0.3.0 del repo padre. Gana la consistencia con ese addon, no un patrón inventado.

---

## 1. Stack

| Pieza | Versión | Fuente |
|-------|---------|--------|
| Godot | 4.7 | `example/project.godot` `config/features` (no inventada) |
| GDScript | el del editor 4.7 | mismo proyecto |
| Física 3D | Jolt Physics | `example/project.godot` |
| Renderer | mobile | mismo |
| MpKit | 0.3.0 | `addons/mp_kit/plugin.cfg` |
| Tests | no hay runner | PRD: F23 Won't |

Copiar el addon: desde la raíz del studio kit, `./install.sh --addon-only example`. No forkear archivos del kit dentro de `glue/` o `scenes/`.

## 2. Arquitectura (ya elegida)

**Estándar Godot** — skill `godot-layered-architecture` camino `standard.md`.  
Skills obligatorias: `godot-composition-first`, `godot-mp-kit` (hay MP).  
No citar `godot-testing` como exigencia (F23).  
No scaffoldear `src/domain/`, `core/`, ni `GameSession` autoload.

```
example/
  addons/mp_kit/          # copia canónica
  glue/net_glue.gd        # autoload: boot, host/join, load_world
  scenes/ui/              # boot, match HUD
  scenes/world/           # match_2d, match_3d, demo_match.gd
  scenes/actors/          # pawn_2d, pawn_3d + input child
  scenes/components/      # piezas reutilizables (pawn_input)
  resources/looks/        # ActorLook .gd + .tres
  DemoCopy (strings UI)
```

Estado de **esta** partida: nodo `DemoMatch` en el mundo, no un singleton eterno.  
Autoloads: `MpKit` **antes** de `NetGlue`. Nada más.

## 3. Composición y editor

- Actor = contenedor flaco + hijos (visual, colisión, `MpReplicate`, `MpCustomPipe`, input).
- Tipos = `ActorLook` Resource. Una escena, varios `.tres`. No `if kind`.
- Knobs en `@export` / inspector. No pisar valores de escena en `_ready` salvo looks inyectados por el padre.
- Internos: `%UniqueName`. Entre escenas: socket `@export`.
- Escenas autónomas (F6). Si falta el mundo, preview local o `_get_configuration_warnings()`.
- InputMap semántico. Hold → `_physics_process`. Emote → `_unhandled_input`.
- UI: idioma del producto (`DemoCopy`). IDs de código: inglés.

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
| `class_name` | PascalCase (`ActorLook`, `DemoMatch`, `DemoCopy`) |
| Señales | pasado, tipadas (`peer_left`, no `onPeer`) |
| RPCs de intención | `submit_*` / `try_*` / `apply_*` |
| Canales túnel | `StringName` (`emote`) |

## 6. Errores y logging

- Host/join: `Error` de ENet → `DemoCopy` en el lobby, `push_error` si dedicated no bindea y `quit(1)`.
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

Cablear este archivo: `example/AGENTS.md` apunta a `RULES.md`. Quien implemente en Cursor debe leerlo.

## Autochequeo

- Tabla stack: 6 filas, versiones ancladas a archivos (Godot 4.7, MpKit 0.3.0).
- Features citadas F1–F23 coinciden con FEATURES.md (Must 16, Should 2, Won't 5).
- No contradice el PRD (estándar, tres modos de MP, placeholders, dedicated al 1.er cliente).
