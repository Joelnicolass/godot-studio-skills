# PlatKit

Motor de **plataformas 2D** como hijo de un `CharacterBody2D`: coyote, jump buffer, gravedad en el apex, corrección de esquina, memoria de lift. **Cero** niveles, puntaje, dash o stamina. Sin autoload, y no depende de ningún otro kit.

Ventanas de perdón al estilo Celeste ([Maddy Thorson](https://maddymakesgames.com/articles/celeste_and_forgiveness/index.html)): agrandar timing y posición a favor del jugador. El addon **no** es un clon de Celeste.

## Instalar

```bash
./install.sh --addon /path/to/godot-project plat_kit
```

Habilitá el plugin **PlatKit**. Proyecto ▸ Herramientas ▸ *PlatKit: Add motor to selected CharacterBody2D* agrega el motor al cuerpo elegido (se deshace con Ctrl+Z).

InputMap: `move_left`, `move_right`, `jump` (o cambiá las acciones en el grupo *InputMap* del motor).

## Ejemplo mínimo

`examples/minimal_2d/minimal_2d.tscn` (F6): un jugador sobre un piso y dos repisas. Flechas para correr, Espacio para saltar (un toque salta bajo, mantenerlo salta alto). Probá saltar justo después de dejar una repisa (coyote) o justo antes de caer (buffer).

No tiene código: es el árbol y el inspector.

```
Minimal2D
├── Floor, LedgeLow, LedgeHigh   # StaticBody2D
├── Walls                        # dos WorldBoundaryShape2D a los costados
└── Player (CharacterBody2D)
    ├── Shape, Look
    └── PlatMotor                # body = Player; acciones ui_left / ui_right / ui_accept; jump_speed = 420
```

El motor del ejemplo lee las acciones `ui_*` para correr en cualquier proyecto; un juego pone las suyas.

## Árbol

```
Player (CharacterBody2D)
├── CollisionShape2D
├── Visual
└── PlatMotor          # body = Player (o el parent)
```

Si usás una máquina de estados, va como **otro** hijo del actor (abajo, [Manejarlo desde otro script](#manejarlo-desde-otro-script)).

## Knobs (inspector)

| Grupo | Qué |
|-------|-----|
| Run | `max_speed`, `accel`, `friction` (px/s y px/s²) |
| Jump | `jump_speed`, `gravity`, `fall_gravity_mult` (cae más rápido de lo que sube), `cut_jump_mult` (soltar antes corta el salto), `coyote_time`, `jump_buffer` |
| Apex | `apex_gravity_mult` mientras se mantiene el salto cerca de vy = 0 (`apex_speed_threshold`) |
| Corner | `jump_corner_pixels` (techo); `side_corner_pixels` (0 = off; el dash **del juego** llama `try_side_corner_correct`) |
| Lift | `lift_remember`: la velocidad de la plataforma, unos segundos después de dejarla |
| Wall jump | off por defecto; `wall_extra_pixels`, `wall_jump_velocity` |

La altura de un salto mantenido es más o menos `jump_speed² / (2 · gravity)` píxeles: 320 y 980 (los valores por defecto) dan unos 52 px; el ejemplo sube `jump_speed` a 420, unos 90 px.

Dash, one-way pop, stamina refund: **glue del juego**, no este addon.

## Manejarlo desde otro script

Con `read_input` apagado el motor no lee el InputMap: un estado, una IA o la red le pasan la entrada.

```gdscript
# El script que maneja el motor: un estado del jugador, una IA, la red.
@export var motor: PlatMotor


func _physics_process(_delta: float) -> void:
	motor.axis = Input.get_axis(&"move_left", &"move_right")
	if Input.is_action_just_pressed(&"jump"):
		motor.request_jump()
	if Input.is_action_just_released(&"jump"):
		motor.release_jump()
```

| Llamada | Qué hace |
|---|---|
| `axis` | La carrera, -1 a 1 |
| `request_jump()` | Apretar salto: sale ya en el piso o en coyote, o al aterrizar dentro de `jump_buffer` |
| `release_jump()` | Soltar salto: corta un salto que sube y deja de flotar en el apex. Un toque que quedó en el buffer igual sale al aterrizar |
| `tick(delta)` | Un paso de física. Con `auto_process` prendido lo llama el motor; apagado, llamalo vos en tu orden (una simulación propia, un rollback) |
| `wall_dir()` | -1 / 1 si hay pared a la izquierda / derecha (o a `wall_extra_pixels`), 0 si no |
| `try_side_corner_correct(delta)` | Sube un borde de hasta `side_corner_pixels` al chocarlo de costado (el dash del juego) |

## Multijugador

PlatKit no tiene red. El motor corre donde se simula la física (el servidor, o el juego de un jugador) y los demás dibujan el cuerpo que sincronizás. Con `read_input` apagado, el servidor le pasa la entrada del dueño (en MpKit, lo que lee de su `MpInput`). Los temporizadores del motor (coyote, buffer, lift) no son parte de la pose: una reconciliación que rebobina el cuerpo no los rebobina.

## Tests

```bash
godot --headless --path <proyecto> --script res://addons/plat_kit/tests/plat_test_runner.gd
```

En el repo del kit, el proyecto es `platkit_lab/` (ahí `addons/plat_kit` es un symlink).

`PLATKIT TESTS PASS (n)`. Juegan el motor sobre física real (aterrizar, correr, el salto y su corte, el apex, el buffer, el coyote, la esquina, el wall jump, la plataforma que se mueve, `tick()` a mano) y el ejemplo mínimo con input. Un test que corta con un error de script, o que no llega a chequear nada, falla. La primera vez en un proyecto, importalo una vez (`godot --headless --path <proyecto> --import`) para que se conozca `PlatMotor`.

Cambios entre versiones, y qué actualizar en tu proyecto: [CHANGELOG.md](CHANGELOG.md).

## Tips y recomendaciones

- Empezá por los valores por defecto (coyote 0,08 s, buffer 0,12 s) y cambialos jugando, de a uno. Ventanas muy grandes se sienten como un salto que pasa solo.
- La altura del salto sale de `jump_speed` y `gravity`; la sensación, de `fall_gravity_mult` (caer más rápido) y `apex_gravity_mult` (flotar arriba). Tocá esos antes que la altura.
- Un solo `move_and_slide` por frame: lo llama el motor. El script del cuerpo no mueve el cuerpo.
- Plataformas que se mueven: un `AnimatableBody2D`. Al saltar, el cuerpo se lleva la velocidad de la plataforma una vez: Godot la suma al dejarla (`platform_on_leave`) y el motor solo agrega la recordada en coyote time, o si apagaste eso.
- Con una máquina de estados: `read_input` apagado y los estados le pasan `axis`, `request_jump()` y `release_jump()`. Sin `release_jump()` el salto queda siempre "mantenido".
- Dash, one-way, super wall jump, stamina: son de tu juego. El catálogo de cómo hacerlos está en la skill `godot-platformer-2d` (`forgiveness.md`).

## No hagas

- `is_on_floor()` + salto **sin** coyote ni buffer en un juego de precisión.
- Mover el cuerpo en su script y además en el motor.
- Meter PlatKit dentro de otro addon, o un fork por título.
