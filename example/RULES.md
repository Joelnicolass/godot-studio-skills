# RULES — MpKit Example

**Product type:** Godot game (demo / guide).  
**Omitted (auditable):** responsive web, auth, SQL, REST, library semver, bundle size, web WCAG, SaaS infra.

**Anchored in existing code:** `example/project.godot` (Godot 4.7, Jolt, mobile) and parent `addons/mp_kit` v0.3.0.

## 1. Stack

| Piece | Version | Source |
|-------|---------|--------|
| Godot | 4.7 | `example/project.godot` `config/features` |
| GDScript | Godot 4.7 | same |
| 3D physics | Jolt Physics | `example/project.godot` |
| Renderer | mobile | same |
| MpKit | 0.3.0 | `addons/mp_kit/plugin.cfg` |
| Tests | no runner | PRD: F23 Won't |

Copy the addon: from the studio kit root, `./install.sh --addon-only example`. Do not fork kit files into `glue/` or `scenes/`.

## 2. Architecture (already chosen)

**Standard Godot** — skill `godot-layered-architecture` `standard.md`.  
Also: `godot-composition-first`, `godot-mp-kit`. Do not require `godot-testing` (F23).  
Do not scaffold `src/domain/`, `core/`, or a `GameSession` autoload.

```
example/
  addons/mp_kit/
  glue/net_glue.gd
  scenes/ui/
  scenes/world/
  scenes/actors/
  scenes/components/
  resources/looks/
```

Match state lives on `DemoMatch` in the world. Autoloads: `MpKit` **before** `NetGlue` only.

## 3. Composition and editor

Thin actor + children. Types = `ActorLook` `.tres`. `@export` knobs. `%UniqueName` inside a scene. F6. InputMap, not `KEY_*`. UI in the product language (`DemoCopy`). Placeholders only (no Aseprite/Blender MCP).

## 4. Multiplayer (`godot-mp-kit`)

| Mode | API | Local player |
|------|-----|----------------|
| 1P | no `host()` | `local_slot()` = 1 |
| LAN | `MpKit.host()` | host is slot 1 / peer 1 |
| Online | `MpKit.host_dedicated()` | `local_slot() == 0`, no pawn |

`submit_*` on the **pawn**. Handshake: spawnables before `add_child(pawn, true)`. Tunnel: reflect only `from_peer != 1`. Dedicated: `MpBoot.is_dedicated_process()`, not `--headless` alone. Startup: listen on host; dedicated on first client. Kit patches go in the canonical addon, then re-copy.

## 5. Naming

`submit_*` / `try_*` / `apply_*`. Signals in past tense. Tunnel channels: `StringName`.

## 6. Errors

ENet `Error` → `DemoCopy` on the lobby. Dedicated bind fail → `quit(1)`. Validate IPv4 with `MpLan` before `join`.

## 7. Tests and quality

No coverage gate (F23). Manual: three modes + F6. Authority: PRD > FEATURES > RULES > RFC.

## 8. MoSCoW

Must F1–F16. Should F17–F18. Won't F19–F23. Phases = RFC-001 → 004.

## 9. Agent

`example/AGENTS.md` points at this file.

## Autocheck

Stack table 6 rows, versions from files. Feature IDs F1–F23 match FEATURES.md. No contradiction with the PRD.
