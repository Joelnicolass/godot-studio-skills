# Cambios de PlatKit

## 0.2.0

**Cambia**

- Saltar de una plataforma que se mueve suma su velocidad **una** vez. Antes se sumaba dos veces: Godot la agrega al dejar el piso (`platform_on_leave = ADD_VELOCITY`, el valor por defecto) y el motor la volvía a agregar. Ahora el motor agrega la velocidad recordada (`lift_remember`) solo en un salto en coyote time, o si el cuerpo tiene otro `platform_on_leave`. Si habías compensado bajando la velocidad de tus plataformas, volvé a probarlas.

**Nuevo**

- `release_jump()`: soltar el salto desde código (corta el salto y deja de flotar en el apex). Con `read_input` apagado, un estado o la red no tenían cómo soltarlo, y el salto quedaba siempre mantenido.
- Ejemplo mínimo `examples/minimal_2d/`: un jugador, un piso y dos repisas, sin código.
- Tests: `addons/plat_kit/tests/plat_test_runner.gd` juega el motor sobre física real y el ejemplo con input.
- `axis`, `request_jump()`, `tick()`, `wall_dir()` y `try_side_corner_correct()` tienen su documentación en el script.

## 0.1.0

`PlatMotor` hijo de un `CharacterBody2D`: coyote, jump buffer, gravedad en el apex, corrección de esquina, memoria de lift, wall jump opcional.
