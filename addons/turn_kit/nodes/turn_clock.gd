@tool
class_name TurnClock
extends Node

## Turns in the scene tree. Its `TurnSeat` children are the players, in order; the inspector sets the actions of a
## turn, the rounds of a cycle and the cycles of the match. It owns a `TurnCycle` built from those values, or shows
## one your game's rules already keep (`use_cycle`). Every call goes to the cycle: `spend_action`, `end_turn`.

## It is `seat`'s turn now.
signal turn_started(seat: int)
## The seat whose turn it is spent actions: `left` are left.
signal action_spent(left: int)
## `seat`'s turn is over.
signal turn_ended(seat: int)
## Round `n` (counted from 1) is over.
signal round_ended(n: int)
## Cycle `n` (counted from 1) is over.
signal cycle_ended(n: int)
## The last cycle is over.
signal finished

## Actions of each turn.
@export_range(1, 99) var actions_per_turn := 3:
	set(value):
		actions_per_turn = value
		if _own and _cycle != null:
			_cycle.actions_per_turn = value
		update_configuration_warnings()
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
## The seat that opens every round.
@export_range(0, 64) var first_seat := 0:
	set(value):
		first_seat = value
		if _own and _cycle != null:
			_cycle.first_seat = value
## On: the first turn starts by itself once the scene is ready. Off: call `start()`.
@export var autostart := true

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

var _cycle: TurnCycle
var _own := true


func _ready() -> void:
	if not Engine.is_editor_hint() and autostart:
		start.call_deferred()


## Starts the first turn. With its own cycle the seats are counted again first, so seats added before this count.
func start() -> void:
	if _own:
		_rebuild_own()
	for seat in seat_nodes():
		turn_cycle.set_seat_active(seat.index(), seat.active)
	turn_cycle.start()


func spend_action(amount := 1) -> bool:
	return turn_cycle.spend_action(amount)


func end_turn() -> bool:
	return turn_cycle.end_turn()


func set_seat_active(seat: int, active: bool) -> void:
	turn_cycle.set_seat_active(seat, active)


## Shows `other` instead of the clock's own cycle (your game's rules keep it). The inspector values no longer apply
## until `use_own_cycle()`. Its seats should match the `TurnSeat` children.
func use_cycle(other: TurnCycle) -> void:
	_own = false
	_set_cycle(other)
	if other.seats != seat_nodes().size():
		push_warning("TurnClock: the cycle has %d seats and the clock %d TurnSeat" % [other.seats, seat_nodes().size()])


## Goes back to a cycle built from the inspector values (not started).
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
	_set_cycle(next)


func _set_cycle(next: TurnCycle) -> void:
	if _cycle != null:
		_cycle.turn_started.disconnect(_on_turn_started)
		_cycle.action_spent.disconnect(_on_action_spent)
		_cycle.turn_ended.disconnect(_on_turn_ended)
		_cycle.round_ended.disconnect(_on_round_ended)
		_cycle.cycle_ended.disconnect(_on_cycle_ended)
		_cycle.finished.disconnect(_on_finished)
	_cycle = next
	_cycle.turn_started.connect(_on_turn_started)
	_cycle.action_spent.connect(_on_action_spent)
	_cycle.turn_ended.connect(_on_turn_ended)
	_cycle.round_ended.connect(_on_round_ended)
	_cycle.cycle_ended.connect(_on_cycle_ended)
	_cycle.finished.connect(_on_finished)


func _on_turn_started(seat: int) -> void:
	turn_started.emit(seat)
	var node := seat_node(seat)
	if node != null:
		node.turn_started.emit()


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
	return warnings
