---
name: godot-command-kit
description: >-
  Validated moves in a Godot 4 game, with the CommandKit addon: every move is a
  named function of the game (do_place, and optionally can_place with the
  rejection reason and undo_place to take it back), a GameCommands node that
  finds and runs them, and a history that is undone, saved, sent and replayed on
  a fresh state with the same seed. The arguments are checked against the
  signature and only do_* functions run, so it fits receiving moves from the
  network. Use when the user wants undo, a move history, replaying a match,
  validating moves with a reason ("not your turn", "occupied cell"), a
  turn-based game or a puzzle with undo, moves over the network without trusting
  the client or /add-commands. Not the game's rules, randomness or the network.
---

# Godot — validated moves with a history (CommandKit)

Addon `addons/command_kit/` in the **game's** project. Reference: `addons/command_kit/README.md`.

If the addon is missing:

```bash
./install.sh --addon /path/to/godot-project command_kit
```

Enable the **CommandKit** plugin (the `GameCommands` type in Create Node; the node works without it). Scoped request: `/add-commands`. Composition: [godot-composition-first](../godot-composition-first/SKILL.md).

## Rules

- **A move is a function of the game.** `do_<name>(seat, args…)` does it. Optional: `can_<name>(seat, args…) -> String` (`""` = it can, or the reason) and `undo_<name>(seat, args…)` (if it exists, the move can be undone). No command classes.
- **`seat` is always the first parameter.** Who asks for it; a single-player game passes `0`.
- **One node.** A `GameCommands` child of the game's node (or with `game` pointing at it). The inspector shows `found_commands`: what it found.
- **Only `do_*` run.** `run(0, &"queue_free")` is rejected with `unknown_command`. The arguments are checked against the signature (`bad_arguments`): never rely on anything else for a move that comes from the network.
- **The reason is a short text** (`"not_your_turn"`), not a sentence: the screen translates it with `tr()` (a `can_` always returns a `String`; `false` gives `not_allowed`).
- **The checks common to every move, in one place.** `can_run(seat, command, args)` in the game runs before the `can_<name>` of each one.
- **Functions do not change the state other than `do_` and `undo_`.** A `can_` changes nothing. A move does not run another (`busy`): emit a signal and run the other from a `done` listener.
- **Undo = the last one.** If `undo_<name>` has one more parameter than `do_<name>`, it gets what `do_<name>` returned (the captured piece). A dice roll or a revealed card has no `undo_`.
- **Repeatable randomness.** The `RandomNumberGenerator` with its `seed` lives in the game's state; `replay` on a fresh state with the same seed gives the same result.
- **A listener that answers** (a bot, an effect) checks `is_replaying()` in the handler itself, before any `call_deferred` or `await`.
- **The history is saved with `var_to_str`** (or `var_to_bytes`, or `JSON.from_native`), not `JSON.stringify`: a `Vector2i` does not survive.
- **Headless rules use `CommandLog`:** `CommandLog.new(self)` in a `RefCounted` and `commands.use_log(rules.commands)` in the scene.
- **No kit depends on another.** CommandKit has no network or rules: the game connects.

## Network

The seat **never travels**: the client sends the name and the arguments, and the server puts the seat of whoever sent it. **With MpKit**:

```gdscript
# client
net.to_server(&"command", &"place", [cell])


# server (the MpActor): sender_slot() says who sent it
func mp_sv_command(command: StringName, args: Array) -> void:
	commands.run(net.sender_slot(), command, args)
```

A move that does not exist or is malformed is rejected on its own, running nothing and raising no errors. **Without MpKit:** the same `run(slot_of_whoever_sent_it, name, args)` from the game's network input.

## Tree

```
Game (Node)                  # game.gd: typed state and do_place / can_place / undo_place; optional can_run
├── Commands (GameCommands)  # empty game = the parent
└── Hud                      # click → commands.run(seat, &"place", [cell]); rejected → the reason; Undo → commands.undo()
```

Start from `addons/command_kit/examples/minimal/minimal.tscn` (stones on a board with rejection, Undo and Replay).

## What goes where

| Kit | Game |
| --- | --- |
| Finding the `do_*`, checking the arguments, running the checks in order | The `do_`, `can_` and `undo_` functions and the rules inside them |
| The history: copy, undo, replay, `is_replaying()` | The (typed) state and the seeded RNG |
| The kit's own reasons: `unknown_command`, `bad_arguments`, `not_allowed`, `busy` | The game's reasons (`"occupied"`) and how the screen says them |
| `done`, `rejected`, `undone` | What is animated or heard with each one |
| Nothing of the network | Sending the name and the arguments, and putting the seat on the server |

## Essential API

| What | How |
| --- | --- |
| Run | `commands.run(seat, &"place", [cell]) -> String` (`""` = it ran) |
| Ask without running | `commands.can_run(seat, &"place", [cell]) -> String` |
| Undo | `commands.can_undo()`, `commands.undo()` |
| Save and replay | `commands.history()`, `commands.clear()`, `commands.replay(history) -> String` |
| Show your rules' log | `commands.use_log(rules.commands)`, `commands.use_own_log()` |
| Signals | `done(seat, name, args)`, `rejected(seat, name, args, reason)`, `undone(seat, name, args)`, `rebuilt` |

## Done when

- The node shows no warnings and `found_commands` lists the game's moves.
- F6: a valid move runs; an invalid one is rejected with its reason and leaves no trace; Undo takes the last one back; replaying the history on a fresh state gives the same state.
- Over the network, `run` gets the server's seat and an invented move is rejected with no errors.
- `godot --headless --path commandkit_lab --script res://addons/command_kit/tests/command_test_runner.gd` prints `COMMANDKIT TESTS PASS` (in the kit's repo).

## Anti-patterns

- A class per command, `command_type()`, `from_args()`: those are 0.1. A move is a function.
- Sending the `seat` from the client and trusting it: the server puts it.
- A `can_` that changes the state, or a `do_` that calls `commands.run()`: it gives `busy`.
- Saving the history with `JSON.stringify` and losing the `Vector2i`.
- Leaving randomness outside the state (a global `randi()`): the replay does not give the same result.
- A `.tres` or an autoload for the history: it is a node in the scene or a `CommandLog` in the rules.
- Having a `done` listener send moves of its own without checking `is_replaying()`: the history duplicates them.
