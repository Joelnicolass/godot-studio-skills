---
description: "Turns (TurnKit addon): whose turn it is, actions, phases, time per turn, rounds, cycles, a rotating first player and initiative; a TurnClock with one TurnSeat per player, or a TurnCycle in the rules."
---

Add **turns** to the **game's Godot project** with the TurnKit addon:
- a `TurnClock` with one `TurnSeat` per player, or a `TurnCycle` in the game's rules shown with `use_cycle`;
- actions per turn, rounds, cycles and the end of the match;
- if needed, phases inside the turn, time per turn, a rotating first player or a round order of your own (initiative).

Then the person sees the clock's warnings in the inspector and plays the flow with the game's buttons; the agent builds and explains.

This is **not** the game's rules (what an action costs, what is done in each phase), nor bots, nor the network: the kit keeps count of the turns and the game listens to the signals.

Load: `godot-turn-kit`, `godot-composition-first`.

If `addons/turn_kit/` is missing:

```bash
./install.sh --addon /ABS/GODOT_ROOT turn_kit
```

Enable **TurnKit**. If `godot-studio-workflow` is loaded: orchestrator → tree (this chat for 1–3 files; otherwise `studio-tech-lead`) → OK → `studio-developer`. No extra subagent.

## 1. Scope

If missing, ask in a single batch:

1. How many players there are, which are bots and who opens; whether each round is opened by the same one or it rotates.
2. How many actions a turn has (or none: no limit) and whether the turn has phases (which, in what order).
3. Whether there is time per turn (how many seconds) and what happens when it runs out: it passes by itself or only warns.
4. Whether the round order is fixed or decided by the game (initiative, who plays first by a roll or a score).
5. How many rounds make a cycle (an era, a year), how many cycles the match lasts or whether it never ends, and what happens at the end of each round or cycle.
6. Where the rules live today (the match state) and whether the game is networked (with MpKit or with what).

## 2. Plan

Show the file tree before touching the game (`[+]` new, `[~]` changed, `[-]` deleted), for example:

```
[~] project.godot                        # TurnKit plugin
[+] scenes/turns/turns.tscn              # TurnClock: actions_per_turn, phases = [draw, play], turn_seconds = 30; one TurnSeat per player
[~] game/state.gd                        # the rules' TurnCycle (if the rules keep it); use_cycle on the clock
[~] scenes/hud/hud.gd                    # listens to turn_started, phase_started, turn_timed_out; shows time_left
[~] game/rules.gd                        # in round_ended: set_round_order(initiative)
```

Start from `addons/turn_kit/examples/minimal`: three seats, phases, time and a rotating first player.

## 3. Implement

Follow [godot-turn-kit](../skills/godot-turn-kit/SKILL.md) and `addons/turn_kit/README.md`.

- One `TurnClock` with one `TurnSeat` child per player, in the order they play; the values in the inspector (groups Turn, Round, Phases, Time).
- With rules of your own: a `TurnCycle` in the game's state, shown with `clock.use_cycle(...)`; never restart it.
- The game listens to `turn_started`, `phase_started`, `turn_timed_out`, `round_ended`, `cycle_ended` and `finished`.
- `next_phase()` and `end_turn()` from the buttons or the rules; bots end their turn with `end_turn.call_deferred()`.
- Initiative: `set_round_order(...)` in `round_ended`.
- Networked: the server calls `tick` and sends `to_dict()`; the clients turn `advance_time` off.
- Tell the person what they see in the inspector (warnings, groups) and how to try the turns with F6.

## 4. Done when

- The clock shows no warnings and turns pass in the expected order.
- F6: actions, phases and time (if used) show, and the turn passes by itself when time runs out.
- The match ends when it should.
- Nothing of the game's rules, bots or network inside `addons/turn_kit`.
