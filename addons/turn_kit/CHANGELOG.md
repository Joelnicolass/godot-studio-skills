# TurnKit changes

## 0.1.0

First version:

- `TurnCycle`: turns, rounds and cycles as plain data. Actions per turn, rounds from `first_seat`, cycles and an end you set (0 = no end), inactive seats, signals in a fixed order and `to_dict` / `from_dict`.
- `TurnClock`: builds the cycle from the inspector with one `TurnSeat` child per player, or shows your rules' cycle (`use_cycle`). `autostart`.
- `TurnSeat`: name, `is_bot`, `active` and signals of its own.
- Example `examples/minimal`, the kit's own tests and `turnkit_lab/`.
