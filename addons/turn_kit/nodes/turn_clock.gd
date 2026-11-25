@tool
class_name TurnClock
extends Node

## Turns in the scene tree. Its `TurnSeat` children are the players, in order; the inspector sets the actions of a
## turn, the phases, the time, the rounds of a cycle and the cycles of the match. It owns a `TurnCycle` built from
## those values, or shows one your game's rules already keep (`use_cycle`). Every call goes to the cycle:
## `spend_action`, `next_phase`, `end_turn`.

## It is `seat`'s turn now.
signal turn_started(seat: int)
## The turn moved to the phase `phase` (the first one at the start of every turn).
signal phase_started(phase: StringName)
## The phase `phase` is over.
signal phase_ended(phase: StringName)
## The seat whose turn it is spent actions: `left` are left.
signal action_spent(left: int)
## `seat`'s time ran out. Once per turn.
signal turn_timed_out(seat: int)
## `seat`'s turn is over.
signal turn_ended(seat: int)
## Round `n` (counted from 1) is over.
signal round_ended(n: int)
## Cycle `n` (counted from 1) is over.
signal cycle_ended(n: int)
## The last cycle is over.
signal finished
## The clock shows another cycle now (`use_cycle`, `use_own_cycle`, or its own built again): read its state again.
signal rebuilt

@export_group("Turn")
## Actions of each turn.
@export_range(1, 99) var actions_per_turn := 1:
	set(value):
		actions_per_turn = value
		if _own and _cycle != null:
			_cycle.actions_per_turn = value
		update_configuration_warnings()
## On: the clock's own cycle starts by itself once the scene is ready. A cycle shown with `use_cycle` is never
## started for you: your rules start it (or it comes already started from a save).
@export var autostart := true

@export_group("Round")
## Rounds of a cycle (an era, a year). 0: cycles never end.
@export_range(0, 999) var rounds_per_cycle := 0:
	set(value):
		rounds_per_cycle = value
		if _own and _cycle != null:
			_cycle.rounds_per_cycle = value
## Cycles of the match. 0: the match never ends.
@export_range(0, 999) var cycles := 0:
	set(value):
		cycles = value
		if _own and _cycle != null:
			_cycle.cycles = value
## The seat that opens the first round (every round, unless `first_seat_rotates`).
@export_range(0, 64) var first_seat := 0:
	set(value):
		first_seat = value
		if _own and _cycle != null:
			_cycle.first_seat = value
## On: every round is opened by the seat after the one that opened the last round.
@export var first_seat_rotates := false:
	set(value):
		first_seat_rotates = value
		if _own and _cycle != null:
			_cycle.first_seat_rotates = value

@export_group("Phases")
## The phases of a turn, in order (draw, play, discard). Empty: a turn has no phases.
@export var phases: Array[StringName] = []:
	set(value):
		phases = value
		if _own and _cycle != null:
			_cycle.phases = value.duplicate()
		update_configuration_warnings()

@export_group("Time")
## Seconds of a turn. 0: no time limit.
@export_range(0.0, 3600.0, 0.1, "or_greater", "suffix:s") var turn_seconds := 0.0:
	set(value):
		turn_seconds = value
		if _own and _cycle != null:
			_cycle.turn_seconds = value
## On: when the time runs out the turn ends by itself. Off: only `turn_timed_out` is emitted.
@export var timeout_ends_turn := true:
	set(value):
		timeout_ends_turn = value
		if _own and _cycle != null:
			_cycle.timeout_ends_turn = value
## On: this clock advances the turn time every frame. Off: your rules, or the server, call `tick()`.
@export var advance_time := true:
	set(value):
		advance_time = value
		_update_process()

## The cycle this clock shows.
var turn_cycle: TurnCycle:
	get:
		if _cycle == null:
			_rebuild_own()
		return _cycle
## The seat whose turn it is (-1 before the start and after the end).
var current_seat: int:
	get:
		return turn_cycle.current_seat
## Actions the current seat has left.
var actions_left: int:
	get:
		return turn_cycle.actions_left
## The phase being played (`&""` without phases or without a turn).
var current_phase: StringName:
	get:
		return turn_cycle.current_phase
## Seconds the current turn has left.
var time_left: float:
	get:
		return turn_cycle.time_left

var _cycle: TurnCycle
var _own := true


func _ready() -> void:
	_update_process()
	if not Engine.is_editor_hint() and autostart:
		_autostart.call_deferred()


func _process(delta: float) -> void:
	if advance_time and not Engine.is_editor_hint():
		turn_cycle.tick(delta)


## Starts the first turn of the clock's own cycle: the seats are counted again first, so seats added before this
## count, and each `TurnSeat.active` applies. A cycle shown with `use_cycle` belongs to your rules: `start()` starts it
## only if it has not started yet, and leaves its seats as they are.
func start() -> void:
	if not _own:
		if not turn_cycle.is_started:
			turn_cycle.start()
		return
	_rebuild_own()
	for seat in seat_nodes():
		turn_cycle.set_seat_active(seat.index(), seat.active)
	turn_cycle.start()


func _autostart() -> void:
	if _own and not turn_cycle.is_started:
		start()


func spend_action(amount := 1) -> bool:
	return turn_cycle.spend_action(amount)


## Moves to the next phase; in the last one (or without phases) it ends the turn.
func next_phase() -> bool:
	return turn_cycle.next_phase()


func end_turn() -> bool:
	return turn_cycle.end_turn()


## Lets `delta` seconds pass in the current turn. Call it yourself when `advance_time` is off.
func tick(delta: float) -> void:
	turn_cycle.tick(delta)


## From the next round on, the seats play in this order (see `TurnCycle.set_round_order`).
func set_round_order(order: Array[int]) -> void:
	turn_cycle.set_round_order(order)


func set_seat_active(seat: int, active: bool) -> void:
	turn_cycle.set_seat_active(seat, active)


## True while the clock shows its own cycle (not one from `use_cycle`).
func owns_cycle() -> bool:
	return _own


## Shows `other` instead of the clock's own cycle (your game's rules keep it). It is never restarted: a cycle from a
## save keeps its turn. The inspector values and `TurnSeat.active` no longer apply until `use_own_cycle()`. Its seats
## should match the `TurnSeat` children. Emits `rebuilt`.
func use_cycle(other: TurnCycle) -> void:
	_own = false
	_set_cycle(other)
	if other.seats != seat_nodes().size():
		push_warning("TurnClock: the cycle has %d seats and the clock %d TurnSeat" % [other.seats, seat_nodes().size()])


## Goes back to a cycle built from the inspector values (not started). Emits `rebuilt`.
func use_own_cycle() -> void:
	_own = true
	_rebuild_own()


## The `TurnSeat` children, in seat order.
func seat_nodes() -> Array[TurnSeat]:
	var list: Array[TurnSeat] = []
	for child in get_children():
		if child is TurnSeat:
			list.append(child)
	return list


## The `TurnSeat` of `seat`, or null.
func seat_node(seat: int) -> TurnSeat:
	var list := seat_nodes()
	return list[seat] if seat >= 0 and seat < list.size() else null


## The `TurnSeat` whose turn it is, or null.
func current_seat_node() -> TurnSeat:
	return seat_node(current_seat)


func _rebuild_own() -> void:
	if not _own:
		return
	var next := TurnCycle.new(maxi(seat_nodes().size(), 1), actions_per_turn, rounds_per_cycle, cycles)
	next.first_seat = first_seat
	next.first_seat_rotates = first_seat_rotates
	next.phases = phases.duplicate()
	next.turn_seconds = turn_seconds
	next.timeout_ends_turn = timeout_ends_turn
	_set_cycle(next)


func _update_process() -> void:
	set_process(advance_time and not Engine.is_editor_hint())


func _set_cycle(next: TurnCycle) -> void:
	if _cycle != null:
		_cycle.turn_started.disconnect(_on_turn_started)
		_cycle.phase_started.disconnect(_on_phase_started)
		_cycle.phase_ended.disconnect(_on_phase_ended)
		_cycle.turn_timed_out.disconnect(_on_turn_timed_out)
		_cycle.action_spent.disconnect(_on_action_spent)
		_cycle.turn_ended.disconnect(_on_turn_ended)
		_cycle.round_ended.disconnect(_on_round_ended)
		_cycle.cycle_ended.disconnect(_on_cycle_ended)
		_cycle.finished.disconnect(_on_finished)
	_cycle = next
	_cycle.turn_started.connect(_on_turn_started)
	_cycle.phase_started.connect(_on_phase_started)
	_cycle.phase_ended.connect(_on_phase_ended)
	_cycle.turn_timed_out.connect(_on_turn_timed_out)
	_cycle.action_spent.connect(_on_action_spent)
	_cycle.turn_ended.connect(_on_turn_ended)
	_cycle.round_ended.connect(_on_round_ended)
	_cycle.cycle_ended.connect(_on_cycle_ended)
	_cycle.finished.connect(_on_finished)
	rebuilt.emit()


func _on_turn_started(seat: int) -> void:
	turn_started.emit(seat)
	var node := seat_node(seat)
	if node != null:
		node.turn_started.emit()


func _on_phase_started(phase: StringName) -> void:
	phase_started.emit(phase)


func _on_phase_ended(phase: StringName) -> void:
	phase_ended.emit(phase)


func _on_turn_timed_out(seat: int) -> void:
	turn_timed_out.emit(seat)


func _on_action_spent(left: int) -> void:
	action_spent.emit(left)


func _on_turn_ended(seat: int) -> void:
	turn_ended.emit(seat)
	var node := seat_node(seat)
	if node != null:
		node.turn_ended.emit()


func _on_round_ended(n: int) -> void:
	round_ended.emit(n)


func _on_cycle_ended(n: int) -> void:
	cycle_ended.emit(n)


func _on_finished() -> void:
	finished.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_CHILD_ORDER_CHANGED and Engine.is_editor_hint():
		update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if seat_nodes().is_empty():
		warnings.append("No players: add a TurnSeat child per seat.")
	if first_seat >= maxi(seat_nodes().size(), 1):
		warnings.append("first_seat is past the last TurnSeat.")
	var seen: Dictionary[StringName, bool] = {}
	for phase in phases:
		if seen.has(phase):
			if phase == &"":
				warnings.append("phases has two empty names: give every phase a name.")
			else:
				warnings.append("phases lists '%s' twice: every phase needs its own name." % phase)
		elif phase == &"":
			warnings.append("phases has an empty name: give every phase a name.")
		seen[phase] = true
	return warnings
