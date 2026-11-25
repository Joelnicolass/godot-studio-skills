# CommandKit changes

## 0.1.0

First version:

- `GameCommand`: the base of a command. Type, `from_args`, `args`, `can_run` (`&""` = can), `run`, optional undo, `seat` and `to_dict` (`{type, seat, args}`).
- `CommandLog`: runs only valid commands, logs the accepted ones, undoes the last one, replays a log (stopping at the first that does not run, with `is_replaying()` so a listener does not send commands twice) and builds commands from their entries.
- `CommandBus`: command types from the inspector, a default `context`, `use_log` and `rebuilt`.
- Example `examples/minimal` (stones on a board with Undo and Replay), the kit's own tests and `commandkit_lab/`.
