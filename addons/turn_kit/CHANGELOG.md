# TurnKit changes

## 0.3.0

Everything new is optional and off by default: a game that does not use it sees nothing new.

- New: **first player that rotates** (`first_seat_rotates`, `round_first_seat`): each round is opened by the seat after the one that opened the last round.
- New: **round order of your own** (initiative): `set_round_order(order)` and `custom_round_order()`. It counts from the next round (called from `round_ended`, for the one about to start); `[]` goes back to the order by seat.
- New: **phases inside the turn** (`phases`, `current_phase`, `phase_index`, `next_phase()`) and the `phase_started` and `phase_ended` signals. Actions still belong to the whole turn.
- New: **time per turn** (`turn_seconds`, `time_left`, `timeout_ends_turn`, `tick(delta)`) and the `turn_timed_out` signal. The core does not read the system clock: time comes in through `tick`.
- `TurnClock`: new inspector properties in groups (Turn, Round, Phases, Time), `advance_time` (the clock ticks every frame, never in the editor), methods `next_phase()`, `set_round_order()` and `tick()`, properties `current_phase` and `time_left`, the new signals relayed, and warnings for a phase with an empty or repeated name. The new values apply to the own cycle (live too), never to one from `use_cycle`.
- `to_dict()` / `from_dict()` keep all the new state; `from_dict` still reads 0.2 dicts.
- Change: `actions_per_turn` is **1** by default (it was 3), in `TurnCycle.new` and in `TurnClock`. A scene that relied on the 3 has to set it in the inspector.
- `minimal` example: phases (`draw`, `play`) with the **Next phase** button, 10 seconds per turn with the time in the status, and the rotating first player.
- README: "How it counts" with phases, time, round and the full signal order; tips for initiative, no action limit and network; "Migrating from 0.2".
- New tests for every case (48 in all), and `test_independence` with the final class names of the other kits.
- New: `godot-turn-kit` skill and `/add-turns` command.

## 0.2.0

- Fix: `autostart` and `start()` no longer restart a cycle shown with `use_cycle`. A started cycle, or one restored with `from_dict`, stays on its turn, and `start()` only starts it if it had not started.
- Fix: with `use_cycle`, `TurnSeat.active` no longer overwrites your rules' active seats.
- New: `rebuilt` signal on `TurnClock` when it starts showing another cycle, and `owns_cycle()`.
- `TurnCycle`: a negative or out-of-range `first_seat` wraps around (`posmod`), and running out of seats ends the match with no division by zero.
- README: the example's buttons are named as they read on screen.

## 0.1.0

First version:

- `TurnCycle`: turns, rounds and cycles as plain data. Actions per turn, rounds from `first_seat`, cycles and an end you set (0 = no end), inactive seats, signals in a fixed order and `to_dict` / `from_dict`.
- `TurnClock`: builds the cycle from the inspector with one `TurnSeat` child per player, or shows your rules' cycle (`use_cycle`). `autostart`.
- `TurnSeat`: name, `is_bot`, `active` and signals of its own.
- Example `examples/minimal`, the kit's own tests and `turnkit_lab/`.
