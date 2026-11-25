---
name: godot-layered-architecture
description: >-
  Choose and apply the architecture of a Godot 4 game (GDScript): one style
  in two sizes, "by entity" (the default) or "systems + content" (lots of
  content, or someone who tunes values without programming). Ask for the size
  and recommend the default. Each system is a node you can see in the editor,
  with an optional pure core next to it. Clean layered only in a repo that
  already declares it or when the user asks for it by name. Use when creating
  or changing a Godot project, GDScript, scenes, folders, match rules,
  features, HUD, or starting a new game.
---

# Godot — architecture

Base for Godot 4 games (GDScript). There is **one style** in **two sizes**. The game is built the way a kit is: each system is a node you can see in the editor, with its `@export`s and its signals, and next to it an optional pure core for the rules that deserve a test.

Always also load [godot-composition-first](../godot-composition-first/SKILL.md) and [godot-code-quality](../godot-code-quality/SKILL.md) (rule 0, folders, patterns, typing, lint). Tests: [godot-testing](../godot-testing/SKILL.md). Multiplayer: **ask** (none / local-Wi-Fi / online) — [godot-mp-kit](../godot-mp-kit/SKILL.md) only if there is MP. 2D/3D: **ask**; if 3D, Blender MCP only with OK. A new title or RFC: [godot-studio-workflow](../godot-studio-workflow/SKILL.md).

## Priorities (always)

- Simple and predictable: each thing where a person guesses it, and changing a number opens 2 files at most.
- A person can find it: `docs/tuning.md` says what to open for each thing.
- Composition before inheritance.
- Nodes and the editor before code: what can be seen and changed in the inspector is not built from code.
- Reusable components.

## 1. Choose the size (required)

**Always ask** the user, with the question tool (`AskUserQuestion` in Claude Code / `AskQuestion` in Cursor, if available), **before** creating folders, autoloads, or a feature that locks in the project shape. The question is about size, and it comes with a recommendation:

> A small game (one or two programmers, up to about 10 entity types), or a game with lots of content or with someone who tunes values without programming?

1. **By entity** (recommended, the default) — one folder per subject, with everything of that entity inside. See [by-entity.md](by-entity.md).
2. **Systems + content** — the rules in `systems/` and everything design and art edit in `content/`. See [systems-content.md](systems-content.md).

If the user does not know, use **by entity**. Moving to systems + content later is moving folders, not rewriting.

Do not ask again if: the user already chose in this chat; they named a size; or the repo **already declares** it (RULES.md) **and** the work is on that same game.

If there is no answer, **do not** create folders.

**Clean layered** (`features → core → domain`) is not offered to a new project. It applies in a repo that already declares it or when the user asks for it by name: [clean.md](clean.md). Do not change the style of a game already under way unless the user asks for it; then migrate in batches, with the tree before each one.

Folders, file names, and suffixes: [godot-code-quality](../godot-code-quality/SKILL.md) §1. The choice goes in RULES.md.

## 2. Shared guidelines

| Priority | In code |
|-----------|-----------|
| Composition | Tree + packed scenes. No 800-line superclass. |
| Editor | Knobs on `@export` and in the `.tscn`. Do not overwrite the inspector in `_init` / `_ready`. |
| Data | Where each number lives and when a `.tres` exists: rule 0 of [godot-code-quality](../godot-code-quality/SKILL.md). |
| Reuse | What two entities use goes to `shared/` (or `systems/`); what serves another game, to `addons/`. |
| One responsibility | One script, one job. Split by responsibility (a child or component), not by line count. |
| Signals | Name in the **past tense**, typed (`signal died(who: Node)`). The parent connects; the child does not name the parent. Between systems that do not know each other, the `Events` bus. |

### Autonomous scenes (Godot docs)

Design each packed scene to run **alone** (F6), without depending on what surrounds it. If it needs the world, the **parent hands it over** (`@export var health: Health`). The tree is **relational**, not spatial: a node is a child only if deleting the parent should delete it too; otherwise it is a sibling + `RemoteTransform2D` / `RemoteTransform3D`. Typical split: persistent `Main`, `World` (levels swap), and a sibling `GUI` (does not die with the level).

### Pure core (both sizes)

A rule that deserves a test without a scene (score, turns, costs, who wins) goes in a pure script **next to the node that uses it**: `match/match.gd` (the node) and `match/match_rules.gd` (the core). It is the contract the kits follow (`GridBoard` + `CellGrid`, `TurnClock` + `TurnCycle`, `Wallet` + `Purse`).

- `extends RefCounted`. Created with `new()` in the node and in tests.
- It does not touch `Node`, `Input`, `MultiplayerAPI`, `get_tree()`, `@rpc`, or a scene `await`. It does not read autoloads.
- It receives numbers or Resources through its constructor or as arguments. The numbers come from the node's inspector or from a `.tres`: the core keeps no balance in constants.
- The node wraps it: it passes its `@export`s, calls its methods, and emits the signals. A person sees the node; the core adds nothing to touch.
- It is optional. If the rule is three lines, they stay in the node.

There is no separate `domain/` folder.

### Where each thing lives

| What | Use | Not |
|------|-----|-----|
| Types with variants (projectile A or B, scout or tank) | `class_name XType extends Resource` + one `x_type.tres` per variant | `if kind ==`, an autoload of stats |
| Design numbers of an entity | The `.tres` of its type, or the root of its scene (rule 0) | The same number in two inspectors |
| Match rules (duration, lives) | `@export` on the `match.tscn` scene; a `match_config.tres` if someone who does not open scenes tunes it, several pieces read it, or there are several modes | Copied literals |
| Look (material, `Environment`, theme, curve) | A named file with a suffix ([godot-composition-first](../godot-composition-first/SKILL.md) §3.1) | An anonymous sub-resource someone will want to tweak |
| Current HP, active cooldown | A variable on the node, at runtime | Mutating the `.tres` |
| Score and lives of *this* match | `Match` node | An eternal `ScoreManager` |
| Actor behavior | Child node with a `class_name`, or a packed scene | A global manager |
| Pure helpers | `class_name` + `static func` | An empty singleton |
| Isolated global service that survives a scene change | Autoload in `autoloads/` (MpKit, the `Events` bus with signals only) | An autoload holding visual nodes or this round's score; registry, locator, or manager |

An autoload with values to tune is registered as a scene (`.tscn`) or reads a `.tres`: a script autoload has no inspector.

UI text in the product language, in the translation file; code identifiers in English.

## 3. How to add a feature

Checklist: [adding-features.md](adding-features.md). Tests: [godot-testing](../godot-testing/SKILL.md).

## 4. IDs (if multiplayer)

Logical slot = HUD and lives. ENet peer = RPC only. HUD: `MpKit.local_slot()`.

## Anti-patterns

- `World.gd` that paints, spawns enemies, scores, and changes scene.
- `if kind == "fast"` on the projectile instead of a type `.tres`.
- Mutating a shared Resource (`type.damage = 3`).
- New feature via deep script inheritance.
- Autoload for something that is a node or a Resource.
- Invented patterns (registry, service locator, manager of managers).
- `domain/`, `core/`, or `features/` folders in a project that did not declare Clean.

Examples: [examples.md](examples.md).
