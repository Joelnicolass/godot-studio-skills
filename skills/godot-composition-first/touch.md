# Controles táctiles

Para un celular o una tablet, Godot ya trae el stick y los botones: no hace falta escribirlos ni un addon. Los dos aprietan las mismas acciones del InputMap que el teclado, así que el juego solo lee acciones (§4 de la skill).

| Querés | Nodo de Godot | Cómo |
|---|---|---|
| Un stick que nace donde apoyás el dedo | `VirtualJoystick` (Control) | `joystick_mode = JOYSTICK_DYNAMIC`; el rect del nodo es la zona que lo agarra (anclalo a la mitad izquierda) |
| Un stick fijo, o que sigue al dedo | `VirtualJoystick` | `JOYSTICK_FIXED` / `JOYSTICK_FOLLOWING`; `initial_offset_ratio` para dónde arranca |
| Sus acciones | `VirtualJoystick` | `action_left`, `action_right`, `action_up`, `action_down`: las aprieta con fuerza analógica (`Input.get_vector` da un vector suave) |
| Zona muerta y tope | `VirtualJoystick` | `deadzone_ratio`, `clampzone_ratio`, `joystick_size`, `tip_size` |
| Que se vea solo mientras se toca | `VirtualJoystick` | `visibility_mode = VISIBILITY_WHEN_TOUCHED` |
| Su aspecto (pixel art) | `VirtualJoystick` | En el tema, los StyleBox `normal_joystick`, `normal_tip`, `pressed_joystick`, `pressed_tip` (un `StyleBoxTexture` con tu arte) |
| Un botón por acción | `TouchScreenButton` (Node2D) | `action`, `texture_normal`, `texture_pressed`, `shape` para el área que lo toca |
| Botones solo en pantallas táctiles | `TouchScreenButton` | `visibility_mode = VISIBILITY_TOUCHSCREEN_ONLY` |

Probado en Godot 4.7.2: el stick en modo dinámico, con 30 px de arrastre a la derecha, da 0,6 en su acción; en diagonal, 0,89 y 0,45; al soltar, las suelta.

```
TouchControls (CanvasLayer)
├── Stick (VirtualJoystick)            # anclado a la mitad izquierda; JOYSTICK_DYNAMIC; acciones move_*
├── Fire (TouchScreenButton)           # action fire; abajo a la derecha
├── Jump (TouchScreenButton)           # action jump
└── Look (Control, look_area.gd)       # solo en 3D: la mitad derecha, para mirar arrastrando
```

## Lo que Godot no trae

**Gestos.** Godot no trae swipe, doble toque con distancia, mantener apretado (salvo en Android, como clic derecho), tocar con dos o tres dedos, ni pellizcar y girar con dos dedos en iOS y la web. Para eso está el addon GestureKit (skill `godot-gesture-kit`, `/add-gestures`): un `GestureArea` que avisa cada gesto con una señal o aprieta una acción, con el HUD encima.

**Mostrarlo solo en teléfonos.** Los navegadores de escritorio suelen decir que tienen pantalla táctil, así que `DisplayServer.is_touchscreen_available()` (y `VISIBILITY_TOUCHSCREEN_ONLY`) muestran los controles en una laptop. Filtrá por plataforma, y mostralos también con el primer toque real:

```gdscript
func _ready() -> void:
	visible = OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("android") or OS.has_feature("ios")

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not visible:
		visible = true
```

Lo mismo para cualquier otra decisión que dependa de «es táctil» (cambiar de jugador solo, ayudas de puntería).

**Mirar arrastrando (3D).** Un `Control` en la mitad derecha que convierte el arrastre de un dedo en giro de cámara. Dos cuidados que salieron de un juego en el navegador de un celular:
- medí el movimiento de cada dedo desde donde lo viste por última vez, nunca con el `relative` del evento: con dos dedos, el navegador lo calcula mal y la cámara salta;
- un evento lejos de donde estaba su dedo no es ese dedo (el navegador puede cambiar los índices): dáselo al dedo más cercano, o a ninguno.

```gdscript
# look_area.gd: un dedo apoyado en esta área mueve la cámara (looked)
extends Control

signal looked(delta: Vector2)

@export var look_scale := 1.0
## Un evento a más de esto de donde estaba su dedo no es ese dedo.
@export var jump_px := 40.0

var _last: Dictionary[int, Vector2] = {}


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and get_global_rect().has_point(touch.position):
			_last[touch.index] = touch.position
		elif not touch.pressed:
			var finger := _finger_of(touch.index, touch.position)
			_last.erase(finger if finger != -1 else touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		var finger := _finger_of(drag.index, drag.position)
		if finger != -1:
			looked.emit((drag.position - _last[finger]) * look_scale)
			_last[finger] = drag.position


func _finger_of(index: int, at: Vector2) -> int:
	if _last.has(index) and at.distance_to(_last[index]) <= jump_px:
		return index
	var best := -1
	var best_px := jump_px
	for finger: int in _last:
		var px := at.distance_to(_last[finger])
		if px <= best_px:
			best = finger
			best_px = px
	return best
```

Probado con toques simulados: un `relative` falso no cuenta, un evento con el índice del otro dedo pero lejos se ignora, un índice cambiado cerca del dedo que mira sigue mirando, y después de soltar no mueve nada. Conectá `looked` a lo que gira la cámara (o, en red, al valor de mirada de tu entrada).

**Una acción de un toque que el juego lee como evento.** `Input.action_press()` no genera eventos: lo que se lee en `_unhandled_input` (cambiar de arma, pausa) no se entera. Mandá el par apretar y soltar como evento:

```gdscript
func tap(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
```

## Probarlo sin celular

Los toques se simulan con `get_viewport().push_input(evento)` (`InputEventScreenTouch`, `InputEventScreenDrag` con su `index`), y se lee `Input.get_action_strength()`. En el editor, **Project Settings › Input Devices › Pointing › Emulate Touch From Mouse** deja probar un dedo con el mouse. Dos dedos y el navegador, en el teléfono; un `GestureArea` de GestureKit también simula dos dedos con Alt + arrastrar.

## Antipatrones

- Escribir un stick propio: `VirtualJoystick` ya nace donde apoyás, tiene zona muerta y aprieta las acciones con fuerza.
- Que el juego lea los toques: los controles aprietan acciones y el juego lee acciones, venga el input del teclado, un mando o la pantalla.
- `DisplayServer.is_touchscreen_available()` como «es un celular»: en la web de escritorio miente.
- Un swipe, un pellizco o un doble toque leídos a mano con `InputEventScreenTouch`: GestureKit ya los lee.
- El `relative` de un `InputEventScreenDrag` para mirar, con dos dedos en el navegador.
