---
name: godot-composition-first
description: >-
  Design Godot 4 scenes by composition: child nodes, packed scenes,
  StateMachine, FX passes, Resources (.tres) as type templates, typed @export
  sockets, %UniqueName, InputMap, and editor values over hardcoding. Prefer
  reusing components in shared/addons. Use when creating or editing .tscn,
  GDScript, shaders, FSM, HUD, or choosing between inheritance, constants,
  Resources, and the inspector.
---

# Godot — composition, editor, and reuse

Companion to [godot-layered-architecture](../godot-layered-architecture/SKILL.md). This skill decides **how the tree and data are built**.

Priority: composition, nodes/editor, reuse. Tests: [godot-testing](../godot-testing/SKILL.md).

## 1. Composition beats inheritance

The actor is a **thin container**: physics + orchestration. Behavior lives in children.

```
Actor (CharacterBody2D or RigidBody2D)
├── Visual          Sprite2D / MeshInstance
├── Health          reusable component
├── Hitbox/Hurtbox  Area2D packed scenes
├── States          StateMachine
│   ├── Idle
│   ├── Move
│   └── Hurt
└── MultiplayerSynchronizer   # if networked
```

- States = `State` nodes under a `StateMachine`, not a 200-line `enum` + `match`.
- Input is **another node** (InputMap), not mixed with physics.
- A new FX is a child or packed scene, not another parameter on the superclass.

Inheritance only for the minimum contract (`State extends Node`, `FxPass extends Control`). If you are about to write `class EliteEnemy extends Enemy` with more systems, stop: compose.

## 2. `@export` sockets and `%UniqueName`

Between components / scenes: a **typed socket**, not a fragile path.

```gdscript
@export var health: Health
```

The parent (or the inspector) assigns the reference. The child does not `get_node("../../Health")`.

Inside **this** scene: `%UniqueName` — `@onready var sprite: Sprite2D = %Sprite2D`.

If a required socket is empty: `@tool` + `_get_configuration_warnings()` (the inspector warns; do not wait for an `assert` in `_ready`).

## 3. Nodes and editor beat code

The `.tscn` and the inspector are the source of truth for **look, layout, and per-instance tunables**.

Do: `@export` / `@export_group` / `@export_range`; default on the scene; the script **does not** overwrite the saved value.

Do not: `_ready` that copies round rules onto a look `@export`; an autoload dump of 80 shader floats.

`MatchRules.tres` = **round rules**. If you tweak look in play and lose it on reload, the knob was in the wrong place.

## 3.1 Resources = type templates

Content types: `class_name XData extends Resource` + one `.tres` per type. One `projectile.tscn`; `projectile_fast.tres` / `projectile_slow.tres` on `@export var data`.

Current HP on the node. Do not mutate the `.tres` (`duplicate()` if you need a copy). Guide: [resources.md](resources.md).

## 4. InputMap

Semantic actions in Project Settings → Input Map: `move_left`, `attack`, `pause`. Not `KEY_A` / `press_shift`.

- Continuous / hold movement: `_physics_process` + `Input.get_vector(...)`.
- Gameplay one-shot (jump, attack): `_unhandled_input` (UI may already have consumed the event).
- `_input` only to intercept (pause, remap).

The input catcher calls `apply_*` / `submit_*`; it does not spawn or score.

## 5. Reuse

Before writing a script in `features/` or `scenes/`:

1. Does it already exist in `shared/` or `addons/`?
2. Second caller → it is born in `shared/` or `addons/`, not forked per title.
3. API: past-tense signals + `@export`. Zero score or product copy.

| Piece | Reusable shape |
|-------|----------------|
| FSM | `StateMachine` + `State`; the actor is injected (`@export var actor: Node`) |
| Health / hit | `Health` + Hitbox/Hurtbox packed scenes |
| Post-process | CanvasLayer stack; **one pass = one packed scene** |
| Authority / sync | `MpAuthority` (addon) |
| UI copy | strings module |
| Types | Resource + `.tres` |

A pass (bloom, grain, distortion) = `BackBufferCopy` + `ColorRect` + its own shader. The stack does not know the game. A pickup does not put logic inside another pass’s shader: it tweens **that** pass.

Shaders: one effect, one file.

## 6. How to implement a component

1. Small packed scene + `class_name`.
2. `@export` knobs. Warnings if a socket is missing.
3. The feature **instances** the component in the scene. Do not `load` shaders by hand from the world.
4. Signals on the node itself (or a bus if there is no common ancestor). The FX pass does not call the session.
5. Per-player variant (tint): public method, does not read internal IDs.

## Anti-patterns

- God-node `World.gd` that draws FX, spawns, scores, and changes scene.
- Giant `match kind` on the actor.
- Duplicating a shader “a little different” in two features.
- Collision layers that differ in code vs the inspector.
- 100% code-created children when a packed scene would make them editable.
- Mutating the type `.tres` at runtime.

## Checklist

- [ ] Does removing a child turn the behavior off?
- [ ] Can it be tuned in the inspector (node or `.tres`)?
- [ ] `@export` / `%UniqueName` sockets instead of `../..` paths?
- [ ] InputMap, not scancodes?
- [ ] Variants = Resources?
- [ ] Does the scene run with F6?

Patterns: [patterns.md](patterns.md). Resources: [resources.md](resources.md). Code: [examples.md](examples.md).
