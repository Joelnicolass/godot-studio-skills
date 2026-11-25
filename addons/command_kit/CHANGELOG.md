# CommandKit changes

## 0.2.1

- **Its own icons in the editor:** every node and resource of the kit has one, in the kit's colour: they show in the scene tree, in "Add Node" and in the FileSystem.

Nothing to update in your project.

## 0.2.0

Redone so there is no class to write per command. **Breaks the 0.1 API** (table in "Migrating from 0.1" in the README).

- A move is a named function of your game: `do_<name>(seat, args…)`, and optionally `can_<name>` (`""` = it can, or the reason) and `undo_<name>`. `can_run(seat, command, args)` is the general check, before the own one. If `undo_<name>` has one more parameter, it gets what `do_<name>` returned.
- `CommandLog.new(game)`: `run(seat, name, args)`, `can_run`, `undo`, `history()` (a deep copy of `{name, seat, args}`), `replay(history)`, `is_replaying()`, `commands()`, `has_command()`, `keep_history`. Signals `done`, `rejected` and `undone` with `seat, name, args`.
- Only the `do_*` functions of the game's script run (`run(0, &"queue_free")` gives `unknown_command`). The arguments are checked against the signature (`bad_arguments`, no script errors): count, default values, types, `int` for `float`, `String` and `StringName` interchangeable, plain `Array` and `Dictionary` for typed parameters.
- An untyped `can_` that returns `false` or something that is not text rejects with `not_allowed`. If the game is freed, `run` reports it once.
- A move does not run another: `run`, `undo` or `replay` from a `can_`, `do_` or `undo_` give `busy`. `replay` stops with `unknown_command` or `bad_arguments` on a malformed entry.
- `GameCommands` (Node) replaces `CommandBus`: `game` (empty = the parent), `keep_history`, `found_commands` in the inspector, `use_log`, `use_own_log`, `owns_log` and `rebuilt`. Editor warnings for a game with no script, no `do_*`, a `do_` with no `seat`, a `can_` or `undo_` with no `do_` and signatures that do not match.
- `GameCommand` and `CommandBus` are gone.
- Example `examples/minimal` redone (`stones.gd` is the game, `minimal.gd` only the screen), the kit's own tests and the `godot-command-kit` skill with `/add-commands`.

## 0.1.0

First version:

- `GameCommand`: the base of a command. Type, `from_args`, `args`, `can_run` (`&""` = can), `run`, optional undo, `seat` and `to_dict` (`{type, seat, args}`).
- `CommandLog`: runs only valid commands, logs the accepted ones, undoes the last one, replays a log (stopping at the first that does not run, with `is_replaying()` so a listener does not send commands twice) and builds commands from their entries.
- `CommandBus`: command types from the inspector, a default `context`, `use_log` and `rebuilt`.
- Example `examples/minimal` (stones on a board with Undo and Replay), the kit's own tests and `commandkit_lab/`.
