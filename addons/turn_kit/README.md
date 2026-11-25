# TurnKit

Turns, rounds and cycles for strategy, board, card, tactics or turn-based RPG games. It has two levels:

- **`TurnCycle`**: turns as plain data (`RefCounted`, no nodes, no scene). It knows whose turn it is, how many actions are left, which round and cycle the match is in, and when it ends. Your game's rules use it directly, and it tests headless.
- **Nodes for the scene**:
  - `TurnClock` builds or shows a `TurnCycle` with the numbers from the inspector.
  - `TurnSeat` is a player: one child of the clock per seat.

TurnKit has **no** game rules, bots, network or autoload. What an action costs, or what happens at the end of a cycle, is up to your game, listening to the signals.

## Install

```bash
./install.sh --addon /path/to/godot-project turn_kit
```

Enable the **TurnKit** plugin (types `TurnClock` and `TurnSeat` in Create Node).

## In 3 steps

1. Add a `TurnClock` and set `actions_per_turn`, `rounds_per_cycle` and `cycles` in the inspector (0 = no end).
2. Give it one `TurnSeat` child per player, in the order they play. The first one is seat 0.
3. Connect the signals and spend actions:

```gdscript
@onready var turns: TurnClock = $Turns


func _ready() -> void:
	turns.turn_started.connect(_on_turn_started)
	turns.cycle_ended.connect(func(n: int) -> void: print("Era over: ", n))


func _on_move_pressed() -> void:
	if turns.spend_action():
		move_unit()


func _on_end_pressed() -> void:
	turns.end_turn()
```

## Minimal example

`examples/minimal/minimal.tscn` (F6): three seats (Ana, Beto and a bot). **Spend action** uses an action and **End turn** passes the turn. The bot passes by itself. Two rounds make a cycle, and the match ends after two cycles.

```
Minimal              # minimal.gd: shows the state and connects the buttons
├── Box              # status, Spend action and End turn buttons, log
└── Turns            # TurnClock: rounds_per_cycle = 2, cycles = 2
    ├── Ana, Beto    # TurnSeat
    └── Bot          # TurnSeat: is_bot = true
```

## How it counts

- **Turn:** starts with `actions_per_turn` actions. `spend_action(n)` spends `n`, and returns false without changing anything when there are not enough.
  - Spending the last action does **not** end the turn. `end_turn()` does, and it is also valid with actions left.
- **Round:** one turn of every active seat, starting at `first_seat`. If that seat is inactive, the next active one starts.
- **Cycle:** `rounds_per_cycle` rounds (an era, a year). With 0, rounds are counted but cycles never end.
- **End:** after `cycles` cycles. With 0, the match never ends. It also ends when no seat is active.
- **Signal order in `end_turn()`:** `turn_ended(seat)`, then `round_ended(n)`, `cycle_ended(n)` and `finished` when they apply, and last `turn_started(next)` if the match goes on.
- **Inactive seats** (eliminated, disconnected): they are skipped. A seat made active again plays from the next round.
- **Determinism:** no randomness and no real time. `to_dict()` and `TurnCycle.from_dict()` keep the whole state, mid-turn included.

## API

### `TurnCycle` (RefCounted)

| Member | What it does |
| --- | --- |
| `TurnCycle.new(seats, actions_per_turn, rounds_per_cycle, cycles)` | A turn cycle. All optional (2, 3, 0, 0) |
| `seats`, `actions_per_turn`, `rounds_per_cycle`, `cycles`, `first_seat` | The setup. A change of actions counts from the next turn, one of `first_seat` from the next round |
| `start(first := -1)` | Starts round 1 of cycle 1 |
| `spend_action(amount := 1) -> bool` | Spends actions of the turn |
| `end_turn() -> bool` | Ends the turn and starts the next one |
| `set_seat_active(seat, active)`, `is_seat_active(seat)` | Skip a seat |
| `current_seat`, `actions_left`, `round_number`, `cycle_number`, `rounds_in_cycle`, `is_started`, `is_finished` | The state. `current_seat` is -1 before the start and after the end |
| `round_order()` | The seats of the current round, in order |
| `to_dict()` / `TurnCycle.from_dict(data)` | Plain data to save, send over the network or compare a replay |
| signals `turn_started(seat)`, `action_spent(left)`, `turn_ended(seat)`, `round_ended(n)`, `cycle_ended(n)`, `finished` | Past tense: it already happened |

### `TurnClock` (Node)

- **Inspector:** `actions_per_turn`, `rounds_per_cycle`, `cycles`, `first_seat` and `autostart`.
  - `autostart` starts the clock's **own** cycle by itself once the scene is ready. Turn it off and call `start()`.
- **Cycle:** `turn_cycle` is the `TurnCycle` it shows. `use_cycle(cycle)` shows your rules' cycle instead of its own, and `use_own_cycle()` goes back to the inspector's. `owns_cycle()` tells which one it shows.
  - A cycle from `use_cycle` is **never restarted**: neither `autostart` nor `start()` takes it back to round 1, so one loaded from a save stays on its turn. If it has not started yet, `start()` starts it.
  - With `use_cycle`, `TurnSeat.active` does not touch your rules' seats: your rules decide who is active.
- **Methods:** `start()`, `spend_action()`, `end_turn()`, `set_seat_active()`, `seat_nodes()`, `seat_node(seat)` and `current_seat_node()`.
- **State:** `current_seat` and `actions_left`.
- **Signals:** the same as `TurnCycle`, plus `rebuilt` when the clock starts showing another cycle (`use_cycle`, `use_own_cycle` or `start()` of its own). When it arrives, read the state again.

### `TurnSeat` (Node, child of a `TurnClock`)

- **Inspector:** `display_name`, `is_bot` (TurnKit only stores it; your game uses it) and `active` (for the clock's own cycle only).
- **Methods:** `index()` (its seat number) and `is_current()`.
- **Signals:** `turn_started` and `turn_ended`, for that seat only. Good for a bot or one player's HUD.

## Tips

- **Rules use `TurnCycle`, not the nodes.** Keep it in your match state and show it with `clock.use_cycle(state.turns)`. The rules run headless and the HUD listens to the clock's signals. Your rules start it (`state.turns.start()`), or it comes already started from a save.
- **An upkeep phase at the end of a cycle:** listen to `cycle_ended`. It arrives before the new cycle's `turn_started`, in the same `end_turn()` call. If the phase needs the player to choose something, your game settles it before taking orders for the new turn.
- **Network:** the cycle knows nothing about the network. Send `to_dict()` in the snapshot, or replay the same orders on every machine.

## Tests

```bash
godot --headless --path turnkit_lab --script res://addons/turn_kit/tests/turn_test_runner.gd
```

It prints `TURNKIT TESTS PASS (n)`. The tests cover:

- Actions, the order of turns and signals, rounds, cycles, the end and no end.
- `first_seat` (negative or out of range too), inactive seats, running out of seats and `to_dict`.
- The nodes: seats as children, per-seat signals, `autostart`, `use_cycle` with no restart (with a started cycle and one from `from_dict`), `rebuilt` and the editor warnings.
- The example played with its buttons.
- That the addon names no other kit.
