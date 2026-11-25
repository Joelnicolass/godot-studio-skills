# Cambios de CommandKit

## 0.2.0

Se rehace para que no haya que escribir una clase por orden. **Rompe la API de 0.1** (tabla en «Migrar desde 0.1» del README).

- Una jugada es una función de tu juego con nombre: `do_<nombre>(seat, args…)`, y opcionalmente `can_<nombre>` (`""` = se puede, o el motivo) y `undo_<nombre>`. `can_run(seat, command, args)` es el chequeo general, antes del propio. Si `undo_<nombre>` tiene un parámetro más, recibe lo que devolvió `do_<nombre>`.
- `CommandLog.new(game)`: `run(seat, name, args)`, `can_run`, `undo`, `history()` (copia profunda de `{name, seat, args}`), `replay(history)`, `is_replaying()`, `commands()`, `has_command()`, `keep_history`. Señales `done`, `rejected` y `undone` con `seat, name, args`.
- Solo corren las funciones `do_*` del script del juego (`run(0, &"queue_free")` da `unknown_command`). Los argumentos se validan contra la firma (`bad_arguments`, sin errores de script): cantidad, valores por defecto, tipos, `int` en `float`, `String` y `StringName` intercambiables, `Array` y `Dictionary` planos en parámetros tipados.
- Un `can_` sin tipar que devuelve `false` o algo que no es texto rechaza con `not_allowed`. Si el juego se libera, `run` avisa una vez.
- Una jugada no corre otra: `run`, `undo` o `replay` desde un `can_`, `do_` o `undo_` dan `busy`. `replay` corta con `unknown_command` o `bad_arguments` en una entrada mal formada.
- `GameCommands` (Node) reemplaza a `CommandBus`: `game` (vacío = el padre), `keep_history`, `found_commands` en el inspector, `use_log`, `use_own_log`, `owns_log` y `rebuilt`. Avisos del editor para un juego sin script, sin `do_*`, un `do_` sin `seat`, un `can_` o `undo_` sin su `do_` y firmas que no coinciden.
- Se borran `GameCommand` y `CommandBus`.
- Ejemplo `examples/minimal` rehecho (`stones.gd` es el juego, `minimal.gd` solo la pantalla), tests propios y skill `godot-command-kit` con `/add-commands`.

## 0.1.0

Primera versión:

- `GameCommand`: la base de una orden. Tipo, `from_args`, `args`, `can_run` (`&""` = puede), `run`, deshacer opcional, `seat` y `to_dict` (`{type, seat, args}`).
- `CommandLog`: corre solo las órdenes válidas, registra las aceptadas, deshace la última, repite un registro (cortando en la primera que no corre, con `is_replaying()` para que un listener no mande órdenes dos veces) y arma órdenes desde sus entradas.
- `CommandBus`: los tipos de orden desde el inspector, un `context` por defecto, `use_log` y `rebuilt`.
- Ejemplo `examples/minimal` (fichas en un tablero con Undo y Replay), tests propios y `commandkit_lab/`.
