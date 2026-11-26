---
description: "Gestos táctiles (addon GestureKit): tocar con varios dedos, doble toque, mantener apretado, swipe, arrastrar y lanzar, pellizcar y girar, con un GestureArea que avisa con señales o aprieta acciones, y el mouse como un dedo (Alt + arrastrar son dos) para probar sin teléfono."
---

Agregá **gestos táctiles** al **proyecto Godot del juego** con el addon GestureKit:
- un `GestureArea` donde cuentan los gestos (Full Rect para toda la pantalla), con los controles del HUD encima;
- cada gesto conectado a lo que hace: una señal (`swiped`, `pinched`, `dragged`, `double_tapped`, …) o una acción del Mapa de entrada desde el inspector (`swipe_up_action`, `tap_action`, …);
- los umbrales que hagan falta en el inspector (`slop_px`, `long_press_s`, `swipe_min_px`, `twist_start_deg`, …).

Después la persona prueba con el mouse (un clic es un dedo, Alt + arrastrar son dos) y en el teléfono; el agente arma y explica.

Esto **no** es un stick ni botones táctiles: para eso están `VirtualJoystick` y `TouchScreenButton` de Godot (ver `godot-composition-first/touch.md`). **No** es la cámara: el juego conecta los gestos a su cámara. **No** decide qué hace cada gesto.

Cargar: `godot-gesture-kit`, `godot-composition-first`.

Si falta `addons/gesture_kit/`:

```bash
./install.sh --addon /ABS/GODOT_ROOT gesture_kit
```

Habilitá **GestureKit**. Si `godot-studio-workflow` está cargado: orquestador → árbol (este chat si son 1–3 archivos; si no, `studio-tech-lead`) → OK → `studio-developer`. Sin subagente extra.

## 1. Alcance

Si falta, preguntá en una sola tanda:

1. Qué gestos usa el juego y qué hace cada uno (un swipe salta, pellizcar acerca la cámara, mantener abre un menú, dos dedos deshacen).
2. Dónde cuentan: toda la pantalla, una mitad, o sobre algo (una carta, el mapa); qué controles del HUD hay encima.
3. Si un toque y un doble toque hacen cosas distintas, y si un swipe y un arrastre conviven (cómo se distinguen).
4. Si el juego ya tiene acciones en el Mapa de entrada que un gesto puede apretar (`jump`, `ui_left`).
5. Si el mundo también tiene que recibir los toques o la rueda del mouse (clics en un mundo 3D, zoom con la rueda): `mouse_filter = Pass`.
6. Si el proyecto usa *Stretch Mode* (`canvas_items`) o no: sin él, los umbrales van en dp (`units = DENSITY_PIXELS`).

## 2. Plan

Mostrá el árbol de archivos antes de tocar el juego (`[+]` nuevo, `[~]` cambiado, `[-]` borrado), por ejemplo:

```
[~] project.godot                        # plugin GestureKit
[~] levels/level/level.tscn       # Ui/Gestures (GestureArea, Full Rect, swipe_up_action = jump), HUD encima
[~] levels/level/level.gd         # pinched → zoom de la cámara; dragged → la mueve; double_tapped → la centra
```

Arrancá desde `addons/gesture_kit/examples/minimal/minimal.tscn` (arrastrar, lanzar, pellizcar, girar, mantener, swipe, dos dedos).

## 3. Implementar

Seguí [godot-gesture-kit](../skills/godot-gesture-kit/SKILL.md) y `addons/gesture_kit/README.md`.

- Un `GestureArea` por zona; los controles del HUD más abajo en el árbol (encima del área).
- Un gesto que es apretar una tecla una vez: la acción en el inspector (la ven `is_action_just_pressed` y `_unhandled_input`, no `get_axis`). Uno que mueve algo: la señal, con `relative`, `ratio`, `radians` y `center`.
- Mantener para cargar y soltar para disparar: `long_pressed` y `long_press_ended`.
- Sin *Stretch Mode* en el proyecto: `units = DENSITY_PIXELS`, para que los umbrales midan lo mismo en un teléfono.
- Swipe y arrastre juntos: decidí en `drag_started(at)` si el gesto empezó sobre lo que se arrastra.
- Un toque que no tiene que dispararse en un doble toque: `tap_confirmed`.
- Lanzar: `drag_ended(velocity)`.
- Decile a la persona cómo probarlo: un clic es un dedo, Alt + arrastrar son dos (pellizcar y girar), Alt + Shift + arrastrar los mueve juntos; `show_fingers` en el teléfono.

## 4. Listo cuando

- El `GestureArea` no muestra avisos y los botones del HUD siguen andando.
- Cada gesto hace lo que debe con el mouse y con los dedos, y nada llega dos veces.
- Nada de cámara, reglas ni red dentro de `addons/gesture_kit`.
