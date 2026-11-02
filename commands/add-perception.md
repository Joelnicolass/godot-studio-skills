---
description: "Perception (PerceptionKit addon): actors that see within a view cone and lose sight farther away, notice what is close, are blocked by walls, hear the game's noises and remember the last known position, in 2D or 3D, with handles to drag the view in the editor."
---

Give an **actor senses** in the **game's Godot project** with the PerceptionKit addon: a `PerceptionSensor3D` (or 2D) on its head, a `PerceptionTarget3D` (or 2D) on what it should see, the sides as physics layers, and the game's noises calling `hear()`. The person then sizes the view by dragging its handles in the actor's scene; the agent sets up and explains.

This is **not** what the actor does about it (its states, chasing, combat): that is the game's, reading the sensor. **Not** the network: a networked game decides who perceives (`enabled`). **Does not** invent the game's noises or light.

Load: `godot-perception-kit`, `godot-composition-first` (and `godot-fsm` for the actor's states).

If `addons/perception_kit/` is missing:

```bash
./install.sh --addon /ABS/GODOT_ROOT perception_kit
```

Enable **PerceptionKit**. If `godot-studio-workflow` is loaded: orchestrator → tree (this chat if 1–3 files; else `studio-tech-lead`) → OK → `studio-developer`. No extra subagent.

## 1. Scope

If missing, ask in one batch:

1. Who perceives (which actor scenes) and what (the player, bots, other enemies, lamps); 2D or 3D.
2. The sides: who sees whom (one physics layer per side).
3. Sight: how far, how wide, how close they notice behind them; what hides (the walls' layers); the eyes' height.
4. Hearing: which noises the game makes (shots, steps) and how far each carries; where they are emitted today.
5. Light and dark, cover, night: what changes how visible a target is, if anything.
6. What the actor does when it perceives and when it forgets (its states), and whether the game is networked (who perceives).

## 2. Plan

Show the file tree before touching the game (`[+]` new, `[~]` changed, `[-]` removed), for example:

```
[~] project.godot                        # PerceptionKit plugin; layer names for the sides (survivors, threats)
[~] scenes/enemies/guard.tscn            # Head > PerceptionSensor3D (mask: survivors; values dragged with its handles)
[~] scenes/player/player.tscn            # PerceptionTarget3D at the chest, on the survivors layer
[~] scenes/enemies/guard_states/*.gd     # the actor's states read the sensor: latest(), sees_any(), is_aware()
[~] scripts/noise.gd                     # the game's noise signal calls sensor.hear(position, radius, source)
```

Start from `addons/perception_kit/examples/minimal_3d` (a guard turning its head), `minimal_2d`, or `guards_3d` (watch, look, search, go home; noise, lamp, night, shade).

## 3. Implement

Follow [godot-perception-kit](../skills/godot-perception-kit/SKILL.md) and `addons/perception_kit/README.md`.

- Put the sensor on what turns to look; its body is found on its own (`body`). The target where it is seen from.
- Name a layer per side; targets on their side's layer, sensors' masks on the sides they see; `occlusion_mask` on the walls.
- Tell the person how to size the view: select the sensor, drag the sight, lose, angle, near and eye handles in the 3D (or 2D) view; Ctrl+Z undoes.
- The actor's states: `perceived` starts the alert, `forgotten` ends it, `latest()` says where to look or go.
- The game's noises call `hear()`; light and dark set `visibility`, `sight_scale` or `reach_by_kind`; a networked game sets `enabled` on its authority only.

## 4. Done when

- The sensors show no warning and the person has sized (or knows how to size) the views with the handles.
- F6 with `show_in_game`: the actor sees the target in its view, loses it past the lose radius or behind a wall, hears a noise, and forgets after `memory_s`.
- The actor's states react to it.
- No state, combat or network code inside `addons/perception_kit`.
