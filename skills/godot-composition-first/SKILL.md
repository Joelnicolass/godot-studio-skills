---
name: godot-composition-first
description: >-
  Design Godot 4 scenes by composition: child nodes, packed scenes,
  StateMachine, FX stacks, Resources (.tres) as bullet, enemy, and power-up
  templates, @export and editor values over hardcoding. Prefer reusing
  components in shared/addons. Use when creating or editing .tscn, GDScript,
  shaders, FSM, trails, HUD, or choosing between inheritance, constants,
  Resources, and the inspector.
---

# Godot — composition, editor, and reuse

Companion to [godot-layered-architecture](../godot-layered-architecture/SKILL.md) (that skill **asks** Clean vs standard). This skill decides **how the tree and data are built**, not whether a `domain/` folder exists.

## Priorities (always)

Always prioritize:

- architecture that is easy to scale and clean in layers
- composition structures always take priority
- nodes and editor configuration always take priority
- component reusability always takes priority

## 1. Composition beats inheritance

The pawn / actor is a **thin container**: physics + orchestration. Behavior lives in children.

```
Pawn (RigidBody2D / CharacterBody2D)     ← little code, authority claims
├── Hull          Polygon2D / Sprite2D
├── Trail         reusable component
├── Feedback      force preview, aim, etc.
├── States        StateMachine
│   ├── Coasting
│   ├── Aiming
│   └── Eliminated
└── MultiplayerSynchronizer
```

- States = `State` nodes under a `StateMachine`, not a 200-line `enum` + `match` on the pawn.
- Input (stick, button, pointer) is **another node** (often a sibling in the world), not mixed with physics.
- A new FX is a child or packed scene, not another parameter on the superclass.

Inheritance only for the minimum contract (`State extends Node`, `CrtPass extends Control`). If you are about to write `class EliteEnemy extends Enemy` with more systems, stop: compose.

## 2. Nodes and editor config beat code

The `.tscn` and the inspector are the source of truth for **look, layout, and per-instance tunables**.

Do:

- `@export` / `@export_group` / `@export_range` for knobs a human will tweak (colors, shader amplitudes, lags, “react to audio”).
- Leave the default on the scene. The script declares the type and a reasonable fallback; it **does not** overwrite the saved value.
- Materials and shaders: knobs on the pass material, not rewritten from a constants autoload.
- HUD layout: anchors, `mouse_filter`, layers — on the scene.

Do not:

- `_init` / `_ready` that copies `GameConstants.FOO` onto a look `@export`. That kills the editor.
- A single `GameConstants` with 80 shader/post-process floats. That does not scale to another title or two different instances.
- Early `return` in `fragment()` or other hacks that leave the `ColorRect` opaque when toggling a pass.

`GameConstants` (or a `MatchRules.tres`) stays for **round rules**: duration, lives, layers. If you tweak look in play and lose the value on reload, the knob was in the wrong place.

## 2.1 Resources = type templates (priority)

Numbers / refs that define **a content type** (another bullet, enemy, power-up): **not** an `enum` + `match` or 40 constants. They go in a `class_name XData extends Resource` and one `.tres` per type.

- One `bullet.tscn`; `plasma.tres` / `spread.tres` assigned to `@export var data`.
- Definition stats (damage, speed, icon, PackedScene) on the Resource.
- Current HP, active cooldown: on the node. Do not mutate the shared `.tres` (`duplicate()` if you need a working copy).
- External `.tres` if several scenes reuse it; built-in only if it belongs to that instance.

Full guide: [resources.md](resources.md).

## 3. Component reuse

Before writing a script in `features/` or `scenes/`:

1. Does it already exist in `src/shared/` or `addons/`?
2. If not, will a second caller need it (another feature, another game, editor preview)? → born in the game’s `shared/` or the framework `addons/`, not forked per title.
3. Component API: signals + `@export`. Zero score names, slots, or product copy.

Patterns to extract, not duplicate:

| Piece | Reusable form |
|-------|----------------|
| World wrap | static helper (`Wrap2D.wrap_position`) |
| FSM | generic `StateMachine` + `State`; the state may ask the parent |
| Post-process | `PostFxStack` (CanvasLayer) + **one pass = one packed scene** |
| Authority / sync | `MpAuthority` (addon), not copied into every pawn |
| UI copy | a strings module, not literals on every button |
| Entity types | `class_name` Resource + `.tres` template, not a script per stats variant |

A pass (CRT, ripple, bloom) is a node with `BackBufferCopy` + `ColorRect` + its own shader. The stack does not know the game. Turning on slow-time does not mix ripple **inside** the CRT shader: tween the ripple pass.

Shaders: one effect, one file. Compose in the tree, not in an uber-shader.

## 4. How to implement a new component

1. Small packed scene (`shared/` or `scenes/components/`) + `class_name` script.
2. `@export` knobs. Try them in the inspector with the game paused / a tool button if preview is needed.
3. The feature **instances** the component (child of the world or pawn scene). Do not `load` the shader and set uniforms by hand from the arena.
4. Communication: `GameEvents` or the node’s own signals. The CRT does not call `GameSession`.
5. If the component has a per-player variant (trail color), it receives a tint via a public method — it does not read `PlayerId` internally if that can be avoided.

## 5. Anti-patterns

- God-node `Arena.gd` / `World.gd` that draws FX, spawns, scores, and changes scene.
- Giant `match state` or `match bullet_kind` on the pawn.
- Duplicating `crt.gdshader` “a little different” in two features.
- Collision layers set only in code **and** differently in the inspector (pick inspector + one business **layer index** constant).
- Children created 100% in code when a packed scene would make them editable.
- Mutating `plasma.tres` at runtime and affecting every bullet.

## Checklist

- [ ] Can this behavior be turned off/reordered by removing or moving a child node?
- [ ] Can a designer tune it in the inspector (node or `.tres`) without touching GDScript?
- [ ] Does the container script still orchestrate, not implement the effect?
- [ ] Are type variants Resources, not `if kind`?
- [ ] Does it live in `shared/` or `addons/` if it is not a rule of this genre?
- [ ] Does the component not score or mix responsibilities?

Concrete patterns: [patterns.md](patterns.md). Resources: [resources.md](resources.md). Generic code: [examples.md](examples.md).
