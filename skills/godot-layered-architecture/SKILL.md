---
name: godot-layered-architecture
description: >-
  Choose and apply Godot 4 architecture (GDScript): Clean layered (domain
  RefCounted, core autoloads, features) or standard small scripts next to
  scenes. Always ask the user which to use. Prefer composition, Resources
  (.tres) for bullet/enemy/power-up types, the editor, and reusable
  components. Use when creating or changing a Godot project, GDScript, scenes,
  match rules, GameSession, GameEvents, features, HUD, or starting a new game.
---

# Godot — architecture

Base for Godot 4 games (GDScript). Two styles are valid. The agent **does not assume Clean**.

Always also load [godot-composition-first](../godot-composition-first/SKILL.md) (includes Resources). If there is networking: [godot-mp-kit](../godot-mp-kit/SKILL.md).

## Priorities (always)

Always prioritize:

- architecture that is easy to scale and clean in layers
- composition structures always take priority
- nodes and editor configuration always take priority
- component reusability always takes priority

On the **standard** path, “layers” does not mean `domain/core/features` folders. It means small scripts, one responsibility per piece, and composition of nodes/Resources. The only exception is the Clean split; the rest of the guidelines **do not relax**.

## 1. Choose a style (required)

**Always ask** the user, with AskQuestion if available, **before** creating folders, autoloads, or a feature that locks in the project shape.

Options:

1. **Clean / layered** — `features → core → domain`. Rules in `RefCounted` without `Node`. Session facade + events. See [clean.md](clean.md).
2. **Standard Godot** — scenes + scripts next to the scene, no domain/core layers. Same code quality. See [standard.md](standard.md).

Suggested prompt:

> Which architecture do you want for this project / this change?
> - Clean (domain / core / features)
> - Standard (scenes and scripts; no Clean layers)

Do not ask again if: the user already chose in this chat; they named a style; or the repo **already declares** it (AGENTS.md / README) **and** the work is on that same game (not a new title).

If the user has not answered yet, **do not** scaffold `src/domain/` or a giant `scripts/` dump: wait.

## 2. Shared guidelines (both paths)

| Priority | In code |
|-----------|-----------|
| Composition | Node tree + packed scenes. No 800-line superclass. |
| Editor | Knobs on `@export` and `.tscn`. Do not overwrite the inspector in `_init`/`_ready`. |
| Resources | Bullet / enemy / power-up / weapon types = `class_name` + `.tres` template. One scene, many data files. See [resources.md](../godot-composition-first/resources.md). |
| Reuse | Extract to `shared/` or `addons/` at the second caller. |
| Small scripts | One responsibility. If it grows, add a child or component, not “one more if”. |
| Signals | Child → parent with signals. Parent calls the child’s API. Unrelated systems: event bus, not `get_node("../../")`. |

Autoloads only for truly global services (events, audio, scene changes, MpKit). A spawner or *this match’s* score is not an eternal singleton.

UI in the product language; code identifiers in English.

## 3. Data: what goes where

| Thing | Where |
|------|--------|
| Type catalog (plasma vs spread, grunt vs tank, slow-time vs shield) | **Resource** `.tres` (template). One data class, N files. |
| Look of *this* instance in *this* scene | `@export` on the node / material |
| Match rules shared host/guest (duration, lives, layers) | Clean: `GameConstants` or a `MatchRules.tres`. Standard: one rules Resource or unique constants — not copied literals. |
| Current HP, active cooldown, combo | **Runtime** state on the node or tracker; **do not** mutate the definition `.tres` |

## 4. How to add a feature

Classify before the sprite. Checklist: [adding-features.md](adding-features.md).

| Type | Owner | Examples |
|------|--------|----------|
| **A. Input** | Client reads; host applies | pointer, fire |
| **B. Simulation** | Host only if networked | projectile, enemy |
| **C. Match state** | Clean: session/domain. Standard: small match node, not a god World | ammo, combo |
| **D. Presentation** | Local, no damage RPC | flash, post-process |
| **E. UI** | HUD / menus | cooldown icon |
| **F. Type definition** | Resource template | `plasma.tres`, `grunt.tres` |

## 5. IDs (if multiplayer)

- **Logical slot**: key for score/lives/HUD.
- **ENet peer**: RPC and authority only.

HUD: `MpKit.local_slot()`, never `get_unique_id()`.

## Anti-patterns (both paths)

- `World.gd` / `Arena.gd` that paints, spawns, scores, and changes scene.
- `if bullet_kind == "plasma"` on the projectile instead of a `.tres`.
- Mutating a shared Resource (`data.damage = 3`) and breaking every instance.
- New feature via deep inheritance.
- Copied business literals (`60`, `3`, `7777`).
- Copy-pasting a component instead of extracting it.

Generic code examples: [examples.md](examples.md).
