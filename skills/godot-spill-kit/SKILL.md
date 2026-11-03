---
name: godot-spill-kit
description: >-
  Blood and any other substance a body spills in a Godot 4 3D game, with the
  SpillKit addon: every hit sprays drops and leaves marks on the floor that stay
  for the whole match, and a death grows a puddle that follows the slope and
  stays off a curb. Each substance is a type in the inspector (blood, ichor, oil,
  slime, ink) with the kit's wet look, PBR textures of its own (albedo, normal,
  ORM) or the game's shader (PS1). Rules as values (heavy hit at 40 %, sprays
  every 0.25 s), one property for the network, Compatibility and WebGL 2,
  nothing on a dedicated server, buttons to try it in the editor. Use when the
  user wants blood, gore, sprays, marks on the floor, puddles on death, a bug's
  ichor, oil leaking from a barrel, or /add-spill. Not the game's HP or damage,
  nor its network.
---

# Godot — what a body spills (SpillKit)

Addon `addons/spill_kit/` in the **game** project. Reference: `addons/spill_kit/README.md`; API by piece: [api.md](api.md).

If the addon is missing:

```bash
./install.sh --addon /path/to/godot-project spill_kit
```

Enable plugin **SpillKit** (the cost line in the inspector; the nodes, their buttons and their warnings work without it). Bounded request: `/add-spill`. Composition: [godot-composition-first](../godot-composition-first/SKILL.md).

## Rules

- **Three calls.** A `SpillSource3D` at the body's chest with its `type`. The game calls `hit(damage, max_hp, from)` where it takes HP off and `die()` when it dies. The rules (heavy at 40 %, light ones every 0.25 s, small hits adding up) are values of the component, not game code.
- **One substance, one type.** One `SpillType` (`.tres`) per substance, shared by every body that spills it: colour, drops, marks, puddle and look. Start by copying one from `addons/spill_kit/examples/types/`.
- **The person tries it in the editor.** Selecting the component and pressing Spray, Heavy spray or Die (puddle) under "Try it" draws in the 3D view on the scene's floor. Tell them how; the agent sets up the nodes and the type with starting values.
- **One pool per level.** A `SpillPool3D` in the level, with the level's types in `types` (so their shaders compile at load and not on the first hit). Without it, the first component makes one with the default values.
- **The floor is a layer.** The pool's `floor_mask`: the floor and what can be marked. Bodies on another layer; the body itself is found on its own and never gets marks. Bodies of different heights (a low bug, a player): each component's `floor_reach_m`, its height plus what it tolerates in the air.
- **The look, in the type.** Colour only = the kit's wet look. PBR textures = `mark_` / `puddle_` / `drop_` + `albedo_texture`, `normal_texture`, `orm_texture` (as `GrassMesh`). The game's shader (PS1) = `mark_material` / `puddle_material` / `drop_material`, with `texture_parameter` and `color_parameter` for its uniforms' names (a drops' shader may take its colour from `COLOR` and declare none).
- **No kit depends on another.** SpillKit has no network: a network game calls `hit()` and `die()` only on the authority and syncs `wound`.
- **The pool's inspector tells the cost.** Drops, marks, puddles and draw calls; nothing is made per hit.

## Network

**With MpKit:** in the body's `MpActor`, `Spill:wound` in **Sync › sync_extra** (everything travels at spawn, so a late joiner starts from the current value), and the damage behind the authority:

```gdscript
func take_damage(amount: float, from: Vector3) -> void:
	if not MpKit.is_authority():
		return
	hp -= amount
	$Spill.hit(amount, max_hp, from)
	if hp <= 0.0:
		$Spill.die()
```

On a dedicated server, an export with the `dedicated_server` feature (or run headless) builds nothing. One run with the editor headless does: `pool.shown = not MpKit.is_dedicated()` in the game's glue.

**With Godot's `MultiplayerSynchronizer`:** the property `Spill:wound`, with Spawn on and Replicate On Change; `hit()` and `die()` behind `multiplayer.is_server()`.

## Tree

```
Level
├── SpillPool3D                    # types: the level's types; floor_mask: the floor
├── Floor (StaticBody3D)           # on the floor's layer
└── Enemy (CharacterBody3D)        # on another layer: the floor rays go through it
    ├── Health (the game's HP component)   # on taking HP: Spill.hit(); on death: Spill.die()
    └── Spill (SpillSource3D)      # at the chest; type: green_blood.tres
```

Start from `addons/spill_kit/examples/minimal_3d/minimal_3d.tscn` (a dummy that bleeds) or `substances_3d` (six substances: the kit's look, PBR of its own, a shader of its own, a slope, a curb, night and a lamp).

## What goes where

| Kit | Game |
|---|---|
| When a hit bleeds and how much (`heavy_from`, `every_s`, `min_lost`) | The HP, the damage, where the hit came from |
| Drops, marks, puddles, their look | Which substances there are and who spills which |
| `wound`, one property | Who decides the damage and how `wound` travels |
| `shown`, `clear()` | The player's "blood" option, the rounds |

## Done when

- The component and the pool show no warnings, and the person tried (or knows how to try) Spray and Die (puddle) in the 3D view.
- F6: a hit sprays and marks the floor, a 40 % one comes out heavy, a death leaves a puddle.
- Networked: another instance sees the same sprays; one that joins late does not see the old ones.
- `godot --headless --path spillkit_lab --script res://addons/spill_kit/tests/spill_test_runner.gd` gives `SPILLKIT TESTS PASS` (in the kit's repo).

## Anti-patterns

- Making particles, decals or meshes on every hit: the pool reuses its own.
- The heavy-hit rule in the game's code: it is the component's `heavy_from` (and `heavy` in `hit()` for a finisher).
- Syncing every spray with an RPC: `wound` is a property; a late joiner compares counters.
- Calling `hit()` on every peer of a network game: only where damage is decided.
- One material per body: one type per substance, shared.
- Bodies on the floor's layer that are not the one bleeding: they get marks on top. Take them out of `floor_mask`.
- `Decal` or `GPUParticles3D` for the blood of a game that ships on the web: the kit uses MultiMesh and CPUParticles3D.
