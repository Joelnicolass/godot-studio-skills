---
description: "Agrega controles de RTS (addon RtsKit): unidades, selección y grupos, órdenes en formación, entrada de comandos, cámara de RTS."
---

Agregá **controles de RTS** al **proyecto Godot del juego** con el addon RtsKit: `RtsUnit` en las unidades, el equipo de mando (un nodo: selección, órdenes, entrada), una cámara, y una interfaz de comandos si el juego la quiere.

Esto **no** es pathfinding, combate ni IA: el kit le da a cada unidad su orden y el juego la cumple. **No** es multijugador: si el juego es en red, el transporte de las órdenes es pegamento del juego (`addons/rts_kit/GUIDE.md` › 6, el canal propio de MpKit). **No** inventa unidades, costos ni reglas.

Cargar: `godot-rts-kit`, `godot-composition-first`.

Si no está `addons/rts_kit/`:

```bash
# Copia el addon al proyecto del juego.
./install.sh --addon /ABS/GODOT_ROOT rts_kit
```

Habilitá **RtsKit**. Si está cargado `godot-studio-workflow`: orquestador → árbol (este chat si son 1–3 archivos; si no, `studio-tech-lead`) → OK → `studio-developer`. Sin subagente extra.

## 1. Alcance

Si falta, preguntá en una sola tanda:

1. 2D o 3D, y qué escena es el campo de batalla.
2. Qué unidades hay (su escena) y de quién son (slots, equipos).
3. Cómo da órdenes el jugador con el mouse además del clic derecho: un panel de comandos, un menú radial, los dos, o ninguno (solo teclas).
4. Cámara: cenital libre, siguiendo a un héroe, o las dos.
5. ¿Es en red? Entonces, quién es el servidor y dónde vive el pegamento del transporte (nunca en el addon).

## 2. Plan

Mostrá el árbol de archivos antes de tocar el juego (`[+]` nuevo, `[~]` cambia, `[-]` se borra), por ejemplo:

```
[~] levels/battle/battle.tscn          # + Rig (rts_command_rig_3d.tscn: camera, ground), Camera, Hud (+ CommandCard / RadialMenu)
[~] units/unit.tscn                   # + hijo RtsUnit
[+] units/unit_orders.gd              # del juego: camina a order.spot(), pelea, complete()
[~] project.godot                      # plugin RtsKit; acciones de entrada (Herramientas > RtsKit: Add default input actions)
```

Seguí `addons/rts_kit/GUIDE.md` (secciones 2–6). El equipo es un nodo: instanciá `addons/rts_kit/rig/rts_command_rig_3d.tscn` (2D: `rts_command_rig_2d.tscn`) en la escena de batalla, asigná `camera` y `ground` (en 2D alcanza con `camera`) y dejá el HUD del juego después en el árbol; no armes `Command` ni `View` a mano. Para cambiar una pieza o conectarle el HUD: Editable Children; desde un script: `@export var rig: RtsCommandRig` y `rig.selection`, `rig.orders`… Los ejemplos (`minimal_2d`, `skirmish_3d`, `skirmish_2d`) lo muestran; no copies su caminante (el `soldier.gd` del mínimo es la forma de un script de unidad). En 2D las distancias son píxeles: el equipo 2D ya las trae y el inspector muestra `px`; poné `RtsUnit.size` en píxeles.

## 3. Implementar

Seguí [godot-rts-kit](../skills/godot-rts-kit/SKILL.md). La lógica de la unidad escucha `order_started` y avisa `complete()` / `fail()`; las unidades muertas apagan `selectable` / `orderable` / `targetable`. Una regla de unidad (pacifista) = `extends RtsUnit`. Una orden nueva = un `RtsCommandType` en el catálogo del juego.

## 4. Listo cuando

- F6: un rectángulo elige solo unidades propias; un clic derecho en el suelo las lleva en formación; sobre un enemigo lo atacan; Ctrl/Cmd+1 y después 1 recupera el grupo; Alt+N guarda una formación.
- El equipo no muestra avisos en el editor (el triángulo amarillo: falta `camera` o `ground`).
- Si sacás los nodos de la interfaz de comandos (panel, menú radial), el clic derecho sigue andando.
- Nada de movimiento ni daño dentro de `addons/rts_kit`; tampoco RPC.
