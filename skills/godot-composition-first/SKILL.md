---
name: godot-composition-first
description: >-
  Design Godot 4 scenes by composition: child nodes, packed scenes,
  FsmMachine, FX passes, typed @export sockets, %UniqueName, InputMap, and the
  value on the node that uses it; Resources (.tres) only for shared types.
  Prefer reusing components in shared/addons. Use when creating or editing .tscn,
  GDScript, shaders (Godot Shaders / Shadertoy), 2D sprites (Aseprite MCP),
  image pixel fonts, 3D models (Blender MCP), procedural materials (Material Maker), FSM, HUD,
  touch controls (VirtualJoystick, TouchScreenButton, drag to look), or choosing between inheritance,
  constants, Resources, and the inspector.
---

# Godot — composition, editor, and reuse

Companion to [godot-layered-architecture](../godot-layered-architecture/SKILL.md). This skill decides **how the tree and data are built**.

Priority: simple and predictable, composition, nodes/editor, reuse. Code conventions, patterns, and review: [godot-code-quality](../godot-code-quality/SKILL.md). Tests: [godot-testing](../godot-testing/SKILL.md).

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

## 2. `@export` sockets and `%UniqueName`

Between components / scenes: a **typed socket**, not a fragile path.

```gdscript
@export var health: Health
```

The parent (or the inspector) assigns the reference. The child does not `get_node("../../Health")`.

Inside **this** scene: `%UniqueName` — `@onready var sprite: Sprite2D = %Sprite2D`.

If a required socket is empty: `@tool` + `_get_configuration_warnings()` (the inspector warns; do not wait for an `assert` in `_ready`).

## 3. Nodes and editor beat code

The `.tscn` and the inspector are the source of truth for **look, layout, and per-instance tunables**. "Editor first" = the value lives **on the node that uses it**, visible in the inspector; not a `.tres` or an intermediate pointer for everything (rule 0 of [godot-code-quality](../godot-code-quality/SKILL.md)). If changing a number means opening more than 2 files, the design is wrong.

Do: `@export` / `@export_group` / `@export_range`; default on the scene; the script **does not** overwrite the saved value.

Do not: `_ready` that copies round rules onto a look `@export`; an autoload dump of 80 shader floats; a tag or string that points at another resource.

Round rules: `@export` on the `Match` node. If you tweak look in play and lose it on reload, the knob was in the wrong place.

Motion / juicy: [godot-animation](../godot-animation/SKILL.md) and [godot-juicy](../godot-juicy/SKILL.md). Tween **or** `AnimationPlayer` per clip; knobs in the inspector. The 12 principles apply either way. FSM: [godot-fsm](../godot-fsm/SKILL.md). 2D platformer: [godot-platformer-2d](../godot-platformer-2d/SKILL.md).

## 3.1 Data Resources = shared types

A **data** `.tres` exists when **several things share it** or when **it is edited as a type**: `class_name XData extends Resource` + one `.tres` per variant. One `projectile.tscn`; `projectile_fast.tres` / `projectile_slow.tres` on `@export var data`. A value that a single scene uses is an `@export` on the node, not a `.tres`.

That rule is for data. The **look** (a material, an `Environment`, a theme, a procedural texture) is an asset: always a named file (`stone.tres`, `world_env.tres`), even when a single scene uses it, and never a sub-resource inside a wiring scene (the world, `Main`). RULES.md decides the folder ([godot-code-quality](../godot-code-quality/SKILL.md) §1).

A Resource whose only content is a `Dictionary` or an `Array` (name → material, a list of materials per sprite) is not a type anyone edits: it is a lookup table in disguise. Each element is its own file, or an `@export` on the node that uses it.

Current HP on the node. Do not mutate the `.tres` (`duplicate()` if you need a copy). Guide: [resources.md](resources.md).

## 4. InputMap

Semantic actions in Project Settings → Input Map: `move_left`, `attack`, `pause`. Not `KEY_A` / `press_shift`.

- Continuous / hold movement: `_physics_process` + `Input.get_vector(...)`.
- Gameplay one-shot (jump, attack): `_unhandled_input` (UI may already have consumed the event).
- `_input` only to intercept (pause, remap).
- Phone or tablet: `VirtualJoystick` and `TouchScreenButton` press the same actions; the game reads no touches. Showing them only on phones, looking by dragging in 3D and one-press actions: [touch.md](touch.md).

The input catcher calls `apply_*` (on a network, the actor's `MpInput` sends the actions and the server applies); it does not spawn or score.

## 5. Reuse

Before writing a script in `features/` or `scenes/`:

1. Does it already exist in `shared/` or `addons/`?
2. Second caller → it is born in `shared/` or `addons/`, not forked per title.
3. API: past-tense signals + `@export`. Zero score or product copy.

| Piece | Reusable shape |
|-------|----------------|
| FSM | addon `fsm_kit`: `FsmMachine` + `FsmState`; the actor is injected (`@export var actor`) |
| 2D platformer | addon `plat_kit`: `PlatMotor` (coyote, buffer, apex). Dash/stamina = glue |
| Health / hit | `Health` + Hitbox/Hurtbox packed scenes |
| Post-process | CanvasLayer stack; **one pass = one packed scene** |
| Authority / sync | `MpAuthority` (addon) |
| UI copy | strings module |
| Shared types | Resource + `.tres` |

A pass (bloom, grain, distortion) = `BackBufferCopy` + `ColorRect` + its own shader. The stack does not know the game. A pickup does not put logic inside another pass’s shader: it tweens **that** pass.

Shaders: one effect, one file. **Do not invent** the FX if a catalog exists: [Godot Shaders](https://godotshaders.com/shader/?orderby=date&order=DESC) first; [Shadertoy](https://www.shadertoy.com) if you need to port. Guide: [assets.md](assets.md).

2D sprites: **ask** if they want MCP/sprites and ask for **references**. Skill [godot-animation](../godot-animation/SKILL.md). If yes: [Aseprite](https://github.com/diivi/aseprite-mcp) MCP ([assets.md](assets.md)). If no: placeholder. Do not invent a sprite.

3D: **ask** if they want the [Blender](https://www.blender.org/lab/mcp-server/) MCP. If yes: install it, ask for references, and the model comes in as the `.blend` itself or as a `.glb`. If no: placeholder. Details in [assets.md](assets.md).

Materials / textures (floor, wall, terrain, 2D tile): **ask** if they want them created with [Material Maker](https://github.com/RodZill4/material-maker) and ask for references. Each surface is a `.tres` picked in the inspector; on an imported model, in its import: **Advanced…** › the material › **Use External** with the `.tres` path, not in code or by the slot name at runtime. Skill [godot-material-maker](../godot-material-maker/SKILL.md).

## 6. How to implement a component

1. Small packed scene + `class_name`.
2. `@export` knobs. Warnings if a socket is missing.
3. The feature **instances** the component in the scene. Do not `load` shaders by hand from the world. A reusable component that owns its shader (as `Sprite3D` owns its own) may `preload` it and build its material, with the knobs as the component's `@export`s.
4. Signals on the node itself; the parent connects. The `Events` bus only for systems that do not know each other. The FX pass does not call the session.
5. Per-player variant (tint): public method, does not read internal IDs.

## 7. Editor preview

Opening the scene in the editor shows the game as it looks at runtime: materials, props, the board. What only exists at runtime gets tuned blind.

- A look component (one that builds meshes, places props, applies a material) is `@tool`. An `@export` whose setter rebuilds it shows the change in the editor.
- What it generates is not saved into the scene: the children it adds have no `owner`, and a generated property leaves the save through `_validate_property` (without `PROPERTY_USAGE_STORAGE`).
- Game logic (input, timers, match signals) does not run in the editor: cut it with `Engine.is_editor_hint()` in `_ready` and `_process`. The preview does run.
- Procedural content takes an `@export var preview_seed`, so the editor shows a fixed result.

## Anti-patterns

- God-node `World.gd` that draws FX, spawns, scores, and changes scene.
- Giant `match kind` on the actor.
- Duplicating a shader “a little different” in two features.
- Collision layers that differ in code vs the inspector.
- 100% code-created children when a packed scene would make them editable.
- Mutating the type `.tres` at runtime.
- A data `.tres` that a single scene uses, or one that points at another through a tag or a string.
- A Resource that is only a `Dictionary` or an `Array` (name → resource).
- Materials or an `Environment` embedded as sub-resources in the world scene.
- A look that only exists at runtime: materials assigned in `_ready`, props made in code with no preview.

## Checklist

- [ ] Does removing a child turn the behavior off?
- [ ] Can it be tuned in the inspector, on the node that uses the value? Does changing a number open 2 files at most?
- [ ] `@export` / `%UniqueName` sockets instead of `../..` paths?
- [ ] InputMap, not scancodes?
- [ ] Shared variants = Resources; a value of a single scene = `@export`?
- [ ] Is every material, `Environment` and theme a named file?
- [ ] Does the scene look in the editor as it does in the game (materials, props)? Which part of the look only exists at runtime, and why?
- [ ] Does the scene run with F6?
- [ ] Catalog shader or documented port? 2D sprite: user OK + references + Aseprite, or placeholder? 3D: OK + Blender MCP + `.blend` or `.glb`, or placeholder?

Patterns: [patterns.md](patterns.md). Resources: [resources.md](resources.md). Assets: [assets.md](assets.md). Code: [examples.md](examples.md).
