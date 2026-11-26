# Cambios de GestureKit

## 0.1.0

Primera versión:

- `GestureReader`: los dedos leídos como gestos, en datos puros y con el tiempo que le pasan (`now`):
  - `tapped` con 1, 2 o 3 dedos;
  - `double_tapped` (ignora un rebote de menos de 40 ms) y `tap_confirmed` para un toque que no fue doble;
  - `long_pressed` y `long_press_ended`, con `hold_progress()`;
  - `swiped` en 4, 8 o cualquier dirección (el tiempo corre desde que los dedos empiezan a moverse; nunca después de un pellizco o un giro);
  - `drag_started`, `dragged` y `drag_ended(velocity)`, con `center()`;
  - `pinched` y `twisted` alrededor de los dedos.

  Detalles:
  - Un solo arrastre por gesto, aunque caigan o se levanten dedos. `fingers` es la mayor cantidad del gesto y `fingers_down()`, la de ahora.
  - La velocidad cuenta solo lo que vino después de una pausa y nunca divide por menos de un cuadro a 120 fps.
  - Los dos dedos que pellizcan se leen juntos (también a un cuadro de distancia), así que moverlos a la vez no es un pellizco.
  - Los umbrales quedan dentro de su rango.
  - `clear()` olvida todo sin dejar un dedo apretado.
- `GestureArea` (Control):
  - lee los dedos que caen sobre él, con posiciones en píxeles del viewport (también con `canvas_items` y en un `SubViewport`);
  - un `Control` encima se queda con sus dedos;
  - los umbrales están en el inspector, en píxeles del viewport o en dp (`units`);
  - cada gesto puede apretar y soltar una acción del Mapa de entrada (el swipe, por dirección);
  - el mouse es un dedo, y Alt + arrastrar son dos (pellizcar y girar alrededor del centro; con Shift, se mueven juntos);
  - un pellizco del trackpad llega como `pinched`;
  - `show_fingers` dibuja los dedos;
  - ignora el mouse que Godot emula desde un dedo;
  - olvida los dedos al ocultarse, salir del árbol, pausarse, deshabilitarse, perder el foco o con un toque cancelado.

  Avisos del editor: `mouse_filter` en `Ignore` y una acción que no existe.
- Ejemplo `examples/minimal` (2D): una tarjeta que se arrastra, se lanza, se pellizca, se gira, se marca y cambia de color.
- Tests propios y `gesturekit_lab/`, con avisos estrictos de GDScript y un chequeo en el editor real (`-- --gesturekit-editor-check`).
- Auditoría de Fable aplicada entera.
