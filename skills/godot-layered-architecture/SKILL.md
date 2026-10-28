---
name: godot-layered-architecture
description: >-
  Choose and apply Godot 4 architecture (GDScript): Clean layered (domain
  RefCounted, core autoloads, features) or standard scripts next to scenes.
  Always ask the user which to use. Prefer simple and predictable,
  composition, the value on the node that uses it (Resources .tres only for
  shared types), the editor, and reusable components. Use when
  creating or changing a Godot project, GDScript, scenes, match rules,
  features, HUD, or starting a new game.
---

# Godot — architecture

Base for Godot 4 games (GDScript). Two styles are valid. The agent **does not assume Clean**.

Always also load [godot-composition-first](../godot-composition-first/SKILL.md) and [godot-code-quality](../godot-code-quality/SKILL.md) (rule 0, patterns, typing, lint). Tests: [godot-testing](../godot-testing/SKILL.md). Multiplayer: **ask** (none / local-Wi-Fi / online) — [godot-mp-kit](../godot-mp-kit/SKILL.md) only if there is MP. 2D/3D: **ask**; if 3D, Blender MCP only with OK. A new title or RFC: [godot-studio-workflow](../godot-studio-workflow/SKILL.md).

## Priorities (always)

Always prioritize:

- simple and predictable: each thing where a developer guesses it, and changing a number opens 2 files at most
- architecture that is easy to scale and clean in layers
- composition structures always take priority
- nodes and editor configuration always take priority: the value lives on the node that uses it
- component reusability always takes priority

On the **standard** path, “layers” does **not** mean `domain/core/features` folders or scaffolding Clean. It means one responsibility per piece and composition of nodes/Resources. The layers bullet above applies to Clean; on standard do not invent `src/domain/`.

## 1. Choose a style (required)

**Always ask** the user, with the question tool (`AskUserQuestion` in Claude Code / `AskQuestion` in Cursor, if available), **before** creating folders, autoloads, or a feature that locks in the project shape.

1. **Clean / layered** — `features → core → domain`. See [clean.md](clean.md).
2. **Standard Godot** — scenes + scripts next to the scene. See [standard.md](standard.md).

Do not ask again if: the user already chose in this chat; they named a style; or the repo **already declares** it **and** the work is on that same game.

If there is no answer, **do not** scaffold `src/domain/` or a giant `scripts/` dump.

## 2. Shared guidelines

| Priority | In code |
|-----------|-----------|
| Composition | Tree + packed scenes. No 800-line superclass. |
| Editor | Knobs on `@export` and `.tscn`. Do not overwrite the inspector in `_init`/`_ready`. |
| Resources | Shared types = `class_name` + `.tres`. One scene, many data files. A value of a single scene = `@export`. |
| Reuse | Extract to `shared/` or `addons/` at the second caller. |
| One responsibility | One script, one job. Split by responsibility (a child or component), not by line count. |
| Signals | Name in the **past tense**, typed (`signal died(who: Node)`). The parent connects; the child does not name the parent. Between systems that do not know each other, the `Events` bus. |

### Autonomous scenes (Godot docs)

Design each packed scene to run **alone** (F6). No external deps. If it needs the world: the **parent injects** (`@export var health: Health`). SceneTree is **relational**, not spatial: child only if deleting the parent should delete the child; otherwise sibling + `RemoteTransform2D`/`RemoteTransform3D`. Typical split: persistent `Main`, `World` (levels swap), sibling `GUI` (does not die with the level).

### Where data lives (not everything is an autoload)

| What | Use | Not |
|------|-----|-----|
| Type / catalog data | `class_name` `Resource` + `.tres` | Autoload of stats |
| Pure helpers | `class_name` + `static func` | Empty singleton |
| Actor behavior | Child `class_name` node / packed scene | Global manager |
| Isolated global that survives `change_scene` | Autoload (MpKit, `Events` bus with signals only) | Autoload holding visual nodes or *this* round’s score; registry, locator, or manager |
| Score / lives of *this* match | `Match` node (or Clean session if it survives scene change) | Eternal `ScoreManager` |

UI in the product language; code identifiers in English.

## 3. Data: what goes where

| Thing | Where |
|------|--------|
| Type catalog (projectile A vs B, scout vs tank) | **Resource** `.tres` |
| Look of *this* instance | `@export` on the node / material |
| Round rules (duration, lives, layers) | `@export` on the `Match` node. A `MatchRules.tres` only if several pieces read it (the Clean session and the features) or there are several modes to pick from. No copied literals. |
| Current HP, active cooldown | Runtime on the node; **do not** mutate the `.tres` |

## 4. How to add a feature

Checklist: [adding-features.md](adding-features.md). Tests: [godot-testing](../godot-testing/SKILL.md).

| Type | Owner | Examples |
|------|--------|----------|
| **A. Input** | Client reads; host applies | InputMap actions |
| **B. Simulation** | Host only if networked | projectile, enemy |
| **C. Match state** | Clean session or Match node | ammo, lives |
| **D. Presentation** | Local | flash, post-process |
| **E. UI** | HUD / menus | cooldown icon |
| **F. Type definition** | Resource template | `projectile_fast.tres` |

## 5. IDs (if multiplayer)

Logical slot = HUD/lives. ENet peer = RPC only. HUD: `MpKit.local_slot()`.

## Anti-patterns

- `World.gd` that paints, spawns, scores, and changes scene.
- `if kind == "fast"` on the projectile instead of a `.tres`.
- Mutating a shared Resource (`data.damage = 3`).
- New feature via deep inheritance.
- Autoload for something that is a node or a Resource.
- Invented patterns (registry, service locator, manager of managers) or pointers through tags / strings.

Examples: [examples.md](examples.md).
