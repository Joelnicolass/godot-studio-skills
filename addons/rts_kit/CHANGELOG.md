# Cambios de RtsKit

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
