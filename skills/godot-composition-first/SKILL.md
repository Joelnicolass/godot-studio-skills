---
name: godot-composition-first
description: >-
  Design Godot 4 scenes by composition: child nodes, packed scenes,
  FsmMachine, FX passes, typed @export references, %UniqueName, InputMap, one
  owner per number, type Resources (.tres), catalogs, inherited scenes, and
  the editor preview. Prefer reusing components in shared/addons. Use when creating or editing .tscn,
  GDScript, shaders (Godot Shaders / Shadertoy), 2D sprites (Aseprite MCP),
  image pixel fonts, 3D models (Blender MCP), procedural materials (Material Maker), FSM, HUD,
  touch controls (VirtualJoystick, TouchScreenButton, drag to look), or choosing between inheritance,
  constants, Resources, and the inspector.
---

# Godot — composition, editor, and reuse

Companion to [godot-layered-architecture](../godot-layered-architecture/SKILL.md). This skill decides **how the tree and data are built**.

Priority: simple and predictable, composition, nodes and editor, reuse. Where each number lives, folders, patterns, and review: [godot-code-quality](../godot-code-quality/SKILL.md). Tests: [godot-testing](../godot-testing/SKILL.md).

## 1. Composition beats inheritance

The actor is a **thin container**: physics + orchestration. Behavior lives in children.

```
Actor (CharacterBody2D or RigidBody2D)
├── Visual          Sprite2D / MeshInstance
├── Health          reusable component
├── Hitbox/Hurtbox  Area2D packed scenes
├── States          FsmMachine
│   ├── Idle
│   ├── Move
│   └── Hurt
└── MultiplayerSynchronizer   # if networked
```

- States = `FsmState` nodes under an `FsmMachine` (addon `fsm_kit`), not a 200-line `enum` + `match`.
- Input is **another node** (InputMap), not mixed with physics.
- A new FX is a child or packed scene, not another parameter on the superclass.

Inheritance only for the minimum contract (`FsmState extends Node`, `FxPass extends Control`). If you are about to write `class EliteEnemy extends Enemy` with more systems, stop: compose.

## 2. `@export` references and `%UniqueName`

Between components or scenes: a **typed reference**, not a fragile path.

```gdscript
@export var health: Health
```

The parent (or the inspector) assigns the reference. The child does not `get_node("../../Health")`.

Inside **this** scene: `%UniqueName` — `@onready var sprite: Sprite2D = %Sprite2D`.

If a required reference is empty: `@tool` + `_get_configuration_warnings()` (the inspector warns; do not wait for an `assert` in `_ready`).

## 3. Nodes and editor beat code

The `.tscn` and the inspector are the source of truth for **look, layout, and knobs**. Where each number lives (one owner: the type or the root), when a `.tres` exists, and what a catalog is: rule 0 of [godot-code-quality](../godot-code-quality/SKILL.md). Each design knob has its row in `docs/tuning.md`.

Do: `@export` / `@export_group` / `@export_range` with a unit and a `##`; the default on the scene; the script **does not** overwrite the saved value.

Do not: a `_ready` that copies match rules onto a look `@export`; an autoload dump of 80 shader floats; a color or a design number written in code.

To tune with the game running: edit the local scene (not the *Remote* tree) with *Debug › Synchronize Scene Changes* on. The change shows in the game and stays saved; what you touch in *Remote* is lost.

Motion / juicy: [godot-animation](../godot-animation/SKILL.md) and [godot-juicy](../godot-juicy/SKILL.md). Tween **or** `AnimationPlayer` per clip; the knobs and the curve in the inspector. FSM: [godot-fsm](../godot-fsm/SKILL.md). 2D platformer: [godot-platformer-2d](../godot-platformer-2d/SKILL.md).

## 3.1 Data, variants, and look

**Data.** A type with variants is `class_name XType extends Resource` + one `x_type.tres` per variant: one `projectile.tscn`, and `fast_projectile_type.tres` / `slow_projectile_type.tres` on `@export var type`. When a `.tres` exists and when it is an `@export`: rule 0.

**Variants.** Other numbers: another `_type.tres`. Another structure or other art (another mesh, one more particle): *New Inherited Scene* of the base scene, and only what differs changes. One level of inheritance, no more. Nothing is copied node by node.

**Look.** Every look resource someone will want to tweak or reuse is a named file with a suffix (`stone_material.tres`, `forest_env.tres`): materials, `Environment`, themes, curves, particle gradients, procedural textures. Resources with no art decision stay embedded in the scene: collision shapes, primitive placeholder meshes, a `StyleBox` the theme already defines. The folder: [godot-code-quality](../godot-code-quality/SKILL.md) §1.

**Colors the game picks** (teams, rarity): they come from an `@export` or a named palette (`@export var team_colors: Array[Color]`), never from a literal in code.

Current HP on the node. Do not mutate the `.tres` (`duplicate()` if you need a copy). Guide: [resources.md](resources.md).

## 4. InputMap

Semantic actions in Project Settings → Input Map: `move_left`, `attack`, `pause`. Not `KEY_A` / `press_shift`.

- Continuous / hold movement: `_physics_process` + `Input.get_vector(...)`.
- Gameplay one-shot (jump, attack): `_unhandled_input` (UI may already have consumed the event).
- `_input` only to intercept (pause, remap).
- Phone or tablet: `VirtualJoystick` and `TouchScreenButton` press the same actions; the game reads no touches. Showing them only on phones, looking by dragging in 3D and one-press actions: [touch.md](touch.md).

The input catcher calls `apply_*` (on a network, the actor's `MpInput` sends the actions and the server applies); it does not spawn or score.

## 5. Reuse

Before writing a new script:

1. Does it already exist in `shared/` or `addons/`?
2. The second entity that uses it → it moves to `shared/` (or `systems/`); if it serves another game, to `addons/`. Not a copy per title.
3. API: past-tense signals + `@export`. No score and no product text.

| Piece | Reusable shape |
|-------|----------------|
| FSM | addon `fsm_kit`: `FsmMachine` + `FsmState`; the actor is injected (`@export var actor`) |
| 2D platformer | addon `plat_kit`: `PlatMotor` (coyote, buffer, apex). Dash/stamina = game code |
| Health / hit | `Health` + Hitbox/Hurtbox packed scenes |
| Post-process | CanvasLayer stack; **one pass = one packed scene** |
| Authority / sync | `MpAuthority` (addon) |
| UI text | translation file (CSV in `locale/`) + `tr()` |
| Types with variants | Resource + `_type.tres` |

A pass (bloom, grain, distortion) = `BackBufferCopy` + `ColorRect` + its own shader. The stack does not know the game. A pickup does not put logic inside another pass’s shader: it tweens **that** pass.

Shaders: one effect, one file. **Do not invent** the FX if a catalog exists: [Godot Shaders](https://godotshaders.com/shader/?orderby=date&order=DESC) first; [Shadertoy](https://www.shadertoy.com) if you need to port. Guide: [assets.md](assets.md).

2D sprites: **ask** if they want MCP/sprites and ask for **references**. Skill [godot-animation](../godot-animation/SKILL.md). If yes: [Aseprite](https://github.com/diivi/aseprite-mcp) MCP ([assets.md](assets.md)). If no: placeholder. Do not invent a sprite.

3D: **ask** if they want the [Blender](https://www.blender.org/lab/mcp-server/) MCP. If yes: install it, ask for references, and the model comes in as the `.blend` itself or as a `.glb`. If no: placeholder. Details in [assets.md](assets.md).

Materials / textures (floor, wall, terrain, 2D tile): **ask** if they want them created with [Material Maker](https://github.com/RodZill4/material-maker) and ask for references. Each surface is a `_material.tres` picked in the inspector; on an imported model, in its import: **Advanced…** › the material › **Use External** with the `.tres` path, not in code or by the slot name at runtime. Skill [godot-material-maker](../godot-material-maker/SKILL.md).

## 6. How to implement a component

1. Small packed scene + `class_name`.
2. `@export` knobs with a `##`, a range, and a unit. An editor warning if a reference is missing.
3. The feature **instances** the component in the scene. Do not `load` shaders by hand from the world. A reusable component that owns its shader (as `Sprite3D` owns its own) may `preload` it and build its material, with the knobs as the component's `@export`s.
4. Signals on the node itself; the parent connects. The `Events` bus only for systems that do not know each other. The FX pass does not call the session.
5. Per-player variant (a tint): a public method that takes the color; the color comes from an `@export` or a palette, not from code.

## 7. Editor preview

Opening the scene in the editor shows the game as it looks at runtime: materials, props, the board. What only exists at runtime gets tuned blind.

- Before `@tool`, ask whether it can be in the `.tscn`. What shows because it is in the scene needs no code.
- A look component (one that builds meshes, places props, applies a material) is `@tool`. An `@export` whose setter rebuilds it shows the change in the editor.
- If the look comes from a Resource (`@export var type: UnitType`), the setter does **not** run when a property of that Resource is edited: connect its `changed` signal and rebuild there. Otherwise someone changes the `.tres` and the preview never finds out.
- `@tool` only on look components. Every script a `@tool` uses is `@tool` too. In the editor, no `queue_free` on saved nodes and no writing properties that get saved.
- What it generates is not saved into the scene: the children it adds have no `owner`, and a generated property leaves the save through `_validate_property` (without `PROPERTY_USAGE_STORAGE`).
- Game logic (input, timers, match signals) does not run in the editor: cut it with `Engine.is_editor_hint()` in `_ready` and `_process`. The preview does run.
- Procedural content takes an `@export var preview_seed`, so the editor shows a fixed result.
- A curve an artist tunes is an `@export var curve: Curve` (drawn in the inspector) or an `AnimationPlayer` clip. A `Tween` also exports its `Tween.TransitionType` and its `Tween.EaseType`; they never stay in code.
- Whoever implements says, for each new scene, what a person should see when opening it in the editor without running it.

Docs: [running code in the editor](https://docs.godotengine.org/en/stable/tutorials/plugins/running_code_in_the_editor.html).

## Anti-patterns

- God-node `World.gd` that draws effects, spawns enemies, scores, and changes scene.
- Giant `match kind` on the actor.
- Duplicating a shader “a little different” in two features.
- Collision layers that differ in code vs the inspector.
- 100% code-created children when a packed scene would make them editable.
- Mutating the type `.tres` at runtime.
- The same number in two inspectors, or a `.tres` → `.tres` chain to find it.
- A blind table: an untyped `Dictionary` or anonymous sub-resources (rule 0).
- A material, an `Environment`, or a theme someone will tweak, embedded as a sub-resource.
- A look that only exists at runtime: materials assigned in `_ready`, props made in code with no preview.
- The curve of a `Tween` (`TRANS_*`, `EASE_*`) written in code.
- A variant made by copying nodes instead of an inherited scene.

## Checklist

- [ ] Does removing a child turn the behavior off?
- [ ] Does each design number have a single owner and its row in `docs/tuning.md`? Does changing it open 2 files at most?
- [ ] Does each `@export` have a `##`, a range, and a unit?
- [ ] `@export` / `%UniqueName` references instead of `../..` paths?
- [ ] InputMap, not scancodes?
- [ ] Number variants = `_type.tres`; structure variants = inherited scene?
- [ ] Is every material, `Environment`, theme, and curve that gets tweaked a named file with a suffix?
- [ ] Does the scene look in the editor as it does in the game (materials, props)? Which part of the look only exists at runtime, and why?
- [ ] Does the scene run with F6?
- [ ] Catalog shader or documented port? 2D sprite: user OK + references + Aseprite, or placeholder? 3D: OK + Blender MCP + `.blend` or `.glb`, or placeholder?

Patterns: [patterns.md](patterns.md). Resources: [resources.md](resources.md). Assets: [assets.md](assets.md). Code: [examples.md](examples.md).
