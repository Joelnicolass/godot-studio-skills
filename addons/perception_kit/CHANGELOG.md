# PerceptionKit changelog

## 0.1.1

- **The sides set in a scene stay when it loads** (found by El Eternauta). 0.1.0 put a new sensor's mask and a new target's layer on layer 32 in `_init()`. Godot sets a node's own properties before its script, so that `_init()` ran after the scene's values and overwrote them: a mask or layer set in the inspector was lost on the next load. Now `_init()` sets only what the kit owns (nothing detects a sensor, a target detects nothing), and the inspector shows a sensor's mask and a target's layer only; the rest is neither shown nor saved.
- **Out of the box, layer 1**, like any area (0.1.0: layer 32). A scene saved with 0.1.0 keeps layer 32 written in it, so it plays the same.
- **Tests:** 44 (`test_saved_scene`: a scene saved and loaded again in 2D and 3D, its sides, what is shown and saved).

What to update: nothing in a scene made in the editor. A sensor or target made in code (`PerceptionSensor3D.new()`) is now on layer 1: set its mask or layer if it must meet ones saved with 0.1.0 (layer 32). A workaround putting `script =` first in a scene can go.

## 0.1.0

The first version, asked for by El Eternauta (its enemies' perception, made generic).

- **Sensors and targets, 2D and 3D:** `PerceptionSensor3D` / `PerceptionSensor2D` and `PerceptionTarget3D` / `PerceptionTarget2D`.
  - Sight: a radius, a farther lose radius, an angle and all-around awareness up close; walls on `occlusion_mask` hide, and the actor's and the target's own bodies never do.
  - Sides are physics layers: a target's layer, a sensor's mask.
  - `hear(position, radius, source)` for noises, `sense(kind, position)` for any sense of the game's own.
  - A memory that forgets after `memory_s`; signals `perceived` and `forgotten`; `latest()`, `sees_any()`, `is_aware()`, `stimulus_of()`.
  - `visibility` on targets, `sight_scale` and `reach_by_kind` on sensors, and `_sight_radius()` to override for a rule of the game's own.
  - Looks `sense_hz` times a second, each sensor at its own moment; `enabled` turns one off (a networked game's clients).
- **`PerceptionStimulus`, `PerceptionMemory`, `PerceptionGeometry`:** what is perceived, what is remembered, and the pure checks.
- **The editor:** the view drawn in the 2D and 3D views with handles for the sight, lose and near radii, the angle and (3D) the eye height; every drag undoes; warnings for a lose radius under the sight radius and an empty mask. `show_in_game` draws the view in play.
- **Examples:** `minimal_3d`, `minimal_2d`, `guards_3d` (guards that watch, look, search and go home; a noise, a lamp, night, shade).
- **Tests:** 41, and an editor check (23 checks).
