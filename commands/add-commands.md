---
description: "Validated moves (CommandKit addon): do_<name> in your game with can_ (the reason) and undo_ (take it back), a GameCommands node and a history you save, send and replay."
---

Add **validated moves with a history** to the **game's Godot project** with the CommandKit addon:
- a `do_<name>(seat, args…)` function per thing the player can do, on the game's node;
- a `can_<name>` where the move may not be valid (it returns the reason) and an `undo_<name>` where it can be undone;
- a `GameCommands` child of the game, and the screen running `commands.run(seat, &"place", [cell])`;
- if needed: a general `can_run` (turn), Undo, replaying a history, saving it or sending the moves over the network.

Then the person sees in the inspector the moves it found (`found_commands`) and tries them with F6; the agent builds and explains.

This is **not** the game's rules or state: those are yours, the kit runs the moves and writes them down. **Not** randomness (the seed lives in your state) nor the network: a network game sends the name and the arguments and puts the seat on the server.

Load: `godot-command-kit`, `godot-composition-first`.

If `addons/command_kit/` is missing:

```bash
./install.sh --addon /ABS/GODOT_ROOT command_kit
```

Enable **CommandKit**. If `godot-studio-workflow` is loaded: orchestrator → tree (this chat for 1–3 files; otherwise `studio-tech-lead`) → OK → `studio-developer`. No extra subagent.

## 1. Scope

If missing, ask in a single batch:

1. What a player can do (each thing is a move) and which arguments it takes (a cell, a unit and a destination).
2. When a move is not valid and how it is said (the short reason: `"not_your_turn"`, `"occupied"`), and whether there is a check common to all of them (the turn, the match not being over).
3. Which ones can be undone (a dice roll or a revealed card cannot) and whether undo needs a value (which piece was captured).
4. Where the state lives today and whether the rules are a node or a `RefCounted` with no scene.
5. Whether the history has to be saved, a match replayed (with randomness? the seed) or a Replay shown.
6. Whether the game is networked (with MpKit or what) and who sends the moves (a client, a bot).

## 2. Plan

Show the file tree before touching the game (`[+]` new, `[~]` changed, `[-]` deleted), for example:

```
[~] project.godot                        # CommandKit plugin
[~] game/stones.gd                       # typed state + can_place / do_place / undo_place, and can_run (turn)
[~] game/game.tscn                       # + Commands (GameCommands): empty game = the parent
[~] game/hud.gd                          # click → commands.run(...); rejected → the reason; Undo → commands.undo()
[+] game/replay.gd                       # saves history(), clear(), resets the state and replays with the same seed
```

Start from `addons/command_kit/examples/minimal` (stones on a board with rejection, Undo and Replay).

## 3. Implement

Follow [godot-command-kit](../skills/godot-command-kit/SKILL.md) and `addons/command_kit/README.md`.

- The functions on the game's node (or on a rules `RefCounted` with `CommandLog.new(self)` and `use_log` in the scene). `seat` first; typed state, no loose dictionaries.
- `can_<name>` returns `""` or the reason and changes nothing; the common check goes in `can_run(seat, command, args)`.
- `undo_<name>` with the same parameters, or one more if it needs what `do_<name>` returned.
- The screen runs moves with `commands.run(...)` and listens to `rejected` to say why not; `done` and `undone` to refresh.
- Replay: `history()`, `clear()`, the state back to the start (the same seed) and `replay(history)`; listeners that answer check `is_replaying()` in the handler.
- Save the history with `var_to_str` or `var_to_bytes`. Over the network, `mp_sv_command(command, args)` runs `commands.run(net.sender_slot(), command, args)`.
- Tell the person where to see the moves it found: `found_commands` in the node's inspector.

## 4. Done when

- The node shows no warnings and `found_commands` lists the moves.
- F6: a valid move runs, an invalid one is rejected with its reason and leaves no trace, Undo takes the last one back and replaying the history gives the same state.
- Over the network, the server puts the seat and an invented move is rejected with no errors.
- Nothing of the rules, randomness or network inside `addons/command_kit`.
