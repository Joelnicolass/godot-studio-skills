---
name: godot-turn-kit
description: >-
  Turns for a Godot 4 game with the TurnKit addon: whose turn it is, how many
  actions are left, phases inside the turn (draw, play, discard), time per turn,
  rounds, cycles (eras, years), the end of the match, a first player that rotates,
  a round order of your own (initiative) and seats that are skipped. A TurnCycle
  as plain data that the rules use directly and a TurnClock in the scene with one
  TurnSeat per player. Use when the user wants turns, rounds, turn phases, a time
  limit per turn, initiative, strategy or turn-based board or card games, a
  tactics RPG, who plays now or /add-turns. Not the game's rules (what an action
  costs, what a phase does), nor bots, nor the network.
---

# Godot — turns (TurnKit)

Addon `addons/turn_kit/` in the **game's** project. Reference: `addons/turn_kit/README.md`.

If the addon is missing:

```bash
./install.sh --addon /path/to/godot-project turn_kit
```

Enable the **TurnKit** plugin (types `TurnClock` and `TurnSeat` in Create Node). Scoped request: `/add-turns`. Composition: [godot-composition-first](../godot-composition-first/SKILL.md).

## Rules

- **Turns are data.** `TurnCycle` is a `RefCounted` with no nodes and no clock: the game keeps it in its state and its rules use it directly (it tests headless). `TurnClock` builds it from the inspector or shows the rules' one with `use_cycle`.
- **A `use_cycle` is never restarted.** Neither `autostart` nor `start()` takes it back to round 1, and the inspector values and `TurnSeat.active` do not touch it: the game is in charge.
- **Everything new is optional.** Phases, time, a rotating first player and a custom order come off. Do not turn them on if the game does not ask for them.
- **Turn phases.** `phases` in the inspector; `next_phase()` moves to the next one and in the last one it ends the turn. `end_turn()` ends it from any phase. Actions belong to the turn, not the phase.
- **Time comes in through `tick(delta)`.** The core does not read the clock: `TurnClock` ticks every frame (`advance_time`), never in the editor. In a network game the clients turn `advance_time` off and the server sends `to_dict()`.
- **Initiative.** In `round_ended`, `set_round_order([...])` with the order the rules compute: it counts for the round that is about to start.
- **Signals in the past tense, in a fixed order.** When a turn ends: `phase_ended` → `turn_ended` → `round_ended` / `cycle_ended` / `finished` → `turn_started` → `phase_started`. Running out of time: `turn_timed_out`, and only then the turn ends.
- **A bot that passes by itself** ends its turn with `end_turn.call_deferred()`.
- **No action limit:** do not call `spend_action`.
- **No kit depends on another.** TurnKit knows nothing about network, bots or cards: the game connects them.

## Tree

```
Game
├── Turns (TurnClock)        # actions_per_turn, phases, turn_seconds, first_seat_rotates, rounds_per_cycle, cycles
│   ├── Ana (TurnSeat)       # display_name; seat 0
│   ├── Beto (TurnSeat)      # seat 1
│   └── Bot (TurnSeat)       # is_bot: the game uses it
└── Hud                      # listens to the clock's signals
```

Start from `addons/turn_kit/examples/minimal/minimal.tscn`: three seats, phases, 10 seconds per turn and a rotating first player.

## What goes where

| Kit | Game |
|---|---|
| Whose turn it is, phases, actions left, time | What an action costs, what is done in each phase |
| Rounds, cycles, the end, who opens the round | What happens at the end of a round or cycle (upkeep, income) |
| The round order it is given | How initiative is computed |
| Active and inactive seats | Who gets eliminated |
| `to_dict()` / `from_dict()` | Saving, sending over the network, the server that calls `tick` |

## Essential API

- `TurnCycle.new(seats, actions_per_turn := 1, rounds_per_cycle := 0, cycles := 0)`; `phases`, `turn_seconds`, `timeout_ends_turn`, `first_seat`, `first_seat_rotates`.
- `start()`, `spend_action(n)`, `next_phase()`, `end_turn()`, `tick(delta)`, `set_round_order(order)`, `set_seat_active(seat, active)`.
- State: `current_seat`, `actions_left`, `current_phase`, `time_left`, `round_number`, `cycle_number`, `round_first_seat`, `is_finished`.
- Signals: `turn_started`, `phase_started`, `phase_ended`, `action_spent`, `turn_timed_out`, `turn_ended`, `round_ended`, `cycle_ended`, `finished`.
- `TurnClock`: the same with the inspector (groups Turn, Round, Phases, Time), `use_cycle(cycle)`, `use_own_cycle()`, `rebuilt`.

## Done when

- The `TurnClock` shows no warnings and each player is a `TurnSeat` child, in order.
- F6: turns pass in the expected order, phases and time (if used) show in the HUD, and the turn passes by itself when time runs out.
- The match ends when it should (cycles or no active seats).
- `godot --headless --path turnkit_lab --script res://addons/turn_kit/tests/turn_test_runner.gd` prints `TURNKIT TESTS PASS` (in the kit's repo).

## Antipatterns

- Writing the game's rules inside the kit's nodes: they go in `TurnCycle` and in your signals.
- Reading the system clock for the turn's time: use `tick(delta)` with a step you decide.
- Restarting a cycle that comes from a save: `use_cycle` shows it as it is.
- Ending a bot's turn in the same call as `turn_started`: use `call_deferred`.
- Keeping the time by hand in the game when `turn_seconds` and `tick` already do it.
