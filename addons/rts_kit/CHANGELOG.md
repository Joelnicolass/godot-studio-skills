# Cambios de RtsKit

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
