# PerceptionKit changelog

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
