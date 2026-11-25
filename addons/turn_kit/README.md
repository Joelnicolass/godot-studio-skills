# TurnKit

Turns, rounds and cycles for strategy, board, card, tactics or turn-based RPG games. It has two levels:

- **`TurnCycle`**: turns as plain data (`RefCounted`, no nodes, no scene and no clock reading). It knows whose turn it is, how many actions are left, which phase and how much time, which round and cycle the match is in, and when it ends. Your game's rules use it directly, and it tests headless.
- **Nodes for the scene**:
  - `TurnClock` builds or shows a `TurnCycle` with the numbers from the inspector.
  - `TurnSeat` is a player: one child of the clock per seat.

Everything beyond "one turn per seat" is optional and off by default: a first player that rotates, phases inside the turn, time per turn and a round order of your own (initiative). A game that does not use them sees nothing new.

TurnKit has **no** game rules, bots, network or autoload. What an action costs, what is done in each phase, or what happens at the end of a cycle is up to your game, listening to the signals.

## Install

```bash
./install.sh --addon /path/to/godot-project turn_kit
```

Enable the **TurnKit** plugin (types `TurnClock` and `TurnSeat` in Create Node).

## In 3 steps

1. Add a `TurnClock` and set `actions_per_turn`, `rounds_per_cycle` and `cycles` in the inspector (0 = no end). For phases, time or a rotating first player, see the Round, Phases and Time groups.
2. Give it one `TurnSeat` child per player, in the order they play. The first one is seat 0.
3. Connect the signals and spend actions. Each player moves by spending actions on their turn, and the game finds out when a turn starts and when a cycle ends:

```gdscript
@onready var turns: TurnClock = %Turns


func _ready() -> void:
	turns.turn_started.connect(_on_turn_started)
	turns.cycle_ended.connect(func(n: int) -> void: print("Era over: ", n))


func _on_move_pressed() -> void:
	if turns.spend_action():
		move_unit()


func _on_end_pressed() -> void:
	turns.end_turn()
```

With phases and time, the game finds out about each new phase and when a player runs out of time:

```gdscript
turns.phase_started.connect(func(phase: StringName) -> void: print("Phase ", phase))
turns.turn_timed_out.connect(func(seat: int) -> void: print("Seat ", seat, " ran out of time"))
turns.next_phase()  # in the last phase it ends the turn
```

## Minimal example

`examples/minimal/minimal.tscn` (F6): three seats (Ana, Beto and a bot). Each turn has two phases (`draw`, `play`) and 10 seconds. **Spend action** uses an action, **Next phase** moves to the next phase (in the last one it ends the turn) and **End turn** passes the turn. When the time runs out the turn passes by itself and the log says so. Each round is opened by the next seat, and the log says who. The bot passes by itself. Two rounds make a cycle, and the match ends after two cycles.

```
Minimal              # minimal.gd: shows the state and connects the buttons
├── Box              # status with phase and time, Spend action, Next phase and End turn buttons, log
└── %Turns           # TurnClock: rounds_per_cycle = 2, cycles = 2, first_seat_rotates, phases = [draw, play], turn_seconds = 10
    ├── Ana, Beto    # TurnSeat
    └── Bot          # TurnSeat: is_bot = true
```

## How it counts

- **Turn:** starts with `actions_per_turn` actions (1 by default). `spend_action(n)` spends `n`, and returns false without changing anything when there are not enough.
  - Spending the last action does **not** end the turn. `end_turn()` does, and it is also valid with actions left.
  - Actions belong to the whole turn, not to a phase. If your game has no action limit, do not call `spend_action`.
- **Phases (optional):** `phases = [draw, play]`. Every turn starts in the first one. `next_phase()` moves to the next one and, in the last one, ends the turn like `end_turn()`. `end_turn()` ends the turn from any phase. Without phases, `next_phase()` is `end_turn()`. A change of `phases` counts from the next turn. `current_phase` is `&""` without phases or without a turn.
- **Time (optional):** `turn_seconds > 0` loads `time_left` when each turn starts. `tick(delta)` lowers it. At 0 it emits `turn_timed_out(seat)` **once** per turn and, with `timeout_ends_turn`, ends the turn (turn it off and the turn goes on and only warns). What is left of `delta` is lost: it does not carry over to the next turn. A change of `turn_seconds` counts from the next turn. `tick` does nothing without a turn being played, with `turn_seconds` 0, with `delta` <= 0 or once the time is over.
- **Round:** one turn of every active seat, starting at `first_seat`. If that seat is inactive, the next active one starts.
  - **First player that rotates:** with `first_seat_rotates`, each round is opened by the seat after the one that opened the last round (0, 1, 2, 0…; if it is inactive, the next active one). `round_first_seat` says who opened the current round (-1 before the start).
  - **Order of your own (initiative):** `set_round_order([2, 0, 1])` sets the order from the **next** round. Not every seat has to be listed: the ones left out do not play those rounds. Inactive seats are skipped. A seat that does not exist, or one listed twice, changes nothing. `set_round_order([])` goes back to the order by seat. While there is an order of your own, `first_seat` and the rotation do not apply. Called from `round_ended`, it counts for the round that is about to start.
- **Cycle:** `rounds_per_cycle` rounds (an era, a year). With 0, rounds are counted but cycles never end.
- **End:** after `cycles` cycles. With 0, the match never ends. It also ends when no seat is active.
- **Signal order when a turn ends:** `phase_ended(current)` (with phases), `turn_ended(seat)`, then `round_ended(n)`, `cycle_ended(n)` and `finished` when they apply, and last `turn_started(next)` and `phase_started(first)` if the match goes on. Inside the turn: `phase_ended(x)` → `phase_started(y)` on each `next_phase()`. Running out of time emits `turn_timed_out(seat)` and only then ends the turn.
- **Inactive seats** (eliminated, disconnected): they are skipped. A seat made active again plays from the next round.
- **Determinism:** no randomness and no system clock: time comes in through `tick(delta)`, so whoever calls it decides the step (with a fixed step, two machines agree). `to_dict()` and `TurnCycle.from_dict()` keep the whole state, mid-turn, mid-phase or with the time running.

## API

### `TurnCycle` (RefCounted)

| Member | What it does |
| --- | --- |
| `TurnCycle.new(seats, actions_per_turn, rounds_per_cycle, cycles)` | A turn cycle. All optional (2, 1, 0, 0) |
| `seats`, `actions_per_turn`, `rounds_per_cycle`, `cycles`, `first_seat` | The setup. A change of actions counts from the next turn, one of `first_seat` from the next round |
| `first_seat_rotates` | Each round is opened by the seat after the one that opened the last round (off by default) |
| `phases: Array[StringName]` | The phases of a turn (empty = no phases). A change counts from the next turn |
| `turn_seconds`, `timeout_ends_turn` | Seconds per turn (0 = no time) and whether the turn passes by itself when it runs out (yes by default) |
| `start(first := -1)` | Starts round 1 of cycle 1 |
| `spend_action(amount := 1) -> bool` | Spends actions of the turn |
| `next_phase() -> bool` | Moves to the next phase; in the last one (or without phases) it ends the turn |
| `end_turn() -> bool` | Ends the turn, from any phase, and starts the next one |
| `tick(delta)` | Lets `delta` seconds of the turn pass. At 0: `turn_timed_out` and, with `timeout_ends_turn`, it ends the turn |
| `set_round_order(order: Array[int])`, `custom_round_order()` | An order of your own from the next round; `[]` clears it. `custom_round_order()` returns a copy |
| `set_seat_active(seat, active)`, `is_seat_active(seat)` | Skip a seat |
| `current_seat`, `actions_left`, `current_phase`, `phase_index`, `time_left`, `round_number`, `cycle_number`, `rounds_in_cycle`, `round_first_seat`, `is_started`, `is_finished` | The state. `current_seat` is -1 before the start and after the end |
| `round_order()` | The seats of the current round, in order |
| `to_dict()` / `TurnCycle.from_dict(data)` | Plain data to save, send over the network or check a replay. `from_dict` reads 0.2 dicts too |
| signals `turn_started(seat)`, `phase_started(phase)`, `phase_ended(phase)`, `action_spent(left)`, `turn_timed_out(seat)`, `turn_ended(seat)`, `round_ended(n)`, `cycle_ended(n)`, `finished` | In the past tense: it already happened |

### `TurnClock` (Node)

- **Inspector**, in groups:
  - Turn: `actions_per_turn` (1 by default) and `autostart`.
  - Round: `rounds_per_cycle`, `cycles`, `first_seat` and `first_seat_rotates`.
  - Phases: `phases`.
  - Time: `turn_seconds`, `timeout_ends_turn` and `advance_time`.
  - `autostart` starts the clock's **own** cycle by itself, once the scene is ready. If you turn it off, call `start()`.
  - The inspector values apply to the **own** cycle, live too. Never to one from `use_cycle`.
- **Time:** with `advance_time` (default) the clock calls `tick(delta)` every frame, never in the editor. Turn it off if your rules, or the server, call `tick()`.
- **Cycle:** `turn_cycle` is the `TurnCycle` it shows. `use_cycle(cycle)` shows your rules' one instead of the own, and `use_own_cycle()` goes back to the inspector one. `owns_cycle()` says which one it shows.
  - A `use_cycle` cycle is **never restarted**: neither `autostart` nor `start()` takes it back to round 1, so one loaded from a save stays on its turn. If it has not started yet, `start()` starts it.
  - With `use_cycle`, `TurnSeat.active` does not touch your rules' seats: they decide who is active.
- **Methods:** `start()`, `spend_action()`, `next_phase()`, `end_turn()`, `tick(delta)`, `set_round_order(order)`, `set_seat_active()`, `seat_nodes()`, `seat_node(seat)` and `current_seat_node()`.
- **State:** `current_seat`, `actions_left`, `current_phase` and `time_left`.
- **Signals:** the same as `TurnCycle`, plus `rebuilt` when the clock starts showing another cycle (`use_cycle`, `use_own_cycle` or the own one's `start()`). When you get it, read the state again.
- **Editor warnings:** no `TurnSeat` children, `first_seat` past the last seat, and a phase with an empty or repeated name.

### `TurnSeat` (Node, child of a `TurnClock`)

- **Inspector:** `display_name`, `is_bot` (TurnKit only stores it; your game uses it) and `active` (for the clock's own cycle only).
- **Methods:** `index()` (its seat number) and `is_current()`.
- **Signals:** `turn_started` and `turn_ended`, for that seat only. Good for a bot or one player's HUD.

## Migrating from 0.2

| Before (0.2) | Now (0.3) |
| --- | --- |
| `actions_per_turn` was 3 by default | It is **1**. A scene that relied on the 3 has to set it in the inspector (a default value is not saved in the `.tscn`), and `TurnCycle.new()` takes `actions` if you need it |
| `to_dict()` with the cycle's keys | Adds `first_seat_rotates`, `round_first_seat`, `custom_order`, `phases`, `turn_phases`, `phase_index`, `turn_seconds`, `time_left`, `timeout_ends_turn` and `timed_out`. `from_dict` still reads 0.2's |
| The clock had no time | `TurnClock` ticks by itself (`advance_time`). With `turn_seconds` at 0 nothing happens |
| Everything else | The same: signals, `use_cycle`, `rebuilt`, `TurnSeat` |

## Tips

- **Rules use `TurnCycle`, not the nodes.** Keep it in your match state and show it with `clock.use_cycle(state.turns)`. The rules run headless and the HUD listens to the clock's signals. Your rules start it (`state.turns.start()`), or it comes already started from a save.
- **An upkeep phase at the end of a cycle:** listen to `cycle_ended`. It arrives before the new cycle's `turn_started`, in the same `end_turn()` call. If the phase needs the player to choose something, your game settles it before taking orders for the new turn.
- **Initiative:** order the seats at the end of each round. In `round_ended`, call `set_round_order(...)` with the seats by the initiative your rules roll or compute: it counts for the round that is about to start.
- **No action limit:** do not call `spend_action`. `actions_left` stays at `actions_per_turn` and the turn is ended by `end_turn()` (or `next_phase()` in the last phase).
- **A bot that passes by itself:** end its turn from `turn_started` with `end_turn.call_deferred()`: that way the turn is seen whole (`phase_started` included) before it ends. Ending it in the same call is valid too: that turn emits no phase signals.
- **Network:** the cycle knows nothing about the network. Send `to_dict()` in the snapshot, or replay the same orders on every machine. Time comes in through `tick(delta)`: on the server, show the cycle with `use_cycle` and send its `to_dict()`. On the clients **turn `advance_time` off** so they do not run a clock of their own, and show the cycle that arrives in each snapshot.

## Tests

```bash
godot --headless --path turnkit_lab --script res://addons/turn_kit/tests/turn_test_runner.gd
```

It prints `TURNKIT TESTS PASS (n)`. The tests cover:

- Actions (1 by default), the order of turns and signals, rounds, cycles, the end and no end.
- `first_seat` (negative or out of range too), the rotating first player (with inactive seats and another `first_seat`), the order of your own (from the next round, from `round_ended`, partial, invalid, empty), inactive seats and running out of seats.
- Phases: the exact order of signals, `next_phase` in the last phase and without phases, `end_turn` mid-phase and a change of `phases` mid-turn.
- Time: partial `tick`, exact, overshoot, only once, with and without `timeout_ends_turn`, reload on the next turn, before the start and after the end.
- `to_dict` / `from_dict` with all the new state (mid-turn, mid-phase and with the time running, going on the same in the original and the copy) and with a 0.2 dict.
- The nodes: seats as children, the inspector values on the own cycle and live, per-seat and relayed signals, `autostart`, `use_cycle` with no restart and no overwrite, `advance_time` and `_process`, `rebuilt` and the editor warnings.
- The example played with its buttons and the time pushed by hand.
- That the addon names no other kit.
