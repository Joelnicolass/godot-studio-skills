class_name TurnCycle
extends RefCounted

## Whose turn it is, as plain data: no nodes, no scene, no real clock. Seats are numbers from 0 to `seats - 1`. Each
## turn has `actions_per_turn` actions and, if you want, `phases` and a time limit; a round is one turn of every active
## seat, starting at `first_seat` (or in an order of your own); a cycle is `rounds_per_cycle` rounds (an era, a year);
## the match ends after `cycles` cycles. 0 means no end. A game keeps one in its rules; `TurnClock` wraps one for the
## editor.

## It is `seat`'s turn now.
signal turn_started(seat: int)
## The turn moved to the phase `phase` (the first one at the start of every turn).
signal phase_started(phase: StringName)
## The phase `phase` is over (the last one just before `turn_ended`).
signal phase_ended(phase: StringName)
## The seat whose turn it is spent actions: `left` are left.
signal action_spent(left: int)
## `seat`'s time ran out (`turn_seconds`). Once per turn.
signal turn_timed_out(seat: int)
## `seat`'s turn is over.
signal turn_ended(seat: int)
## Round `n` (counted from 1 since the start) is over: every active seat had its turn.
signal round_ended(n: int)
## Cycle `n` (counted from 1) is over: it had `rounds_per_cycle` rounds.
signal cycle_ended(n: int)
## The last cycle is over. No turn starts after this.
signal finished

## How many seats there are.
var seats := 2
## Actions of each turn. A change counts from the next turn.
var actions_per_turn := 1
## Rounds of a cycle. 0: cycles never end (rounds are still counted).
var rounds_per_cycle := 0
## Cycles of the match. 0: the match never ends.
var cycles := 0
## The seat that opens the first round (the next active one if it is out), wrapped into 0 … seats - 1. Without
## `first_seat_rotates` it opens every round. A change counts from the next round.
var first_seat := 0
## On: every round is opened by the seat after the one that opened the last round (the next active one if it is out).
## A change counts from the next round.
var first_seat_rotates := false
## The phases of a turn, in order. Empty: a turn has no phases. A change counts from the next turn.
var phases: Array[StringName] = []
## Seconds of a turn. 0: no time limit. A change counts from the next turn.
var turn_seconds := 0.0
## On: when the time runs out the turn ends by itself, after `turn_timed_out`. Off: only the signal.
var timeout_ends_turn := true

## The seat whose turn it is (-1 before `start()`).
var current_seat := -1
## Actions the current seat has left.
var actions_left := 0
## The phase being played (`&""` without phases or without a turn).
var current_phase: StringName = &""
## The place of `current_phase` in `phases` (-1 without phases or without a turn).
var phase_index := -1
## Seconds the current turn has left (loaded at the start of every turn; stays 0 without `turn_seconds`).
var time_left := 0.0
## The round being played, counted from 1 since the start (0 before `start()`).
var round_number := 0
## The cycle being played, counted from 1 (0 before `start()`).
var cycle_number := 0
## Rounds already over in the current cycle.
var rounds_in_cycle := 0
var is_started := false
var is_finished := false
## The seat that opened the round being played (-1 before `start()`).
var round_first_seat: int:
	get:
		return _round_first

var _inactive: Dictionary[int, bool] = {}
var _order: Array[int] = []
var _custom_order: Array[int] = []
var _turn_phases: Array[StringName] = []
var _index := 0
var _round_first := -1
var _timed_out := false
var _turn_serial := 0
var _phase_open := false


func _init(seat_count := 2, actions := 1, rounds := 0, cycle_count := 0) -> void:
	seats = seat_count
	actions_per_turn = actions
	rounds_per_cycle = rounds
	cycles = cycle_count


## Starts round 1 of cycle 1 at `first` (or `first_seat` when -1): emits `turn_started`.
func start(first := -1) -> void:
	if seats < 1:
		push_error("TurnCycle: no seats to start with")
		return
	if first >= 0:
		first_seat = first
	is_started = true
	is_finished = false
	round_number = 1
	cycle_number = 1
	rounds_in_cycle = 0
	_round_first = -1
	_begin_round()


## Spends `amount` actions of the current turn. False, and nothing changes, when there are not that many left or no
## turn is being played. Spending the last action does not end the turn: `end_turn()` does. Actions belong to the whole
## turn, not to a phase.
func spend_action(amount := 1) -> bool:
	if not is_started or is_finished or amount < 1 or actions_left < amount:
		return false
	actions_left -= amount
	action_spent.emit(actions_left)
	return true


## Moves to the next phase of the turn. In the last phase it ends the turn, like `end_turn()`; so does a turn without
## phases. False when no turn is being played.
func next_phase() -> bool:
	if not is_started or is_finished:
		return false
	if phase_index < 0 or phase_index >= _turn_phases.size() - 1:
		return end_turn()
	_close_phase()
	phase_index += 1
	current_phase = _turn_phases[phase_index]
	_phase_open = true
	phase_started.emit(current_phase)
	return true


## Ends the current turn, from any phase, with actions left or not, and starts the next one. Emits `phase_ended` (with
## phases), `turn_ended`, then `round_ended`, `cycle_ended` and `finished` when they apply, then `turn_started` and
## `phase_started` unless the match is over. False when no turn is being played.
func end_turn() -> bool:
	if not is_started or is_finished:
		return false
	var seat := current_seat
	_close_phase()
	actions_left = 0
	time_left = 0.0
	phase_index = -1
	current_phase = &""
	_turn_phases.clear()
	turn_ended.emit(seat)
	_index += 1
	while _index < _order.size() and _inactive.has(_order[_index]):
		_index += 1
	if _index < _order.size():
		_begin_turn(_order[_index])
		return true
	round_ended.emit(round_number)
	rounds_in_cycle += 1
	if rounds_per_cycle > 0 and rounds_in_cycle >= rounds_per_cycle:
		cycle_ended.emit(cycle_number)
		if cycles > 0 and cycle_number >= cycles:
			_finish()
			return true
		cycle_number += 1
		rounds_in_cycle = 0
	round_number += 1
	_begin_round()
	return true


## Lets `delta` seconds pass in the current turn. The cycle never reads a clock: whoever calls `tick` decides the
## step (a fixed step keeps it deterministic). Nothing happens without a turn being played, without `turn_seconds`,
## with `delta` <= 0 or once the time of this turn is over. At 0 it emits `turn_timed_out` (once) and, with
## `timeout_ends_turn`, ends the turn. What is left of `delta` is lost: it does not carry to the next turn.
func tick(delta: float) -> void:
	if not is_started or is_finished or turn_seconds <= 0.0 or delta <= 0.0 or _timed_out or time_left <= 0.0:
		return
	time_left -= delta
	if time_left > 0.0:
		return
	time_left = 0.0
	_timed_out = true
	var serial := _turn_serial
	turn_timed_out.emit(current_seat)
	if timeout_ends_turn and serial == _turn_serial:
		end_turn()


## From the next round on, the seats play in this order (inactive ones are skipped). Not every seat has to be listed:
## the ones left out do not play those rounds. A seat that does not exist or is listed twice: nothing changes. An
## empty list goes back to the order by seat. While there is an order of your own, `first_seat` and
## `first_seat_rotates` do not apply. Called from `round_ended`, it counts for the round that is about to start.
func set_round_order(order: Array[int]) -> void:
	var seen: Dictionary[int, bool] = {}
	for seat in order:
		if seat < 0 or seat >= seats:
			push_error("TurnCycle: seat %d does not exist" % seat)
			return
		if seen.has(seat):
			push_error("TurnCycle: seat %d is listed twice" % seat)
			return
		seen[seat] = true
	_custom_order = order.duplicate()


## The order of your own set with `set_round_order()` (a copy). Empty: rounds follow the seat order.
func custom_round_order() -> Array[int]:
	return _custom_order.duplicate()


## An inactive seat is skipped (eliminated, disconnected); with none active the match finishes. The current turn
## goes on until `end_turn()`; a seat made active again plays from the next round.
func set_seat_active(seat: int, active: bool) -> void:
	if seat < 0 or seat >= seats:
		push_error("TurnCycle: seat %d does not exist" % seat)
		return
	if active:
		_inactive.erase(seat)
	else:
		_inactive[seat] = true


func is_seat_active(seat: int) -> bool:
	return seat >= 0 and seat < seats and not _inactive.has(seat)


## The seats of the current round in the order they play, inactive ones left out when the round began.
func round_order() -> Array[int]:
	return _order.duplicate()


## Plain data for a save, a network snapshot or a replay check.
func to_dict() -> Dictionary:
	var inactive: Array[int] = []
	inactive.assign(_inactive.keys())
	inactive.sort()
	return {
		"seats": seats,
		"actions_per_turn": actions_per_turn,
		"rounds_per_cycle": rounds_per_cycle,
		"cycles": cycles,
		"first_seat": first_seat,
		"first_seat_rotates": first_seat_rotates,
		"phases": phases.duplicate(),
		"turn_seconds": turn_seconds,
		"timeout_ends_turn": timeout_ends_turn,
		"custom_order": _custom_order.duplicate(),
		"current_seat": current_seat,
		"actions_left": actions_left,
		"turn_phases": _turn_phases.duplicate(),
		"phase_index": phase_index,
		"phase_open": _phase_open,
		"time_left": time_left,
		"timed_out": _timed_out,
		"round_number": round_number,
		"cycle_number": cycle_number,
		"rounds_in_cycle": rounds_in_cycle,
		"round_first_seat": _round_first,
		"is_started": is_started,
		"is_finished": is_finished,
		"inactive": inactive,
		"order": _order.duplicate(),
		"index": _index,
	}


## Rebuilds a cycle from `to_dict()`, in the same turn, phase and time, with the same actions left. No signal is
## emitted. A dict from TurnKit 0.2 (without the phase, time and order keys) works too.
static func from_dict(data: Dictionary) -> TurnCycle:
	var turns := TurnCycle.new(
		int(data.get("seats", 2)),
		int(data.get("actions_per_turn", 1)),
		int(data.get("rounds_per_cycle", 0)),
		int(data.get("cycles", 0))
	)
	turns.first_seat = int(data.get("first_seat", 0))
	turns.first_seat_rotates = bool(data.get("first_seat_rotates", false))
	for phase: Variant in data.get("phases", []):
		turns.phases.append(StringName(phase))
	turns.turn_seconds = float(data.get("turn_seconds", 0.0))
	turns.timeout_ends_turn = bool(data.get("timeout_ends_turn", true))
	for seat: Variant in data.get("custom_order", []):
		turns._custom_order.append(int(seat))
	turns.current_seat = int(data.get("current_seat", -1))
	turns.actions_left = int(data.get("actions_left", 0))
	for phase: Variant in data.get("turn_phases", []):
		turns._turn_phases.append(StringName(phase))
	turns.phase_index = int(data.get("phase_index", -1))
	if turns.phase_index >= 0 and turns.phase_index < turns._turn_phases.size():
		turns.current_phase = turns._turn_phases[turns.phase_index]
	else:
		turns.phase_index = -1
	turns._phase_open = bool(data.get("phase_open", turns.phase_index >= 0))
	turns.time_left = float(data.get("time_left", 0.0))
	turns._timed_out = bool(data.get("timed_out", false))
	turns.round_number = int(data.get("round_number", 0))
	turns.cycle_number = int(data.get("cycle_number", 0))
	turns.rounds_in_cycle = int(data.get("rounds_in_cycle", 0))
	turns.is_started = bool(data.get("is_started", false))
	turns.is_finished = bool(data.get("is_finished", false))
	for seat: Variant in data.get("inactive", []):
		turns._inactive[int(seat)] = true
	for seat: Variant in data.get("order", []):
		turns._order.append(int(seat))
	turns._index = int(data.get("index", 0))
	var opener := -1
	if not turns._order.is_empty():
		opener = turns._order[0]
	turns._round_first = int(data.get("round_first_seat", opener))
	return turns


func _begin_round() -> void:
	_order.clear()
	if _custom_order.is_empty():
		var base := first_seat
		if first_seat_rotates and _round_first >= 0:
			base = _round_first + 1
		for step in maxi(seats, 0):
			var seat := posmod(base + step, seats)
			if not _inactive.has(seat):
				_order.append(seat)
	else:
		for seat in _custom_order:
			if not _inactive.has(seat):
				_order.append(seat)
	_index = 0
	if _order.is_empty():
		_finish()
		return
	_round_first = _order[0]
	_begin_turn(_order[0])


func _begin_turn(seat: int) -> void:
	_turn_serial += 1
	var serial := _turn_serial
	current_seat = seat
	actions_left = actions_per_turn
	_turn_phases = phases.duplicate()
	phase_index = 0 if not _turn_phases.is_empty() else -1
	current_phase = _turn_phases[0] if phase_index == 0 else &""
	time_left = maxf(turn_seconds, 0.0)
	_timed_out = false
	_phase_open = false
	turn_started.emit(seat)
	if serial == _turn_serial and phase_index >= 0 and not _phase_open:
		_phase_open = true
		phase_started.emit(current_phase)


func _close_phase() -> void:
	if _phase_open:
		_phase_open = false
		phase_ended.emit(current_phase)


func _finish() -> void:
	is_finished = true
	current_seat = -1
	actions_left = 0
	time_left = 0.0
	phase_index = -1
	current_phase = &""
	_phase_open = false
	_turn_phases.clear()
	finished.emit()
