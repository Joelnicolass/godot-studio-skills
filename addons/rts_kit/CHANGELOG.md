# Cambios de RtsKit

## 0.4.0

- **Táctil en las dos cámaras.** `RtsCamera3D` y `RtsCamera2D` leen los dedos (`touch_enabled`, prendido por defecto). Un dedo arrastra el mapa (FREE) o mira alrededor (FOLLOW en 3D). Dos dedos pellizcan para el zoom (`pinch_zoom`: en 1 el suelo queda debajo de ellos, la distancia sigue la separación) y giran para rotar (`twist_turn`, pasado `twist_start_deg`, así un pellizco no gira el mapa; en 2D con `can_turn`). En FREE el mapa se acerca y gira alrededor de los dedos. Un toque sigue siendo un clic: un dedo es arrastre recién pasado `touch_drag_px` (12 px; un dedo tiembla más que un mouse), y un toque con dos dedos nunca es un clic. Un gesto cuyo primer dedo cae sobre la UI es de la UI, con la regla de los bordes (`edge_area`, `edges_over_gui`). Un dedo que se levanta con un modal abierto, o con la ventana en segundo plano, no queda apretado.
- **El mouse que Godot emula desde un dedo** no mueve la vista una segunda vez, y ya no es el puntero de los bordes (un dedo levantado en un borde paneaba para siempre).
- **`takes_drag()`** en las dos cámaras, y `RtsPointer.camera_takes_drag()`: verdadero mientras un botón o un dedo apretado mueve la vista (un dedo, el botón de órbita, el gesto de mirar, arrastrar con elegir con `select_drag_pans`). `RtsSelectInput` no dibuja el rectángulo en ese caso, y suelta el que la cámara toma: un dedo que mueve el mapa ya no selecciona lo que barrió.
- **`select_drag_pans`** (FREE, apagado por defecto) en las dos cámaras: arrastrar con el botón de elegir mueve el mapa pasado `drag_px`, como en un mapa de estrategia. Dejalo apagado en un RTS, donde ese arrastre dibuja el rectángulo.
- **`focus(point, seconds)`** en las dos cámaras desliza la vista libre hasta ahí, con aceleración y frenado suaves; un paneo del jugador corta el deslizamiento. `focus(point)` sigue siendo instantáneo.
- **`RtsKeymap`** asigna sus teclas por defecto a todos los dispositivos (`RtsKeymap.ALL_DEVICES`, como guarda una acción Project Settings), así un toque (el mouse emulado, dispositivo -1) es un clic izquierdo.
- **Tests:** los dedos por la entrada de Godot (`Input.parse_input_event`, con el mouse emulado llegando antes), con la cámara, el puntero y la entrada de elegir juntos: un toque selecciona, un dedo que mueve el mapa no dibuja el rectángulo ni cambia la selección, un toque con dos dedos no es un clic, un dedo sobre un botón del HUD es del botón, y un arrastre lento con elegir que mueve el mapa no dibuja el rectángulo. Y cada cámara: toque, arrastre, pellizco y giro alrededor de los dedos, dedos levantados con un modal o al perder el foco la ventana, los gestos de la UI, el mouse emulado, `takes_drag`, el arrastre con elegir y el deslizamiento.

**Para actualizar:** en una pantalla táctil las cámaras ahora se mueven con los dedos. Antes un dedo llegaba al juego solo como el mouse emulado, y en un RTS un arrastre dibujaba el rectángulo. Apagá `touch_enabled` para mantener eso, o si tu juego lee los dedos por su cuenta. Las acciones que tu proyecto define en Project Settings conservan sus teclas; las que agrega `RtsKeymap` ahora también toman un toque.

## 0.3.1

- **Iconos propios en el editor:** cada nodo y recurso del kit tiene el suyo, del color del kit: se ven en el árbol de escena, en «Agregar nodo» y en el FileSystem.

Nada que actualizar en tu proyecto.

## 0.3.0

- **El equipo de mando es un nodo.** `rig/rts_command_rig_3d.tscn` y `rig/rts_command_rig_2d.tscn` (`RtsCommandRig`) traen `Command` con sus diez piezas y la `View` con su `Box`, todo conectado. Lo instanciás, asignás `camera` y `ground` (en 2D alcanza con `camera`) y ya elegís y ordenás. `menu` es un tercer socket, opcional, para el menú del botón derecho. Si falta un socket, o la cámara es de la otra dimensión, el nodo muestra un aviso en el editor.
- **Las piezas siguen a mano.** En el editor, clic derecho sobre el equipo > Editable Children: cada valor sigue en la pieza que lo usa. En código, `rig.selection`, `rig.orders`, `rig.command`, `rig.order_input`, `rig.select_input`, `rig.armed`, `rig.state`, `rig.pointer`, `rig.probe`, `rig.order_button`, `rig.group_keys`, `rig.view`, `rig.box`.
- **Los bordes de la cámara, sin conectar nada.** A un `RtsCamera3D` / `RtsCamera2D` sin `edge_area`, el equipo le pone su `View`.
- **El inspector muestra la unidad de cada distancia.** `RtsUnit.size`, `RtsOrders.spacing_base`, `max_spacing`, `retarget_range` y `RtsSelection.same_type_radius` muestran `px` cuando el nodo cuelga de un `Node2D` y `m` cuando cuelga de un `Node3D`; antes no mostraban nada y la documentación decía «metros» también en 2D. Ningún valor cambia. El equipo 2D trae las suyas en píxeles (8, 120, 1200, 600). `RtsSpace.distance_unit(node)` es la regla.
- **`RtsOrderButton.menu` se puede cambiar con el juego andando** (antes solo se conectaba en `_ready`).
- **Ejemplos:** `minimal_2d`, `skirmish_3d` y `skirmish_2d` usan el equipo; los `skirmish` tienen Editable Children prendido para conectar su HUD.
- **Tests:** `test_rig` (el equipo en 2D y 3D con eventos de mouse, los avisos, el socket del suelo, el menú, los bordes, un HUD encima con un puntero real), `test_space` (la unidad que muestra el inspector) y `test_independence` (el kit no nombra a ningún otro).

Para actualizar: nada se rompe; un equipo armado a mano sigue andando igual. Para pasarte a la escena: borrá tu `Command` y tu `Hud/View`, instanciá el equipo de tu dimensión, asigná `camera` y `ground`, y dejá tu HUD después del equipo en el árbol. Los valores que habías cambiado en una pieza se vuelven a poner con Editable Children; en tus scripts, `$Command/Selection` pasa a `rig.selection` (con `@export var rig: RtsCommandRig`), y el `edge_area` de tu cámara puede quedar vacío. Un script tuyo que extiende `RtsOrders` o `RtsSelection` sigue igual (ahora son `@tool` solo para mostrar la unidad).

## 0.2.0

- **Los bordes se frenan sobre la UI.** `RtsCamera3D` y `RtsCamera2D` ya no panean ni giran por los bordes con el puntero sobre un control de la UI: un botón o un panel del HUD, cualquier control cuyo filtro de mouse no sea *Ignore* (los labels y contenedores en *Ignore* no cuentan). Antes, sin `edge_area`, la cámara se movía mientras apuntabas a un botón de una esquina. `edges_over_gui = true` vuelve a lo de antes. Con `edge_area` nada cambia: los bordes siguen andando solo sobre ese control.
- **Tests:** `test_camera` prueba un botón en el borde, un label que ignora el mouse, `edges_over_gui` y `edge_area`, en 3D y en 2D.

Para actualizar: si tu cámara no tiene `edge_area` y un panel del HUD cubre un borde por el que querés panear, poné el filtro de mouse de ese panel en *Ignore* (sus botones siguen frenando los bordes) o prendé `edges_over_gui`.

## 0.1.1

- **Ejemplo mínimo** `examples/minimal_2d/`: seis soldados (`soldier.tscn`: un cuerpo, un `RtsUnit` y el script de unidad de la GUIDE en 2D) y el equipo de mando de la GUIDE › 3. Los tests lo juegan con eventos de mouse.
- **Tests:** el runner falla un test que corta con un error de script o que no hizo ningún chequeo; antes lo daba por bueno.

Nada que actualizar en tu proyecto.

## 0.1.0

Primera versión: la capa de mando de un RTS, para 2D y 3D, sin red y sin reglas de juego.

- **Unidades**: `RtsUnit` (dueño, equipo, tipo, tags, selectable / orderable / targetable, tamaño, centro, órdenes rechazadas, formación) con su cola de órdenes (`give`, `complete`, `fail`, `stop`; `order_started`, `order_ended`, `order_queued`).
- **Selección**: `RtsSelection` (clic, Shift, Ctrl / Cmd o doble clic por tipo y radio, rectángulo en 2D y 3D con oclusión opcional, límite con empuje, diez grupos y un grupo de unidades nuevas; las unidades que dejan de ser seleccionables salen solas).
- **Órdenes**: `RtsOrders` (`apply(order, from_slot)` revisa el slot, `request` / `send` para el jugador local, `apply_units` para una IA), órdenes tipadas (`RtsCommandType`, `RtsCommandCatalog`: move, attack, guard, guard_area, attack_move, retreat), formaciones (`RtsFormation`: línea, flancos, falange, semicírculo, círculo, cuña, escaramuza), reparto de lugares greedy y fila por fila, re-blanco al enemigo más cercano, retirada al ancla del bando, `RtsOrder.to_array` / `from_array` para cualquier transporte.
- **Entrada**: `RtsCommandInput`, `RtsSelectInput`, `RtsOrderButton`, `RtsOrderInput` (contexto -> orden, clics armados según el tipo de blanco, `run_entry`), `RtsArmedCommand`, `RtsGroupKeys`, `RtsPointer` (2D y 3D), `RtsWorldInput`, `RtsKeymap` (Cmd o Ctrl en macOS, configurable).
- **Interfaces de comandos, todas opcionales**: `RtsMenuEntry` (un modelo para todas), `RtsCommandCard` (un panel de botones), `RtsOrderMenu` (el contrato de un menú que se abre en un punto) y `RtsRadialMenu` (cualquier cantidad de anillos, llenados a mano o desde los catálogos).
- **Señales**: `RtsCueSet`, `RtsTargetProbe`, `RtsCursorSkin`, `rts_command_cue.tscn` con `RtsRefusalReason`, `RtsArmedPreview`, `RtsPing3D` / `RtsPing2D`.
- **Cámaras**: `RtsCamera3D` (seguir un cuerpo, o una vista cenital libre con paneo, giro, zoom y límites), `RtsCamera2D` (el mismo contrato), `RtsCameraEffect`.
- **Ejemplos**: `skirmish_3d` (menú radial) y `skirmish_2d` (sin menú, panel de comandos). **Tests**: `rtskit_lab`.
