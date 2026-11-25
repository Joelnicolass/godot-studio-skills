# TurnKit changes

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
