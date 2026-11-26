# <img src="icons/gesture_kit.svg" width="32" height="32" alt=""> GestureKit

Gestos táctiles que Godot no trae: tocar con uno, dos o tres dedos, el doble toque y mantener apretado. También el swipe, arrastrar con cualquier cantidad de dedos (con la velocidad al soltar), pellizcar y girar con dos dedos. Funcionan igual en Android, iOS, la web y una pantalla táctil de escritorio. El mouse también es un dedo, así que se prueba sin teléfono. Hay dos niveles:

- **`GestureArea`** (Control): un área de la pantalla que lee los dedos que caen sobre ella y avisa cada gesto con una señal. Los umbrales están en el inspector, y cada gesto puede apretar una acción del Mapa de entrada sin escribir código.
- **`GestureReader`** (RefCounted): los dedos leídos como gestos, como datos puros. No lee el reloj: recibe el tiempo con cada dedo, así que se testea con tiempos exactos. El área tiene el suyo (`area.reader`) para consultarlo; para leer dedos que vienen de otro lado, creá un `GestureReader.new()` y alimentalo vos.

GestureKit **no tiene** stick ni botones: Godot ya trae `VirtualJoystick` y `TouchScreenButton`. Tampoco tiene reglas de juego, cámara, red ni autoload: dice qué gesto hicieron los dedos, y el juego decide qué hace con él.

## Qué trae Godot y qué agrega

| Gesto | Godot 4.7 | GestureKit |
|---|---|---|
| Toque | `InputEventScreenTouch` (bajar y subir un dedo) | `tapped`, solo si no se movió ni se quedó apretado, con 1, 2 o 3 dedos |
| Doble toque | `double_tap` en el toque | `double_tapped` con distancia y dedos, y `tap_confirmed` para un toque que no fue doble |
| Mantener apretado | Solo en Android, como clic derecho | `long_pressed` en todas las plataformas, cuánto lleva de 0 a 1 (`hold_progress()`) y `long_press_ended` al soltar |
| Swipe | No | `swiped` con dirección (4, 8 o exacta) y dedos, y una acción por dirección |
| Arrastrar | `InputEventScreenDrag` por dedo | `dragged` del medio de los dedos, después de un margen, dónde está (`center()`) y la velocidad al soltar |
| Pellizcar | Solo en el trackpad de Mac y en Android (con un ajuste) | `pinched` en todas las plataformas, alrededor de los dedos |
| Girar con dos dedos | No | `twisted`, después de un umbral para que un pellizco no gire |

## Instalar

```bash
./install.sh --addon /path/to/godot-project gesture_kit
```

Habilitá el plugin **GestureKit**: queda el tipo `GestureArea` en Create Node.

## En 3 pasos

1. Agregá un `GestureArea` y ponelo donde cuentan los gestos: **Layout → Full Rect** para toda la pantalla. Un `Control` dibujado encima, como un botón del HUD o un `VirtualJoystick`, se queda con sus dedos.
2. Elegí qué hace cada gesto. Sin código, poné una acción en el inspector (`swipe_up_action = jump`): el swipe la aprieta y la suelta de una vez, así que la ven `Input.is_action_just_pressed` y `_unhandled_input`. Con código, conectá las señales en la pestaña Node.
3. Usalas desde tu código:

```gdscript
@onready var gestures: GestureArea = %Gestures
@onready var camera: Camera2D = %Camera


func _ready() -> void:
	gestures.dragged.connect(_on_dragged)
	gestures.pinched.connect(_on_pinched)
	gestures.double_tapped.connect(_on_double_tapped)


func _on_dragged(relative: Vector2, _fingers: int) -> void:
	camera.position -= relative / camera.zoom


func _on_pinched(ratio: float, _center: Vector2) -> void:
	camera.zoom *= ratio


func _on_double_tapped(_at: Vector2, _fingers: int) -> void:
	camera.zoom = Vector2.ONE
```

## Probarlo sin teléfono

- **El mouse es un dedo** (`use_mouse`, encendido): un clic es un toque, arrastrar es arrastrar y mantener apretado es mantener.
- **Alt + arrastrar** pone dos dedos, uno en el mouse y otro en espejo alrededor del centro del área. Alejarte del centro pellizca y dar la vuelta gira, como el simulador de iOS con Option.
- **Alt + Shift + arrastrar** mueve los dos dedos juntos: un arrastre o un swipe con dos dedos.
- **Un pellizco en el trackpad** de una Mac llega como `pinched`.
- **`show_fingers`** dibuja un círculo en cada dedo, el anillo de mantener y el nombre del último gesto. Sirve también en el teléfono.

Los dedos de verdad siempre cuentan: el mouse que Godot emula desde un dedo se ignora, así que en un teléfono nada llega dos veces.

## Ejemplo mínimo

`examples/minimal/minimal.tscn` (F6, 2D): una tarjeta sobre un `GestureArea` del tamaño de la pantalla.
- Arrastrala y lanzala.
- Pellizcala y girala con dos dedos (con el mouse, Alt + arrastrar).
- Un doble toque la vuelve al medio.
- Mantenerla apretada la marca (la esquina amarilla), con un anillo que se llena mientras tanto.
- Un swipe que empieza fuera de ella le cambia el color.
- Un toque con dos dedos muestra u oculta la ayuda.

```
Minimal          # minimal.gd: conecta las señales del área
├── Background
├── %Card        # Node2D: Face, Number, Mark
├── %Area        # GestureArea: Full Rect, sus valores de entrada
├── %Ring        # Control: el anillo de mantener, con reader.hold_progress()
└── %Status, %Help
```

## Cómo lee los dedos

- **Un gesto** empieza cuando un dedo cae en el área vacía y termina cuando se levanta el último. En todas las señales, `fingers` es la mayor cantidad de dedos que hubo a la vez en ese gesto.
- **Toque:** todos los dedos se levantan sin moverse más de `slop_px`, antes de `long_press_s` desde que cayó el último. `at` es el medio de donde cayeron. Cada toque de un doble toque también llega a `tapped`.
- **Doble toque:** el segundo toque cae dentro de `double_tap_s` desde que se levantó el primero, a menos de `double_tap_px` y con la misma cantidad de dedos. Llega `tapped` y después `double_tapped`. Un segundo toque que cae antes de 40 ms es un rebote de la pantalla y se ignora, como en Android.
- **`tap_confirmed`:** un toque al que no le siguió otro en `double_tap_s`. Usala cuando un toque y un doble toque hacen cosas distintas (seleccionar y abrir): llega un poco después, pero nunca antes de un doble toque. Si el área olvida los dedos antes (se oculta, por ejemplo), ese toque no se confirma.
- **Mantener apretado:** los dedos se quedan quietos `long_press_s`. Si cae otro dedo, la espera empieza de nuevo (y el toque se mide desde él). `fingers` es la mayor cantidad del gesto, aunque uno ya se haya levantado. Después no llega un toque ni un swipe; si los dedos se mueven, arrastran desde donde se mantuvieron. Al levantarse el último llega `long_press_ended(at)`, también después de arrastrar o si el área olvida los dedos: «mantené para cargar, soltá para disparar». `reader.hold_progress()` va de 0 a 1 mientras tanto.
- **Arrastrar:** el medio de los dedos se movió más de `slop_px` desde donde cayeron. `drag_started(at)` dice dónde cayeron, y el primer `dragged` incluye ese margen: lo que sigue a los dedos queda debajo de ellos. Hay un solo arrastre por gesto. Un dedo que cae o se levanta no mueve nada. `reader.center()` dice dónde está el medio de los dedos: una línea de apuntado va de `drag_started(at)` hasta ahí. `drag_ended(velocity)` trae la velocidad de la última décima de segundo, cero si los dedos ya se habían quedado quietos. Después de una pausa de más de 40 ms cuenta solo lo que vino después, como en Android, y nunca divide por menos de un cuadro a 120 fps: un lanzamiento que entra entero en un cuadro no sale en millones de píxeles por segundo.
- **Swipe:** una línea rápida, de al menos `swipe_min_px`, que termina antes de `swipe_max_s` desde que los dedos empezaron a moverse: un pulgar que espera apoyado y después desliza también hace swipe. No hay swipe después de mantener apretado, pellizcar o girar. Un swipe también es un arrastre: llega `drag_ended` y después `swiped`. `direction` es un vector de largo 1 según `swipe_directions`: `FOUR` da `Vector2.LEFT`, `RIGHT`, `UP` o `DOWN` (se compara con `==`), `EIGHT` suma las diagonales y `ANY` da la dirección exacta.
- **Pellizcar y girar:** los dos dedos más bajos. `pinched(ratio, center)` empieza cuando la distancia entre ellos cambió más de `slop_px`, y `twisted(radians, center)` cuando giraron más de `twist_start_deg`. Las dos señales dan lo que cambió desde la anterior, así que un zoom se multiplica por `ratio`. El giro es positivo en el sentido del reloj, como `rotation` en 2D. Dos dedos a menos del doble de `slop_px` no giran (su ángulo es ruido), y una distancia de menos de 1 px cuenta como 1.
- **Los dos dedos se leen juntos.** Godot manda un evento por dedo. Si los dos se mueven juntos, la distancia entre ellos sube y baja en cada evento y parecería un pellizco. Por eso el par se lee cuando se movieron los dos. Si se movió uno solo, se lee en el segundo cuadro, por si el otro llega un cuadro después.
- **Todo junto:** pellizcar, girar y arrastrar pueden llegar en el mismo gesto, como en un mapa que se mueve, se acerca y gira con dos dedos.
- **Posiciones:** en píxeles del viewport, como un `InputEventScreenTouch` en `_input`, aunque el área esté corrida o escalada en su `CanvasLayer`. Con *Stretch Mode* `canvas_items`, son los de la resolución de diseño; dentro de un `SubViewport`, los suyos.
- **Umbrales en píxeles** (`slop_px`, `double_tap_px`, `swipe_min_px`): por defecto, del viewport. Sin *Stretch Mode*, son los píxeles de la pantalla y en un teléfono quedan chicos: 12 px son menos de 5 dp, y un toque con el pulgar pasa a ser un arrastre. `units = DENSITY_PIXELS` los lee en dp (160 por pulgada, como Android), con el DPI de la pantalla y la escala de la ventana: miden lo mismo en cualquier pantalla.
- **La UI:** un `Control` encima del área se queda con sus dedos. Un dedo que cayó en el área sigue siendo suyo hasta que se levanta, aunque salga del área o pase sobre un botón.
- **`mouse_filter`:** con `Stop` (el valor de Godot), los dedos son solo del área, y también la rueda y los otros botones del mouse. Con `Pass` también llegan a `_unhandled_input`: un mundo 3D que elige con clics o un juego que hace zoom con la rueda. Con `Ignore`, el área no recibe nada y lo avisa.
- **Ningún dedo queda apretado:** si el área se oculta, sale del árbol, se pausa, se deshabilita (`process_mode`), la ventana pierde el foco o el sistema cancela un toque, el área olvida los dedos. Un arrastre en curso termina con `velocity` cero y un long press con `long_press_ended`. Lo que esos dedos hagan después no cuenta. Un toque cancelado olvida todos los dedos: el sistema los cancela juntos (una llamada, un gesto del sistema).
- **Acciones:** se aprietan y se sueltan de una vez, como eventos (`Input.parse_input_event`). Las ven `_unhandled_input` e `Input.is_action_just_pressed`, una vez. No sirven para algo que se mantiene: `Input.is_action_pressed` y `Input.get_axis` nunca las ven apretadas. Un swipe aprieta la de la dirección más cercana de las cuatro; una diagonal de `EIGHT` aprieta las dos suyas.
- **El trackpad:** un pellizco (`InputEventMagnifyGesture`) llega como `pinched`, pero no mientras haya un dedo apoyado. Si activás *Enable Pan And Scale Gestures* de Android, Godot manda las dos cosas: dejalo apagado.
- **El reloj:** el área mide el tiempo con `Time` y procesa solo mientras espera algo (mantener, un toque por confirmar, el par de dedos). El reader recibe el tiempo con cada llamada (`now`, en segundos).

## API

### `GestureReader` (RefCounted)

| Señal | Cuándo |
|---|---|
| `tapped(at, fingers)` | Un toque. `at`: el medio de donde cayeron los dedos |
| `double_tapped(at, fingers)` | El segundo toque de un par, después de su `tapped` |
| `tap_confirmed(at, fingers)` | Un toque al que no le siguió otro en `double_tap_s` |
| `long_pressed(at, fingers)` | Los dedos se quedaron quietos `long_press_s` |
| `long_press_ended(at, fingers)` | Se levantaron los dedos de un long press (también después de arrastrar), o `clear()` |
| `swiped(direction, fingers)` | Una línea rápida, después de `drag_ended` |
| `drag_started(at, fingers)` | Los dedos pasaron `slop_px`. `at`: donde empezó el arrastre |
| `dragged(relative, fingers)` | El medio de los dedos se movió `relative` (dónde está: `center()`) |
| `drag_ended(velocity, fingers)` | Se levantó el último dedo (o `clear()`, con velocidad cero) |
| `pinched(ratio, center)` | Dos dedos se separaron (más de 1) o se juntaron (menos de 1) |
| `twisted(radians, center)` | Dos dedos giraron, en el sentido del reloj si es positivo |

| Miembro | Qué hace |
|---|---|
| `slop_px` (12), `long_press_s` (0,5), `double_tap_s` (0,3), `double_tap_px` (50) | Los umbrales de los toques. Un valor fuera de rango queda en el borde (`long_press_s` nunca menos de 0,01) |
| `swipe_min_px` (60), `swipe_max_s` (0,5), `swipe_directions` (`FOUR`) | Los del swipe. `Directions`: `FOUR`, `EIGHT`, `ANY` |
| `twist_start_deg` (10) | Los grados antes de girar |
| `press(index, at, now)`, `move(index, at, now)`, `lift(index, at, now)` | Un dedo cae, se mueve, se levanta. Un dedo que no conoce se ignora; uno que cae dos veces perdió su `lift` y el gesto empieza de nuevo |
| `update(now)` | Avanza el reloj: llegan mantener, `tap_confirmed` y el par de dedos pendiente. Llamalo cada cuadro mientras `is_waiting()` |
| `is_waiting() -> bool` | Algo puede llegar con el tiempo |
| `clear()` | Olvida los dedos y el toque que esperaba. Un arrastre en curso termina con velocidad cero y un long press con `long_press_ended` |
| `fingers_down() -> int`, `finger_positions() -> Dictionary[int, Vector2]` | Cuántos dedos hay apoyados ahora y dónde (una copia). El `fingers` de las señales es otra cosa: la mayor cantidad del gesto |
| `center() -> Vector2` | El medio de los dedos apoyados; después de levantarse, donde estaban |
| `is_dragging() -> bool` | Los dedos arrastran |
| `hold_progress() -> float` | De 0 a 1 mientras mantenés apretado, para dibujar un anillo. 0 sin dedos, si se movieron o si ya se mantuvo |
| `VELOCITY_WINDOW_S` (0,1), `STOPPED_GAP_S` (0,04), `MIN_SPAN_S` (1/120), `DOUBLE_TAP_MIN_S` (0,04) | Las constantes de la velocidad y del rebote |

### `GestureArea` (Control)

- **Señales:** las once del reader, con las mismas reglas y posiciones en píxeles del viewport.
- **Inspector:** `units` (los umbrales en píxeles del viewport o en dp) y los umbrales en los grupos **Taps**, **Swipe** y **Two fingers**. Cambiarlos cambia el reader al momento.
- **Actions:** `tap_action`, `double_tap_action`, `long_press_action`, `swipe_left_action`, `swipe_right_action`, `swipe_up_action` y `swipe_down_action`. Vacía: ninguna. Se aprietan y se sueltan de una vez.
- **Testing:** `use_mouse` (el mouse es un dedo; Alt, dos) y `show_fingers` (dibuja los dedos en el juego).
- **`reader`:** su `GestureReader`, de solo lectura, para `hold_progress()`, `center()`, `finger_positions()` o `is_dragging()`. Es para consultarlo: el área no se entera si le pasás dedos vos.
- **Avisos del editor:** `mouse_filter` en `Ignore`, y una acción que no existe en el Mapa de entrada.
- **En el editor** se dibuja con un borde y su nombre, así se ve dónde está. No lee dedos ni procesa nada.

## Querés → escribí

| Querés | Escribí |
|---|---|
| Gestos en toda la pantalla | Un `GestureArea` con **Layout → Full Rect** |
| Que un botón del HUD siga andando | Dibujalo encima del área (más abajo en el árbol) |
| Saltar con un swipe hacia arriba, sin código | `swipe_up_action = jump` |
| Saltar con un toque | `tap_action = jump`, o `tapped.connect(...)` |
| Un toque que no se confunda con un doble toque | `tap_confirmed` en lugar de `tapped` |
| Zoom con dos dedos (2D) | `pinched`: `camera.zoom *= ratio` |
| Zoom con dos dedos (3D, distancia) | `pinched`: `distance /= ratio` |
| Que el punto bajo los dedos quede quieto | `pinched(ratio, center)`: `position = center + (position - center) * ratio` |
| Girar algo con dos dedos | `twisted`: `rotation += radians` |
| Mover algo con un dedo | `dragged`: `position += relative` |
| Lanzar lo que arrastrabas | `drag_ended(velocity)`: seguí moviéndolo con esa velocidad |
| Arrastrar solo lo que estaba bajo el dedo | En `drag_started(at)` fijate si `at` cae sobre eso |
| Un menú al mantener apretado | `long_pressed(at)`: abrilo en `at` |
| Un anillo que se llena al mantener | `area.reader.hold_progress()` en `_process` o `_draw` |
| Mantener para cargar, soltar para disparar | `long_pressed` empieza a cargar; `long_press_ended` dispara |
| Una línea de apuntado mientras arrastrás | De `drag_started(at)` a `area.reader.center()` en `dragged` |
| Deshacer con dos dedos | `tapped`: `if fingers == 2: undo()` |
| Swipes en diagonal | `swipe_directions = EIGHT` |
| Un swipe más corto o más lento | `swipe_min_px`, `swipe_max_s` |
| Que un pellizco no gire | `twist_start_deg` más alto |
| Que el mundo 3D también reciba los toques | `mouse_filter = Pass` |
| Que la rueda del mouse siga llegando al juego | `mouse_filter = Pass` |
| Umbrales del mismo tamaño en cualquier pantalla (sin *Stretch Mode*) | `units = DENSITY_PIXELS` |
| Moverse mientras dura un swipe (`get_axis`) | Las acciones no sirven: conectá `swiped` y movete en tu código |
| Ver los dedos en el teléfono | `show_fingers = true` |
| Probar dos dedos con el mouse | Alt + arrastrar; Alt + Shift + arrastrar para moverlos juntos |
| Leer gestos sin un nodo (tests, otro input) | `GestureReader.new()`, y `press`, `move`, `lift` y `update` con tu tiempo |

## Tips

- **Un swipe también es un arrastre.** Si los dos significan algo, decidí con `at` de `drag_started`, como el ejemplo: arrastrar la tarjeta la mueve y un swipe fuera de ella cambia el color.
- **El área no es dueña de la cámara.** Para un mapa, conectá `dragged`, `pinched` y `twisted` a tu cámara. Si tu cámara ya lee los dedos por su cuenta, no le pongas encima un área con `Stop`, porque le quitaría los dedos.
- **Varias áreas.** Cada una lee solo los dedos que caen sobre ella: una mitad de la pantalla para mirar y otra para swipes, o una por carta.
- **Stick y botones, de Godot.** `VirtualJoystick` y `TouchScreenButton` arriba del área se quedan con sus dedos y el área recibe el resto.
- **Píxeles del viewport o dp.** Con *Stretch Mode* `canvas_items`, los umbrales siguen la resolución de diseño: en un teléfono se parecen a los de Android, pero en una tablet miden más milímetros. Sin *Stretch Mode*, o para que midan lo mismo en todas las pantallas, usá `units = DENSITY_PIXELS`.
- **En la web,** *Emulate Mouse From Touch* puede quedar encendido: el área ignora el mouse que Godot emula y lee el dedo.

## Tests

```bash
godot --headless --path gesturekit_lab --script res://addons/gesture_kit/tests/gesture_test_runner.gd
```

Sale `GESTUREKIT TESTS PASS (n)`. Cubren:

- **El reader, con tiempos exactos:**
  - toques con 1, 2 y 3 dedos (también un segundo dedo tarde), y el margen;
  - el doble toque (a tiempo, tarde, lejos, con otros dedos, con el segundo todavía apoyado y un rebote) y `tap_confirmed`;
  - mantener apretado (con otro dedo que cae, sin `update`, arrastrar después, `long_press_ended` y `fingers`);
  - el swipe en 4, 8 y cualquier dirección, demasiado lento o corto, con dos dedos, después de esperar apoyado, y que un pellizco no sea swipe;
  - el arrastre con dedos que caen y se levantan, `center()` y la velocidad (pareja, después de una pausa y en un mismo cuadro);
  - pellizcar y girar, el tercer dedo, los dos dedos leídos juntos (también a un cuadro de distancia) y dedos muy juntos;
  - `clear`, un dedo que cae dos veces, un índice que vuelve y los umbrales fuera de rango.
- **El área, por la entrada de Godot:**
  - un toque es uno solo con el mouse emulado, y sus acciones (una diagonal aprieta las dos; `is_action_just_pressed` la ve una vez);
  - las posiciones con un `CanvasLayer` corrido y escalado, con `canvas_items` y dentro de un `SubViewport`;
  - un botón encima, y `Pass` que deja llegar los dedos al mundo;
  - dos dedos de verdad;
  - el mouse como uno o dos dedos (también con el área corrida), con *Emulate Touch From Mouse* y con `use_mouse` apagado;
  - el reloj, y que ningún dedo quede apretado (ocultarse, salir del árbol, pausar, deshabilitar, perder el foco, un toque cancelado con dos dedos);
  - `show_fingers`, `long_press_ended`, los umbrales en dp, el trackpad, el inspector y sus avisos.
- **El ejemplo,** jugado con dedos al ritmo de una pantalla.
- **La independencia:** el addon no nombra a ningún otro kit.

En el editor real, el lab tiene un chequeo que abre el ejemplo y edita el área desde el inspector: un umbral que llega al reader y se deshace con el atajo, una acción que no existe (aviso) y una que sí, y `mouse_filter` en `Ignore`. Después guarda una copia:

```bash
godot --headless --editor --path gesturekit_lab -- --gesturekit-editor-check
```

Sale `GESTUREKIT EDITOR CHECK PASS (n)`.
