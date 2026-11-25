# CommandKit

Validated commands with a log, for turn-based games, puzzles with undo, editors or command-based multiplayer. It has two levels:

- **`GameCommand` and `CommandLog`**: commands and their log as plain data (`RefCounted`, no nodes, no scene). A command says whether it can run and what it does. The log runs only valid ones, keeps the accepted ones as `{type, seat, args}`, undoes the last one and replays a whole match. Your game's rules use it directly, and it tests headless.
- **`CommandBus`** (Node): builds or shows a `CommandLog` with the command types picked in the inspector.

CommandKit has **no** game rules, randomness, network or autoload. The match state (`ctx`) is yours: the kit never looks inside it. Randomness lives in your state (a `RandomNumberGenerator` with the match seed), so replaying the log on a fresh state with the same seed gives the same result.

## Install

```bash
./install.sh --addon /path/to/godot-project command_kit
```

Enable the **CommandKit** plugin (type `CommandBus` in Create Node).

## In 3 steps

1. Write one command per thing the player can do, extending `GameCommand`:

```gdscript
class_name MoveUnit
extends GameCommand

var unit_id := 0
var to := Vector2i.ZERO


static func command_type() -> StringName:
	return &"move_unit"


static func from_args(data: Dictionary) -> GameCommand:
	var command := MoveUnit.new()
	command.unit_id = int(data.get("unit_id", 0))
	command.to = data.get("to", Vector2i.ZERO)
	return command


func args() -> Dictionary:
	return {"unit_id": unit_id, "to": to}


func can_run(ctx: Variant) -> StringName:
	if not ctx.has_unit(unit_id):
		return &"unknown_unit"
	return &""


func run(ctx: Variant) -> void:
	ctx.move(unit_id, to)
```

2. Add a `CommandBus` and put the script in `commands`.
3. Run commands and listen to rejections:

```gdscript
@onready var bus: CommandBus = $Commands


func _ready() -> void:
	bus.context = match_state
	bus.rejected.connect(func(_cmd: GameCommand, why: StringName) -> void: hud.say(tr(why)))


func _on_cell_clicked(cell: Vector2i) -> void:
	var move := MoveUnit.new()
	move.unit_id = selected
	move.to = cell
	move.seat = local_seat
	bus.run(move)
```

## Minimal example

`examples/minimal/minimal.tscn` (F6): two players take turns putting stones (X and O) on a 5 × 5 board. Every click is a `place_stone` command. An occupied cell is rejected and the reason shows. **Undo** takes the last stone back and **Replay** clears the board and plays the log again, one stone at a time.

```
Minimal          # minimal.gd: the state, the button board, Undo and Replay
├── Box          # status, board, Undo and Replay buttons
└── Commands     # CommandBus: commands = [place_stone.gd]
```

## How it works

- **A command** defines:
  - `static command_type()`: its name in the log, unique.
  - `static from_args(args)`: builds it again from its data.
  - `args()`: its data, plain values only (numbers, strings, `StringName`, vectors, arrays, dictionaries).
  - `can_run(ctx)`: `&""` when it can run, or the rejection code. It does not change `ctx`.
  - `run(ctx)`.
  - If it can be taken back: `can_undo()` returns true and `undo(ctx)` takes it back. Off by default, because a die roll or a revealed card cannot be returned.
  - `seat`: who sent it. Your game sets it and it stays in the log.
- **Running:** `run(cmd, ctx)` calls `can_run` and, when it gives `&""`, `run`.
  - An accepted command goes in the log and `executed` is emitted.
  - A rejected one emits `rejected(cmd, reason)` and leaves no trace.
- **Log:** `entries()` returns one `{type, seat, args}` per accepted command, oldest first. Use it to save, send over the network or compare.
- **Undo:** `undo(ctx)` takes the last command out of the log if it can be undone, and emits `undone`. Only the last one: if the last cannot be undone, the earlier ones cannot either.
- **Replay:** `replay(entries, ctx)` builds each command with `make` and runs it.
  - It stops at the first one that does not run and returns its code, or `UNKNOWN_COMMAND` when the type is not registered.
  - Replayed commands are added at the end of the log. On an empty log (call `clear()` first), a full replay leaves it equal to the original.
  - While it runs, `is_replaying()` is true. A listener that sends commands of its own (a bot, an automatic effect) sends nothing then, because its commands are in the log already and would run twice.

## API

### `GameCommand` (RefCounted)

| Member | What it does |
| --- | --- |
| `static command_type() -> StringName` | The type in the log |
| `static from_args(args) -> GameCommand` | The command from its data |
| `args() -> Dictionary` | Its data |
| `can_run(ctx) -> StringName` | `&""` = can run; otherwise the rejection code |
| `run(ctx)`, `can_undo()`, `undo(ctx)` | Doing and undoing it |
| `seat`, `type()`, `to_dict()` | Who sent it, its type and its log entry |

### `CommandLog` (RefCounted)

| Member | What it does |
| --- | --- |
| `register(script) -> bool`, `has_type(type)`, `types()` | The command types it can build |
| `run(cmd, ctx) -> StringName` | Runs a valid command and logs it |
| `can_undo()`, `undo(ctx) -> bool` | Undoes the last one |
| `replay(entries, ctx) -> StringName`, `is_replaying()` | Replays a log; `is_replaying()` is true while it runs |
| `make(entry)`, `entries()`, `last()`, `size()`, `clear()` | The log |
| `keep_log` | Off: commands run and emit, but nothing is kept |
| `UNKNOWN_COMMAND`, `NO_COMMAND` | The kit's own codes |
| signals `executed(cmd)`, `rejected(cmd, reason)`, `undone(cmd)` | Past tense: it already happened |

### `CommandBus` (Node)

- **Inspector:** `commands` (the command scripts it can build) and `keep_log`.
- **Context:** `context` is the `ctx` used when `run`, `undo` or `replay` get none. Usually your match state.
- **Log:** `command_log` is the `CommandLog` it shows. `use_log(log)` shows your rules' log and `use_own_log()` goes back to its own, empty one.
- **Methods:** `run`, `can_undo`, `undo`, `replay`, `is_replaying`, `make`, `entries`, `size` and `clear`, with an optional `ctx`. The rest (`register`, `has_type`, `types`, `last`) goes through `command_log`.
- **Signals:** the same as `CommandLog`, plus `rebuilt` when it starts showing another log (`use_log`, `use_own_log` or new `commands`).
- **Editor warnings:** an empty slot in `commands`, a script that does not extend `GameCommand`, one with no `command_type()` and two with the same type.

## Tips

- **Rules use `CommandLog`, not the node.** Keep it with your match state and show it with `bus.use_log(rules.commands)`. The rules and the replay run headless.
- **A repeatable match:** the state keeps its seed and its RNG. To reproduce it, build a fresh state with the same seed, empty the log with `clear()` and call `replay(entries)`. Compare both states with a `to_dict()` of your own.
- **Commands that trigger commands:** if a bot or an automatic effect answers `executed` (or a `turn_started`) by sending another command, it does nothing while `is_replaying()` is true:

```gdscript
func _on_executed(command: GameCommand) -> void:
	if bus.is_replaying():
		return
	if command.seat == human_seat:
		bus.run(bot.answer(command))
```

  The check goes in the handler itself, before any `call_deferred` or `await`: a deferred answer would read it with the replay already over and send anyway.

- **Saving to a file:** `JSON.stringify` turns a `Vector2i` into the text `"(1, 2)"` and the command no longer builds the same. Save the log with `var_to_str` / `str_to_var`, `var_to_bytes` / `bytes_to_var`, or `JSON.from_native` / `JSON.to_native`.
- **Network:** the kit sends nothing. With MpKit, the client sends the command's data (`to_dict()`) to the server, and the server builds it with `make()` and runs it: the server validates, and if it accepts it, it shares it. **The server never trusts the `seat` the client sends:** it overwrites it with the sender's, and drops an entry of an unknown type.

```gdscript
func mp_sv_command(entry: Dictionary) -> void:
	var command := bus.make(entry)
	if command == null:
		return  # unknown type: not run
	command.seat = net.sender_slot()  # who sent it, not what the entry says
	bus.run(command)
```
- **Rejection codes:** use short `StringName`s (`&"not_your_turn"`) and translate them in the UI with `tr()`.

## Tests

```bash
godot --headless --path commandkit_lab --script res://addons/command_kit/tests/command_test_runner.gd
```

It prints `COMMANDKIT TESTS PASS (n)`. The tests cover:

- Running and rejecting, the log format, undo, replay on a seeded state, stopping a replay at a bad entry, replay with a listener that answers (`is_replaying`), replay on a log that is not empty, `make`, `register` and `keep_log`.
- The node: types from the inspector, the context, signals, replay, `use_log`, `rebuilt` and the editor warnings.
- The example played with its buttons.
- That the addon names no other kit.
