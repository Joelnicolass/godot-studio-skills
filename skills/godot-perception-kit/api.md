# PerceptionKit API by piece

All under `addons/perception_kit/`. 3D distances are metres (`_m`), 2D ones pixels (`_px`), angles degrees (`_deg`).

| Class | What |
|---|---|
| `PerceptionSensor3D` (@tool, Area3D) | Sight: `sight_radius_m`, `lose_radius_m`, `view_angle_deg`, `near_radius_m`, `eye_height_m`, `occlusion_mask`, `body`, `sight_scale`, `reach_by_kind: Dictionary[StringName, float]`. Hearing: `hearing_scale`. Memory: `memory_s`, `sense_hz`. `enabled`. Debug draw: `show_in_game`, `idle_color`, `aware_color`, `seeing_color`. Its collision mask: the sides it sees (layer 32 by default). Signals `perceived(stimulus)`, `forgotten(stimulus)`. `hear(at, radius_m, source = 0) -> bool`, `sense(kind, at, strength = 1, source = 0)`, `latest(kind = &"")`, `stimulus_of(target)`, `sees(target)`, `sees_any()`, `is_aware()`, `remembered(kind = &"")`, `forget_all()`, `eye_position()`, `reach_m()`, `sight_radius_for(target, seen)`; virtual `_sight_radius(target, seen, radius) -> float` |
| `PerceptionSensor2D` (@tool, Area2D) | The same in pixels (`sight_radius_px`, `lose_radius_px`, `near_radius_px`; no eye height), looking along +X: `hear(at: Vector2, radius_px, source)`, `sense(kind, at: Vector2, …)`, `reach_px()`; constant `EDITOR_COLOR` |
| `PerceptionTarget3D` (@tool, Area3D) | `enabled`, `visibility` (0–1), `kind` (StringName, `&"sight"`), `radius_m`, `body`. Its collision layer: its side (layer 32 by default). static `body_above(node)` |
| `PerceptionTarget2D` (@tool, Area2D) | The same with `radius_px` |
| `PerceptionStimulus` | `kind`, `position` (`position_2d`), `strength`, `age_s`, `key`, `sensing`, `target` (null for a noise or a freed target); `is_seen()`; constants `SIGHT`, `HEARING`; static `seeing(of, kind, at, strength)` |
| `PerceptionMemory` | `remember(stimulus) -> bool` (true when new), `find(kind, key)`, `forget(kind, key)`, `age(delta_s, memory_s) -> Array[PerceptionStimulus]` (the forgotten), `latest(kind = &"")`, `all(kind = &"")`, `is_empty()`, `size()`, `clear()`, `stop_sensing()` |
| `PerceptionGeometry` | static `in_view_3d(eye, basis, point, half_angle)`, `in_view_2d(eye, rotation, point, half_angle)`, `strength_at(distance, radius)`, `view_lines_3d(sight, lose, angle_deg, near)`, `view_lines_2d(…)` |
| Editor (plugin) | 3D: the gizmo with handles for sight, lose, angle, near and eye height (`editor/perception_gizmo_3d.gd`); 2D: the same handles in the 2D view (`plugin.gd`); their math in `editor/perception_handles.gd`. Every drag undoes |
