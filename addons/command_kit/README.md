# CommandKit

Validated moves with a rejection reason, undo, and a history you save, send and replay. For turn-based games, puzzles with undo, editors and command-based multiplayer.

Every move is a function of your game with a name: `do_place`, and optionally `can_place` (why not) and `undo_place` (how to take it back). CommandKit has **no** game rules, randomness, network or autoload: the state and the rules are yours; the kit only runs the valid moves and writes them down.

## Install

```bash
./install.sh --addon /path/to/godot-project command_kit
```

Enable the **CommandKit** plugin (type `GameCommands` in Create Node).

## In 3 steps

1. Write the functions in your game. The first parameter is always `seat`: who asks for it (a single-player game passes `0`).

```gdscript
# stones.gd (your game's node)
var stones: Dictionary[Vector2i, int] = {}
var turn := 0


func can_place(seat: int, cell: Vector2i) -> String:  # optional: "" = it can, or the reason
	if seat != turn:
		return "not_your_turn"
	return "occupied" if stones.has(cell) else ""


func do_place(seat: int, cell: Vector2i) -> void:     # the move
	stones[cell] = seat
	turn = 1 - seat


func undo_place(seat: int, cell: Vector2i) -> void:   # optional: if it exists, the move can be undone
	stones.erase(cell)
	turn = seat
```

2. Add a `GameCommands` node as a child of your game (or put your game in `game`). The inspector shows `found_commands`: the moves it found, for example `place (can, undo)`.
3. Run the moves and listen to the rejections. Clicking a cell places a stone, and if the move is rejected the HUD shows the reason:

```gdscript
@export var commands: GameCommands  # the GameCommands node, assigned in the inspector


func _ready() -> void:
	commands.rejected.connect(func(_seat: int, _name: StringName, _args: Array, reason: String) -> void: hud.say(tr(reason)))


func _on_cell_clicked(cell: Vector2i) -> void:
	commands.run(turn, &"place", [cell])
```

## Minimal example

`examples/minimal/minimal.tscn` (F6): two players take turns putting stones (X and O) on a 5 × 5 board. A click on an occupied cell is rejected and the reason shows. **Undo** takes the last stone back and **Replay** clears the board and plays the history again, one stone at a time.

```
Minimal          # minimal.gd (Control): only the screen: board buttons, Undo, Replay and the status
├── Box          # Status (Label), Board (GridContainer), Undo and Replay
├── Stones       # stones.gd (Node): THE GAME: typed state and can_place / do_place / undo_place
└── Commands     # GameCommands: game = Stones
```

## How it works

- **Moves.** They are the `do_<name>` functions of your object's script (a `Node`, or the `RefCounted` of your rules), base scripts included. Nothing else can run: `run(0, &"queue_free")` is rejected with `unknown_command`, because there is no `do_queue_free`. That closed list is what makes the network safe.
- **Arguments.** `run(seat, &"place", [cell])` checks them against the signature of `do_place`: how many (the ones with a default value may be missing) and their types. An `int` goes where a `float` is asked, `String` and `StringName` are interchangeable, a plain `Array` goes where an `Array[Vector2i]` is asked if its items are `Vector2i` (same for `Dictionary[K, V]`). If they do not match: `bad_arguments`, nothing is called and there are no script errors, even if a client sends garbage.
- **Checks, in this order:** the move exists, the arguments match, the general `can_run(seat, command, args)` if there is one, and `can_<name>(seat, args…)` if there is one. The first non-empty reason rejects. `can_` functions return a `String` or a `StringName`, and do not change the state. An untyped `can_` that returns `true` or nothing lets it run; `false` rejects with `not_allowed`; any other type is an error (it is reported) and also rejects with `not_allowed`.
- **Doing it.** `do_<name>(seat, args…)` is called. Then it goes in the history and only then `done` is emitted. A `done` listener may run another move (a bot that answers): it lands after it in the history.
- **History.** `history()` returns a **deep copy** with one `{name, seat, args}` per accepted move, oldest first. `args` are copied before `do_` is called: if `do_` changes an array it was given, the history does not change.
- **Undo.** `undo()` takes the last move out of the history and calls `undo_<name>(seat, args…)`. Only the last one: if it has no `undo_`, `can_undo()` is false and the earlier ones cannot be undone either. If `undo_<name>` declares **one parameter more** than `do_<name>`, it gets at the end what `do_<name>` returned (the captured piece, for example). That data lives in memory only: it is not in `history()`.
- **Replay.** `replay(history)` runs every entry. It returns `""` when all of them ran, or the reason of the first that did not (the ones before it already ran). The replayed ones are added at the end of the history: on an empty history (`clear()` first) a full replay leaves it equal to the original.
  - While it runs, `is_replaying()` is true. A listener that sends moves of its own (a bot, an automatic effect) sends nothing then, because its moves are in the history already.
  - A malformed entry stops it with `unknown_command` (not a dictionary, no `name`) or `bad_arguments` (`args` is not an array, `seat` is not an integer), with no script errors.
- **A move does not run another.** If `run`, `undo` or `replay` are called from inside a `can_`, a `do_` or an `undo_` of the game, the kit reports an error and returns `busy` without touching anything: the history would end up in an order that replay would duplicate. Emit a signal and run the other move afterwards, or from a `done` listener.

## API

### `CommandLog` (RefCounted)

`CommandLog.new(game)`: plain data, no nodes. Your game's rules use it directly and it tests headless. It does not keep `game` alive.

| Member | What it does |
| --- | --- |
| `game` | The object with the `do_` / `can_` / `undo_` functions. Changing it reads the moves again and keeps the history |
| `keep_history` | Off: moves still run and emit, but nothing is kept (no undo, no history) |
| `run(seat, name, args = []) -> String` | Runs a valid move. `""` = it ran; else the reason |
| `can_run(seat, name, args = []) -> String` | The same without running: changes nothing and emits nothing |
| `can_undo()`, `undo() -> bool` | Takes the last one back |
| `history() -> Array[Dictionary]` | A copy of the history: `{name, seat, args}` |
| `replay(history) -> String`, `is_replaying()` | Replays a history; `""` = all of them ran |
| `size()`, `clear()` | How many there are, and empty the history (the moves stay) |
| `commands() -> Array[StringName]`, `has_command(name)` | The moves it found (without `do_`), sorted |
| `UNKNOWN_COMMAND`, `BAD_ARGUMENTS`, `NOT_ALLOWED`, `BUSY` | The kit's own reasons: `"unknown_command"`, `"bad_arguments"`, `"not_allowed"`, `"busy"` |
| signal `done(seat, name, args)` | It ran and is in the history |
| signal `rejected(seat, name, args, reason)` | It did not run |
| signal `undone(seat, name, args)` | It was taken back |

### `GameCommands` (Node)

- **Inspector:** `game` (the node with the functions; empty = the parent), `keep_history` and `found_commands` (read only: the moves it found, `place (can, undo), pass`; not saved in the scene).
- **Methods:** those of `CommandLog`: `run`, `can_run`, `undo`, `can_undo`, `history`, `replay`, `is_replaying`, `size`, `clear`, `commands` and `has_command`.
- **Log:** `command_log` is the `CommandLog` it shows. `use_log(log)` shows your rules' one, `use_own_log()` goes back to its own (empty) and `owns_log()` says which one it is.
- **Signals:** `done`, `rejected` and `undone`, plus `rebuilt` when it shows another log (`use_log` or `use_own_log`): read it again.
- **Editor warnings:** no game, the game has no script, no `do_*`, a `do_x` with no parameters (the `seat` is missing), a `can_x` or `undo_x` with no `do_x` (almost surely a typo), a `can_x` or `undo_x` with another number of parameters than `do_x`, and a `can_x` that does not return a `String`. Your game does not need to be `@tool`.

## Tips

- **Checks common to every move.** A single function `can_run(seat: int, command: StringName, args: Array) -> String` in your game runs before the `can_<name>` of each move: put "is it your turn?" and "is the match over?" there. The order is always general → own. If an own check has to come before the general one (for example "does that unit exist?" before "is it your turn?"), do not define `can_run`: write a function with the common checks and call it first from each `can_<name>`, in the order you need.
- **The rules use `CommandLog`, not the node.** Keep it with your match state (`var commands := CommandLog.new(self)`) and show it in the scene with `%Commands.use_log(rules.commands)` (with the `Commands` node marked as a unique name: right click › "Access as Unique Name"). That way the rules and the replay run headless. `CommandLog` does not keep its game alive, so it makes no reference cycle; if the game is freed, `run` reports an error (once) and returns `unknown_command`.
- **Repeatable match.** Seeded randomness lives in your state (a `RandomNumberGenerator` with its `seed`). To reproduce a match, build a new state with the same seed, empty the history with `clear()` and call `replay(history)`: it gives the same result. Compare the two states with a `to_dict()` of your own.
- **Moves that trigger moves.** If a bot or an automatic effect answers `done` by sending another move, it does nothing while `is_replaying()` is true:

```gdscript
func _on_done(seat: int, _name: StringName, _args: Array) -> void:
	if commands.is_replaying():
		return
	if seat == human_seat:
		commands.run(bot_seat, &"place", [bot.choose_cell()])
```

  The check goes in the handler itself, before any `call_deferred` or `await`: a deferred answer would read it once the replay is over and send it anyway.

- **Saving to a file.** `JSON.stringify` turns a `Vector2i` into the text `"(1, 2)"` and the move no longer matches the signature. Save the history with `var_to_str` / `str_to_var`, `var_to_bytes` / `bytes_to_var`, or `JSON.from_native` / `JSON.to_native`.
- **Rejection reasons.** Short texts (`"not_your_turn"`) that the screen translates with `tr()`.
- **Network.** The kit sends nothing. With MpKit, **the seat never travels**: the client sends the name and the arguments, and the server puts the seat of whoever sent it (`sender_slot()`).

```gdscript
# client: a click on a cell
net.to_server(&"command", &"place", [cell])


# server (the MpActor): sender_slot() says who sent it
func mp_sv_command(command: StringName, args: Array) -> void:
	commands.run(net.sender_slot(), command, args)
```

  It is safe because only the `do_*` functions can run (a move that does not exist is rejected on its own, running nothing), the arguments are checked against the signature (a malformed move is rejected with no errors) and the seat comes from the server, not the client. The reasons `run` returns are what you tell the client.

## Migrating from 0.1

| Before (0.1) | Now (0.2) |
| --- | --- |
| A `GameCommand` subclass per command | Three functions in your game: `do_<name>`, and optionally `can_<name>` and `undo_<name>` |
| `command_type()`, `from_args()`, `args()` | Gone: the name is the function's and the arguments are its parameters |
| The command's `can_run(ctx) -> StringName` | `can_<name>(seat, args…) -> String`; `can_run(seat, command, args)` is the general check |
| The command's `run(ctx)` | `do_<name>(seat, args…)` |
| The command's `can_undo()` and `undo(ctx)` | An `undo_<name>(seat, args…)` exists |
| `command.seat` | The first parameter, `seat`, of the three functions |
| `CommandLog.register(script)` | `CommandLog.new(game)` (or `log.game = game_object`) |
| `log.run(cmd, ctx)` | `log.run(seat, &"place", [cell])` |
| `StringName` rejection | `String` rejection |
| `entries()` with `{type, seat, args: Dictionary}` | `history()` with `{name, seat, args: Array}` |
| `make(entry)` | Gone: `replay(history)` runs them directly |
| `last()` | Gone: `history()[-1]` |
| `keep_log` | `keep_history` |
| `CommandBus` with `commands` and `context` | `GameCommands` with `game` (empty = the parent) |
| Signals `executed(cmd)`, `rejected(cmd, reason)`, `undone(cmd)` | `done(seat, name, args)`, `rejected(seat, name, args, reason)`, `undone(seat, name, args)` |
| `replay(entries, ctx)` | `replay(history)` |
| `NO_COMMAND`, `UNKNOWN_COMMAND` | `UNKNOWN_COMMAND`, and the new `BAD_ARGUMENTS`, `NOT_ALLOWED` and `BUSY` |

A history saved with 0.1 (`{type, seat, args: Dictionary}`) is not read by 0.2: convert it to `{name, seat, args: Array}` with the arguments in the order of `do_<name>`.

## Tests

```bash
godot --headless --path commandkit_lab --script res://addons/command_kit/tests/command_test_runner.gd
```

It prints `COMMANDKIT TESTS PASS (n)`. The tests cover:

- Running and rejecting with a reason, the general check before the own one, unknown moves (native methods like `free` and `queue_free` included), arguments that are too many, too few, of another type, with a default value, and typed collections.
- The history (deep copy, format, `var_to_str` round trip), undo with and without a returned value, `keep_history`, replaying on a seeded state, stopping at the first bad one, replaying with a listener that answers and with malformed entries, re-entry (`busy`), a `can_` that does not return text and a game that is gone.
- A `Node` game, a `RefCounted` game and changing the game.
- The node: empty `game` = the parent, `use_log`, `rebuilt`, the signals, the editor warnings and `found_commands`.
- The example played with its buttons.
- That the addon names no other kit.
