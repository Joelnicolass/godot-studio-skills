---
description: "Jugadas validadas (addon CommandKit): do_<nombre> en tu juego con can_ (el motivo) y undo_ (deshacer), un nodo GameCommands y un historial que se guarda, se manda y se repite."
---

Agregá **jugadas validadas con historial** en el **proyecto Godot del juego** con el addon CommandKit:
- una función `do_<nombre>(seat, args…)` por cosa que el jugador puede hacer, en el nodo del juego;
- un `can_<nombre>` donde la jugada puede no valer (devuelve el motivo) y un `undo_<nombre>` donde se puede deshacer;
- un `GameCommands` hijo del juego, y la pantalla corriendo `commands.run(seat, &"place", [cell])`;
- si hace falta: un `can_run` general (turno), Undo, repetir un historial, guardarlo o mandar las jugadas por la red.

Después la persona ve en el inspector las jugadas que encontró (`found_commands`) y las prueba con F6; el agente arma y explica.

Esto **no** son las reglas del juego ni su estado: son tuyos, el kit corre las jugadas y las anota. **No** es el azar (la semilla vive en tu estado) ni la red: un juego en red manda el nombre y los argumentos y pone el asiento en el servidor.

Cargar: `godot-command-kit`, `godot-composition-first`.

Si falta `addons/command_kit/`:

```bash
./install.sh --addon /ABS/GODOT_ROOT command_kit
```

Habilitá **CommandKit**. Si `godot-studio-workflow` está cargado: orquestador → árbol (este chat si son 1–3 archivos; si no, `studio-tech-lead`) → OK → `studio-developer`. Sin subagente extra.

## 1. Alcance

Si falta, preguntá en una sola tanda:

1. Qué puede hacer un jugador (cada cosa es una jugada) y qué argumentos lleva (una casilla, una unidad y un destino).
2. Cuándo una jugada no vale y cómo se dice (el motivo corto: `"not_your_turn"`, `"occupied"`), y si hay un chequeo común a todas (el turno, que la partida no haya terminado).
3. Cuáles se pueden deshacer (una tirada de dados o una carta revelada, no) y si el deshacer necesita un dato (qué pieza se capturó).
4. Dónde vive el estado hoy y si las reglas son un nodo o un `RefCounted` sin escena.
5. Si hay que guardar el historial, repetir una partida (¿con azar? la semilla) o mostrar un Replay.
6. Si el juego es en red (con MpKit o con qué) y quién manda las jugadas (un cliente, un bot).

## 2. Plan

Mostrá el árbol de archivos antes de tocar el juego (`[+]` nuevo, `[~]` cambiado, `[-]` borrado), por ejemplo:

```
[~] project.godot                        # plugin CommandKit
[~] game/stones.gd                       # estado tipado + can_place / do_place / undo_place, y can_run (turno)
[~] game/game.tscn                       # + Commands (GameCommands): game vacío = el padre
[~] game/hud.gd                          # clic → commands.run(...); rejected → el motivo; Undo → commands.undo()
[+] game/replay.gd                       # guarda history(), clear(), reinicia el estado y repite con la misma semilla
```

Arrancá desde `addons/command_kit/examples/minimal` (fichas en un tablero con rechazo, Undo y Replay).

## 3. Implementar

Seguí [godot-command-kit](../skills/godot-command-kit/SKILL.md) y `addons/command_kit/README.md`.

- Las funciones en el nodo del juego (o en un `RefCounted` de reglas con `CommandLog.new(self)` y `use_log` en la escena). `seat` primero; el estado tipado, sin diccionarios sueltos.
- `can_<nombre>` devuelve `""` o el motivo y no cambia nada; el chequeo común va en `can_run(seat, command, args)`.
- `undo_<nombre>` con los mismos parámetros, o uno más si necesita lo que devolvió `do_<nombre>`.
- La pantalla corre las jugadas con `commands.run(...)` y escucha `rejected` para decir por qué no; `done` y `undone` para refrescar.
- Repetir: `history()`, `clear()`, el estado de vuelta al inicio (la misma semilla) y `replay(history)`; los listeners que responden chequean `is_replaying()` en el handler.
- Guardar el historial con `var_to_str` o `var_to_bytes`. En red, `mp_sv_command(command, args)` corre `commands.run(net.sender_slot(), command, args)`.
- Decile a la persona dónde ver las jugadas que encontró: `found_commands` en el inspector del nodo.

## 4. Listo cuando

- El nodo no muestra avisos y `found_commands` lista las jugadas.
- F6: una jugada válida corre, una inválida se rechaza con su motivo y no deja rastro, Undo saca la última y repetir el historial da el mismo estado.
- En red, el servidor pone el asiento y una jugada inventada se rechaza sin errores.
- Nada de las reglas, el azar ni la red dentro de `addons/command_kit`.
