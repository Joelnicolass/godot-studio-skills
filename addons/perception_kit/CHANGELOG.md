# Changelog de PerceptionKit

## 0.1.0

La primera versión, pedida por El Eternauta (la percepción de sus enemigos, hecha genérica).

- **Sensores y objetivos, 2D y 3D:** `PerceptionSensor3D` / `PerceptionSensor2D` y `PerceptionTarget3D` / `PerceptionTarget2D`.
  - Vista: un radio, un radio de pérdida más lejano, un ángulo y conciencia de lo cercano en todas las direcciones; los muros de `occlusion_mask` tapan, y el cuerpo del actor y el del objetivo nunca.
  - Los bandos son capas de física: la capa del objetivo, la máscara del sensor.
  - `hear(position, radius, source)` para los ruidos, `sense(kind, position)` para cualquier sentido propio del juego.
  - Una memoria que olvida pasado `memory_s`; señales `perceived` y `forgotten`; `latest()`, `sees_any()`, `is_aware()`, `stimulus_of()`.
  - `visibility` en los objetivos, `sight_scale` y `reach_by_kind` en los sensores, y `_sight_radius()` para sobrescribir con una regla propia del juego.
  - Mira `sense_hz` veces por segundo, cada sensor en su propio momento; `enabled` apaga uno (los clientes de un juego en red).
- **`PerceptionStimulus`, `PerceptionMemory`, `PerceptionGeometry`:** lo que se percibe, lo que se recuerda y los chequeos puros.
- **El editor:** la vista dibujada en las vistas 2D y 3D con manijas para los radios de vista, pérdida y cercanía, el ángulo y (3D) la altura de ojos; cada arrastre se deshace; avisos por un radio de pérdida debajo del de vista y por una máscara vacía. `show_in_game` dibuja la vista en juego.
- **Ejemplos:** `minimal_3d`, `minimal_2d`, `guards_3d` (guardias que vigilan, miran, buscan y vuelven; un ruido, una linterna, la noche, la sombra).
- **Tests:** 41, y un chequeo del editor (23 chequeos).
