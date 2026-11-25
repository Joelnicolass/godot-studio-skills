# RULES — MpKit Example

## Where everything is

**Size:** by entity (one folder per topic at the root; see `godot-layered-architecture`).

```
example/
├── main/            boot.tscn, boot.gd                  # entry
├── player/          pawn_2d.*, pawn_3d.*, pawn_type.gd, pawn_{a,b,c,d}_type.tres, pawn_catalog.*, pawn_material.tres
├── match/           demo_match.tscn, demo_match.gd      # match state
├── levels/
│   ├── match_2d/    match_2d.tscn
│   └── match_3d/    match_3d.tscn, floor_material.tres
├── ui/hud/          match_hud.tscn, match_hud.gd
├── shared/components/   pawn_input.gd                   # used by pawn_2d and pawn_3d
├── locale/          texts.csv                           # player-facing texts (es, en)
├── autoloads/       net_session.tscn, net_session.gd          # connects MpKit to the game
├── debug/           pawn_3d_preview.tscn, spawn_lab/    # outside the export
├── agent/           flows/, playtest scripts
├── docs/            architecture.md, tuning.md, .gdignore
└── addons/          mp_kit/, agent_kit/
```

| Suffix | What it is | Here |
|---|---|---|
| `_type.tres` | Data of one type | `player/pawn_a_type.tres` … `pawn_d_type.tres` (`PawnType`) |
| `_catalog.tres` | Typed list of Resources | `player/pawn_catalog.tres` (`PawnCatalog`) |
| `_material.tres` | Material | `player/pawn_material.tres`, `levels/match_3d/floor_material.tres` |
| `_config.tres`, `_env.tres`, `_theme.tres`, `_layout.tres`, `_curve.tres` | Global balance, `Environment`, theme, saved map, curve | none in this example |

A `.tres` without a suffix does not pass. Every design knob and where to change it: [`docs/tuning.md`](docs/tuning.md).

**Product type:** Godot game (demo / guide).  
**Omitted (auditable):** responsive web, auth, SQL, REST, library semver, bundle size, web WCAG, SaaS infra.

**Anchored in existing code:** `example/project.godot` (Godot 4.7, Jolt, mobile) and parent `addons/mp_kit` (the version in its `plugin.cfg`, 0.20.1 today).

## 1. Stack

| Piece | Version | Source |
|-------|---------|--------|
| Godot | 4.7 | `example/project.godot` `config/features` |
| GDScript | Godot 4.7 | same |
| 3D physics | Jolt Physics | `example/project.godot` |
| Renderer | mobile | same |
| MpKit | 0.20.1 | `example/addons/mp_kit/plugin.cfg` (a copy of `addons/mp_kit`) |
| Tests | no runner (PRD: F23 Won't); network checks: `debug/spawn_lab/run_lab.sh`, `agent/run_mp_playtest.sh` (AgentKit) | README → Network checks |

Copy the addon: from the studio kit root, `./install.sh --addon-only example`. Do not fork kit files into the game (`autoloads/`, `player/`…).

## 2. Architecture (already chosen)

**By entity** — skill `godot-layered-architecture`, `by-entity.md` (the real tree is above).  
Also: `godot-composition-first`, `godot-mp-kit`. Do not require `godot-testing` (F23).  
Do not scaffold `src/domain/`, `core/`, or a `GameSession` autoload.

Match state lives on `DemoMatch` in the world. Autoloads: `MpKit` **before** `NetSession`; `AgentKit` last (inert without `--agent=`).

## 3. Composition and editor

Thin actor + children. Types = `PawnType` Resource (`type`), one `_type.tres` per variant, one catalog by slot. One owner per number: the type. `@export` knobs. `%UniqueName` inside a scene. F6. InputMap, not `KEY_*`. UI texts are in `locale/texts.csv` (a `Control` uses the key, code uses `tr()`). Placeholders only (no Aseprite/Blender MCP).

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

ENet `Error` → `tr("STATUS_*")` on the lobby. Dedicated bind fail → `quit(1)`. Validate IPv4 with `MpLan` before `join`.

## 7. Tests and quality

No coverage gate (F23). Manual: three modes + F6. Authority: PRD > FEATURES > RULES > RFC.

## 8. MoSCoW

Must F1–F16. Should F17–F18. Won't F19–F23. Phases = RFC-001 → 004.

## 9. Agent

`example/AGENTS.md` points at this file and `example/CLAUDE.md` imports both.

## Autocheck

Stack table 6 rows, versions from files. Feature IDs F1–F23 match FEATURES.md. No contradiction with the PRD.
