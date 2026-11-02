---
name: godot-perception-kit
description: >-
  Gives a Godot 4 actor senses with the PerceptionKit addon, in 2D and 3D: a view
  cone that starts seeing at one distance and keeps seeing until a farther one,
  all-around awareness up close, walls that hide, noises heard by distance, any
  sense of the game's own (light, alarms, hits), a memory that forgets with the
  last known position, sides as physics layers, and handles to drag the view in
  the editor. Use when the user wants enemies or guards that see or hear the
  player, stealth, vision cones, line of sight, hearing noises, AI awareness or
  alert, investigating the last known position, darkness or light changing
  detection, or /add-perception. Not what the actor does about it (its state
  machine, chasing, combat) and not the network.
---

# Godot — perception (PerceptionKit)

Addon `addons/perception_kit/` in the **game** project. Reference: `addons/perception_kit/README.md`; API by piece: [api.md](api.md).

If the addon is missing:

```bash
./install.sh --addon /path/to/godot-project perception_kit
```

Enable plugin **PerceptionKit** (the handles in the editor; the nodes work without it). Bounded request: `/add-perception`. Composition: [godot-composition-first](../godot-composition-first/SKILL.md); the actor's states: [godot-fsm](../godot-fsm/SKILL.md).

## Rules

- **The person sizes the view, the agent sets it up.** Sight, lose, angle, near and eye height are dragged with the sensor's handles in the actor's scene (2D or 3D view; every drag undoes). The agent adds the nodes with starting values and tells the person how to drag them; it never tunes them by code at runtime.
- **Two nodes.** A `PerceptionSensor3D` (or 2D) on the actor's head (it looks along -Z; 2D along +X), a `PerceptionTarget3D` (or 2D) on what is seen, where it is seen from (the chest). Their spheres are internal; no CollisionShape to add.
- **Sides are physics layers.** A target's collision layer is its side; a sensor's mask is what it sees. Name a layer per side in Project Settings; out of the box everything is on layer 1, like any area. No faction enum, no groups.
- **Values live on the node that uses them** (`@export`): the sensor's radii, angle, `memory_s`, `sense_hz`, scales; the target's `visibility`, `kind`. Per-actor values in the actor's scene, one file.
- **States read, signals start and end.** `perceived` starts an alert, `forgotten` ends it; while it lasts the states read `latest()` (where to look or go), `sees_any()`, `is_aware()`. The kit has no state machine; the game's (FsmKit or its own) reads the sensor through an exported reference.
- **Noises come from the game.** The game's own noise signal calls `sensor.hear(position, radius, source)` on the sensors that listen; `source` keeps one memory per noise maker. Other senses: `sensor.sense(&"kind", position, strength, source)`.
- **Light and dark are numbers.** The game sets `target.visibility` (shade, cover), `sensor.sight_scale` (night, fog) and `reach_by_kind` (`{&"light": 2.5}` for a lamp that is its own target of kind light). Anything else: a script `extends PerceptionSensor3D` overriding `_sight_radius(target, seen, radius)` (and `reach_m()` if it returns more).
- **No kit depends on another.** PerceptionKit has no network: a networked game sets `enabled = <is authority>` and syncs what the actor does, never the perception.
- **The cost is the looks.** `sense_hz` (5) times the sensors; each sensor at its own moment, one ray per candidate that passes the radius and angle. Lower `sense_hz`, then the radii.

## Tree

```
Guard (CharacterBody3D)           # the sensor's own body: found on its own, never hides its view
├── Head (Node3D)                  # what turns to look
│   └── Perception (PerceptionSensor3D)   # mask: the sides it sees; occlusion_mask: the walls
└── States (the game's state machine)     # reads Perception: latest(), sees_any(), is_aware()

Player (CharacterBody3D)
└── Seen (PerceptionTarget3D)      # on its side's layer, at the chest
```

Start from `addons/perception_kit/examples/minimal_3d/minimal_3d.tscn` (a guard turning its head), `minimal_2d` (the same in 2D) or `guards_3d` (watch, look, search, go home; a noise, a lamp, night, shade).

## What belongs where

| Kit | Game |
|---|---|
| The view, the lose radius, near awareness, walls, the memory | What the actor does (states, alert levels, chasing, combat) |
| `hear()`, `sense()` | Where noises come from and how far they carry |
| `visibility`, `sight_scale`, `reach_by_kind`, `_sight_radius()` | Light, darkness, cover and what they mean |
| Layers as sides, `enabled` | Which sides exist, who perceives in a networked game |

## Done when

- The sensor shows no warning; its view shows in the 3D (or 2D) view and the person knows how to drag its handles.
- F6 with `show_in_game`: grey, red when it sees the target, amber after, grey once forgotten; a wall hides; a noise turns it.
- The actor's states react to `perceived` / `forgotten` and read `latest()`.
- `godot --headless --path perceptionkit_lab --script res://addons/perception_kit/tests/perception_test_runner.gd` gives `PERCEPTIONKIT TESTS PASS` (in the kit repo).

## Anti-patterns

- A manager or registry of every enemy that checks every player each frame: each sensor looks for itself, a few times a second.
- Raycasting every frame from the actor's script: `sense_hz` and the sensor's own ray.
- Sides as an enum or a group checked in code: they are layers, filtered by the physics engine.
- Adding a CollisionShape under a sensor or target: their spheres are internal and sized by the values.
- Tuning the radii by code at runtime for a person's level: drag the handles; code changes `sight_scale` and `visibility`.
- Perceiving on every peer of a networked game: `enabled` only where the game decides (the server).
- The sensor under the actor's body without `body` found (no physics body above it): its own collider hides the view; set `body`.
