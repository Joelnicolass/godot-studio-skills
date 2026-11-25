class_name TurnCycle
extends RefCounted

## Whose turn it is, as plain data: no nodes, no scene. Seats are numbers from 0 to `seats - 1`. Each turn has
## `actions_per_turn` actions; a round is one turn of every active seat, starting at `first_seat`; a cycle is
## `rounds_per_cycle` rounds (an era, a year); the match ends after `cycles` cycles. 0 means no end. A game keeps one in
## its rules; `TurnClock` wraps one for the editor.

## It is `seat`'s turn now.
signal turn_started(seat: int)
## The seat whose turn it is spent actions: `left` are left.
signal action_spent(left: int)
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
var actions_per_turn := 3
## Rounds of a cycle. 0: cycles never end (rounds are still counted).
var rounds_per_cycle := 0
## Cycles of the match. 0: the match never ends.
var cycles := 0
## The seat that opens every round (the next active one if it is out), wrapped into 0 … seats - 1. A change counts
## from the next round.
var first_seat := 0

## The seat whose turn it is (-1 before `start()`).
var current_seat := -1
## Actions the current seat has left.
var actions_left := 0
## The round being played, counted from 1 since the start (0 before `start()`).
var round_number := 0
## The cycle being played, counted from 1 (0 before `start()`).
var cycle_number := 0
## Rounds already over in the current cycle.
var rounds_in_cycle := 0
var is_started := false
var is_finished := false

var _inactive: Dictionary[int, bool] = {}
var _order: Array[int] = []
var _index := 0


func _init(seat_count := 2, actions := 3, rounds := 0, cycle_count := 0) -> void:
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
	_begin_round()


## Spends `amount` actions of the current turn. False, and nothing changes, when there are not that many left or no
## turn is being played. Spending the last action does not end the turn: `end_turn()` does.
func spend_action(amount := 1) -> bool:
	if not is_started or is_finished or amount < 1 or actions_left < amount:
		return false
	actions_left -= amount
	action_spent.emit(actions_left)
	return true


## Ends the current turn, with actions left or not, and starts the next one. Emits `turn_ended`, then `round_ended`,
## `cycle_ended` and `finished` when they apply, then `turn_started` unless the match is over. False when no turn is
## being played.
func end_turn() -> bool:
	if not is_started or is_finished:
		return false
	var seat := current_seat
	actions_left = 0
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
		"current_seat": current_seat,
		"actions_left": actions_left,
		"round_number": round_number,
		"cycle_number": cycle_number,
		"rounds_in_cycle": rounds_in_cycle,
		"is_started": is_started,
		"is_finished": is_finished,
		"inactive": inactive,
		"order": _order.duplicate(),
		"index": _index,
	}


## Rebuilds a cycle from `to_dict()`, in the same turn and with the same actions left. No signal is emitted.
static func from_dict(data: Dictionary) -> TurnCycle:
	var turns := TurnCycle.new(
		int(data.get("seats", 2)),
		int(data.get("actions_per_turn", 3)),
		int(data.get("rounds_per_cycle", 0)),
		int(data.get("cycles", 0))
	)
	turns.first_seat = int(data.get("first_seat", 0))
	turns.current_seat = int(data.get("current_seat", -1))
	turns.actions_left = int(data.get("actions_left", 0))
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
	return turns


func _begin_round() -> void:
	_order.clear()
	for step in maxi(seats, 0):
		var seat := posmod(first_seat + step, seats)
		if not _inactive.has(seat):
			_order.append(seat)
	_index = 0
	if _order.is_empty():
		_finish()
		return
	_begin_turn(_order[0])


func _begin_turn(seat: int) -> void:
	current_seat = seat
	actions_left = actions_per_turn
	turn_started.emit(seat)


func _finish() -> void:
	is_finished = true
	current_seat = -1
	actions_left = 0
	finished.emit()
