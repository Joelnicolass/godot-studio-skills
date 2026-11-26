---
name: godot-gesture-kit
description: >-
  Gestos táctiles que Godot 4 no trae, con el addon GestureKit: tocar con
  uno, dos o tres dedos, doble toque (y un toque confirmado que no fue
  doble), mantener apretado con un anillo que se llena, swipe en 4, 8 o
  cualquier dirección, arrastrar con cualquier cantidad de dedos y la
  velocidad al soltar para lanzar algo, pellizcar para hacer zoom y girar con
  dos dedos, en Android, iOS, la web y pantallas táctiles. Un
  GestureArea (Control) que avisa con señales y puede apretar acciones del
  Mapa de entrada sin código, un GestureReader de datos puros que se testea
  con tiempos exactos, y el mouse como un dedo (Alt + arrastrar son dos) para
  probar sin teléfono. Usar cuando el usuario quiere swipe, gestos,
  pinch to zoom, pellizcar, rotar con dos dedos, doble toque, mantener
  apretado, long press, tocar con dos dedos, lanzar con el dedo, controles
  táctiles por gestos o /add-gestures. No es un stick ni botones
  (Godot trae VirtualJoystick y TouchScreenButton), ni la cámara, ni lo que
  hace cada gesto en el juego.
---

# Godot — gestos táctiles (GestureKit)

Addon `addons/gesture_kit/` en el proyecto del **juego**. Referencia: `addons/gesture_kit/README.md`.

Si el addon no está:

```bash
./install.sh --addon /path/to/godot-project gesture_kit
```

Habilitá el plugin **GestureKit** (tipo `GestureArea` en Create Node). Pedido acotado: `/add-gestures`. Stick, botones y mirar arrastrando, con nodos de Godot: [touch.md](../godot-composition-first/touch.md). Composición: [godot-composition-first](../godot-composition-first/SKILL.md).

## Reglas

- **Solo lo que Godot no trae.** Para un stick o botones, `VirtualJoystick` y `TouchScreenButton`, sin el kit. GestureKit es para toques con varios dedos, doble toque, mantener apretado, swipe, arrastrar con la velocidad, pellizcar y girar.
- **Un área por zona.** Un `GestureArea` (Control) donde cuentan los gestos, en **Full Rect** para toda la pantalla. Un `Control` encima (HUD, stick) se queda con sus dedos. Un dedo que cayó en el área sigue siendo suyo hasta que se levanta.
- **Señales o acciones.** Las reglas conectan `tapped`, `swiped`, `dragged`, `pinched`, etc. Un gesto que equivale a apretar una tecla una vez va en el inspector (`swipe_up_action = jump`): la acción se aprieta y se suelta de una vez, así que la ven `is_action_just_pressed` y `_unhandled_input`, nunca `is_action_pressed` ni `get_axis`.
- **Datos que da cada señal.** `fingers` es la mayor cantidad de dedos a la vez en el gesto. Las posiciones están en píxeles del viewport. `pinched` y `twisted` dan lo que cambió desde la señal anterior: un zoom se multiplica por `ratio` y una rotación suma `radians`, alrededor de `center`.
- **Un swipe también es un arrastre.** Llega `drag_ended` y después `swiped`. Si los dos significan algo, decidí con `at` de `drag_started`.
- **Toque y doble toque distintos:** `tap_confirmed` en lugar de `tapped`.
- **Mantener para cargar, soltar para disparar:** `long_pressed` y `long_press_ended`. Una línea de apuntado: de `drag_started(at)` a `area.reader.center()`.
- **Umbrales en una pantalla sin *Stretch Mode*:** `units = DENSITY_PIXELS` los mide en dp; si no, 12 px de pantalla son poco en un teléfono.
- **Probar sin teléfono.** El mouse es un dedo; Alt + arrastrar pone dos en espejo alrededor del centro del área (pellizcar y girar), y Alt + Shift los mueve juntos. `show_fingers` dibuja los dedos, también en el teléfono.
- **`mouse_filter`:** `Stop` (el de Godot) deja los dedos solo para el área, y también la rueda del mouse; `Pass` también se los da a `_unhandled_input` (un mundo 3D que elige con clics, un zoom con la rueda).
- **Ningún kit depende de otro.** El área no mueve la cámara ni sabe del juego: el juego conecta sus señales a lo que corresponda. Una cámara que ya lee los dedos por su cuenta no lleva un área con `Stop` encima.

## Árbol

```
Level
├── World / Camera2D
└── Ui (CanvasLayer)
    ├── Gestures (GestureArea)        # Full Rect; umbrales y acciones en el inspector
    ├── Stick (VirtualJoystick)       # encima: se queda con sus dedos
    └── Pause (Button)                # encima: se queda con sus dedos
```

`level.gd` conecta `Gestures.dragged`, `.pinched` y `.twisted` a la cámara, y `.double_tapped` a centrarla. Arrancá desde `addons/gesture_kit/examples/minimal/minimal.tscn`.

## Qué va dónde

| Kit | Juego |
|---|---|
| Qué gesto hicieron los dedos, dónde y con cuántos | Qué hace cada gesto |
| Los umbrales en el inspector | Valores que se sientan bien en su juego |
| `dragged`, `pinched`, `twisted` alrededor de `center` | La cámara o el objeto que se mueve, sus límites |
| `drag_ended(velocity)` | El lanzamiento, el rozamiento |
| `hold_progress()` | El anillo o la barra que se dibuja |
| Apretar una acción | Qué hace la acción |

## Listo cuando

- El `GestureArea` no muestra avisos y cubre la zona donde cuentan los gestos.
- Con el mouse (clic, Alt + arrastrar) cada gesto hace lo que debe, y un botón del HUD sigue andando.
- En un teléfono (o con `show_fingers`), los dedos de verdad hacen lo mismo y nada llega dos veces.
- `godot --headless --path gesturekit_lab --script res://addons/gesture_kit/tests/gesture_test_runner.gd` da `GESTUREKIT TESTS PASS` (en el repo del kit).

## Antipatrones

- Leer `InputEventScreenTouch` y `InputEventScreenDrag` a mano para un swipe o un pellizco: eso es el kit.
- El `relative` de un `InputEventScreenDrag` con dos dedos: el kit mide desde la posición de cada dedo.
- Un `Timer` para separar un toque de un doble toque: `tap_confirmed`.
- Contar el mouse emulado como un segundo dedo: el área ya lo ignora.
- Un área con `Stop` encima de botones del HUD: los botones van encima del área.
- Un stick o botones táctiles escritos a mano: `VirtualJoystick` y `TouchScreenButton`.
- Una acción del inspector para moverse mientras dura algo (`get_axis`): se aprieta y se suelta de una vez; conectá la señal.
- Alimentar `area.reader` desde el juego: el área no se entera. Para otro origen de dedos, un `GestureReader.new()` propio.
- Mover la cámara o reglas del juego dentro del kit: el kit dice qué gesto fue, el juego decide.
