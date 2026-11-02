# API de PerceptionKit por pieza

Todo bajo `addons/perception_kit/`. Las distancias 3D son metros (`_m`), las 2D píxeles (`_px`), los ángulos grados (`_deg`).

| Clase | Qué |
|---|---|
| `PerceptionSensor3D` (@tool, Area3D) | Vista: `sight_radius_m`, `lose_radius_m`, `view_angle_deg`, `near_radius_m`, `eye_height_m`, `occlusion_mask`, `body`, `sight_scale`, `reach_by_kind: Dictionary[StringName, float]`. Oído: `hearing_scale`. Memoria: `memory_s`, `sense_hz`. `enabled`. Dibujo de depuración: `show_in_game`, `idle_color`, `aware_color`, `seeing_color`. Su máscara de colisión: los bandos que ve (capa 1 por defecto; los valores de colisión propios del kit no se muestran). Señales `perceived(stimulus)`, `forgotten(stimulus)`. `hear(at, radius_m, source = 0) -> bool`, `sense(kind, at, strength = 1, source = 0)`, `latest(kind = &"")`, `stimulus_of(target)`, `sees(target)`, `sees_any()`, `is_aware()`, `remembered(kind = &"")`, `forget_all()`, `eye_position()`, `reach_m()`, `sight_radius_for(target, seen)`; virtual `_sight_radius(target, seen, radius) -> float` |
| `PerceptionSensor2D` (@tool, Area2D) | Lo mismo en píxeles (`sight_radius_px`, `lose_radius_px`, `near_radius_px`; sin altura de ojos), mirando hacia +X: `hear(at: Vector2, radius_px, source)`, `sense(kind, at: Vector2, …)`, `reach_px()`; constante `EDITOR_COLOR` |
| `PerceptionTarget3D` (@tool, Area3D) | `enabled`, `visibility` (0–1), `kind` (StringName, `&"sight"`), `radius_m`, `body`. Su capa de colisión: su bando (capa 1 por defecto). static `body_above(node)` |
| `PerceptionTarget2D` (@tool, Area2D) | Lo mismo con `radius_px` |
| `PerceptionStimulus` | `kind`, `position` (`position_2d`), `strength`, `age_s`, `key`, `sensing`, `target` (null para un ruido o un objetivo liberado); `is_seen()`; constantes `SIGHT`, `HEARING`; static `seeing(of, kind, at, strength)` |
| `PerceptionMemory` | `remember(stimulus) -> bool` (true si es nuevo), `find(kind, key)`, `forget(kind, key)`, `age(delta_s, memory_s) -> Array[PerceptionStimulus]` (los olvidados), `latest(kind = &"")`, `all(kind = &"")`, `is_empty()`, `size()`, `clear()`, `stop_sensing()` |
| `PerceptionGeometry` | static `in_view_3d(eye, basis, point, half_angle)`, `in_view_2d(eye, rotation, point, half_angle)`, `strength_at(distance, radius)`, `view_lines_3d(sight, lose, angle_deg, near)`, `view_lines_2d(…)` |
| Editor (plugin) | 3D: el gizmo con manijas para vista, pérdida, ángulo, cercanía y altura de ojos (`editor/perception_gizmo_3d.gd`); 2D: las mismas manijas en la vista 2D (`plugin.gd`); su cuenta en `editor/perception_handles.gd`. Cada arrastre se deshace |
