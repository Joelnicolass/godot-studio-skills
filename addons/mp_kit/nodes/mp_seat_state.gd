@icon("res://addons/mp_kit/icons/mp_seat_state.svg")
class_name MpSeatState
extends Node

## Values that only one seat sees, next to MpState's public ones: its hand of cards, its ammo, its secret goal. Put
## one in the world. The server writes them per seat (`set_value(slot, key, value)`); only that seat's machine gets
## them, as `changed(key, value)` or `watch(key, callback)`, and again when it loads late or comes back. They belong to
## the seat, not to the player: whoever takes the seat later (a late player, a bot) finds them there.
## Solo it is a Dictionary per seat. They travel through the custom tunnel on `channel` (add it to custom_channels if
## your game lists them). Not: what every player sees (MpState), one-off effects (MpActor.to_all).

## A value of this machine's seat changed (null: it was removed).
signal changed(key: StringName, value: Variant)

const GROUP := &"mp_seat_state"

## Its channel in the custom tunnel. Two MpSeatState in one world need two channels.
@export var channel := &"mp_seat_state"

## Server and solo: every seat's values (slot -> {key: value}). A client: only its own seat's, under its slot.
var _seats: Dictionary[int, Dictionary] = {}


## The MpSeatState of the current scene, or null.
static func of(from: Node) -> MpSeatState:
	if from == null or not from.is_inside_tree():
		return null
	return from.get_tree().get_first_node_in_group(GROUP) as MpSeatState


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	MpKit.custom_received.connect(_on_custom)
	MpKit.client_world_ready.connect(_on_world_ready)


func _exit_tree() -> void:
	if MpKit.custom_received.is_connected(_on_custom):
		MpKit.custom_received.disconnect(_on_custom)
	if MpKit.client_world_ready.is_connected(_on_world_ready):
		MpKit.client_world_ready.disconnect(_on_world_ready)


## Server (or solo): sets a value of `slot`. Only that seat's machine gets it. null removes it.
func set_value(slot: int, key: StringName, value: Variant) -> void:
	if not MpKit.is_authority():
		push_warning("MpSeatState '%s': set_value(%d, %s) only runs on the server" % [name, slot, key])
		return
	if slot <= 0:
		return
	var seat: Dictionary = _seats.get(slot, {})
	if value == null:
		if not seat.has(key):
			return
		seat.erase(key)
	elif seat.has(key) and seat[key] == value:
		return
	else:
		seat[key] = value
	_seats[slot] = seat
	if slot == MpKit.local_slot():
		changed.emit(key, value)
	elif MpKit.is_server():
		var peer_id := MpKit.peer_id_for(slot)
		if peer_id != 0 and MpKit.is_peer_world_ready(peer_id):
			MpKit.push_custom_to(peer_id, channel, {"k": "set", "key": String(key), "value": value})


## Server (or solo): adds `amount` to a number of `slot` (missing = 0).
func add(slot: int, key: StringName, amount: float = 1) -> void:
	var now: Variant = value_of(slot, key, 0)
	if typeof(now) == TYPE_INT and amount == int(amount):
		set_value(slot, key, int(now) + int(amount))
	else:
		set_value(slot, key, float(now) + amount)


## Server (or solo): removes every value of `slot` (a new match, a seat your game resets).
func clear_seat(slot: int) -> void:
	if not MpKit.is_authority():
		return
	for key: StringName in (_seats.get(slot, {}) as Dictionary).keys():
		set_value(slot, key, null)


## A value of this machine's seat.
func get_value(key: StringName, default: Variant = null) -> Variant:
	return value_of(MpKit.local_slot(), key, default)


## A value of `slot`: any seat on the server (and solo), only its own seat on a client (`default` for the others).
func value_of(slot: int, key: StringName, default: Variant = null) -> Variant:
	return (_seats.get(slot, {}) as Dictionary).get(key, default)


## Every value of this machine's seat (a copy).
func values() -> Dictionary:
	return (_seats.get(MpKit.local_slot(), {}) as Dictionary).duplicate(true)


## Calls `on_value(value)` now with this seat's value of `key` (`default` while it has none), then on every change of
## that key. Whoever loads late or comes back gets the value first. Returns a handle for unwatch().
func watch(key: StringName, on_value: Callable, default: Variant = null) -> Callable:
	var relay := func(changed_key: StringName, value: Variant) -> void:
		if changed_key == key and on_value.is_valid():
			on_value.call(default if value == null else value)
	changed.connect(relay)
	on_value.call(get_value(key, default))
	return relay


## Stops a watch (the handle watch() returned).
func unwatch(handle: Callable) -> void:
	if changed.is_connected(handle):
		changed.disconnect(handle)


func _on_custom(on_channel: StringName, data: Dictionary, _from_peer: int) -> void:
	if on_channel != channel or MpKit.is_authority():
		return
	var mine := MpKit.local_slot()
	match str(data.get("k", "")):
		"set":
			var key := StringName(str(data.get("key", "")))
			var seat: Dictionary = _seats.get(mine, {})
			var value: Variant = data.get("value")
			if value == null:
				seat.erase(key)
			else:
				seat[key] = value
			_seats[mine] = seat
			changed.emit(key, value)
		"all":
			var before: Dictionary = _seats.get(mine, {})
			var now := {}
			for key: Variant in data.get("values", {}) as Dictionary:
				now[StringName(str(key))] = (data["values"] as Dictionary)[key]
			_seats.clear()
			_seats[mine] = now
			for key: StringName in before:
				if not now.has(key):
					changed.emit(key, null)
			for key: StringName in now:
				changed.emit(key, now[key])


## Server: a peer's world loaded (it joined late, or came back): every value of its seat.
func _on_world_ready(peer_id: int) -> void:
	if not MpKit.is_server():
		return
	var slot := MpKit.slot_for_peer(peer_id)
	if slot <= 0:
		return
	var seat: Dictionary = _seats.get(slot, {})
	var out := {}
	for key: Variant in seat:
		out[String(key)] = seat[key]
	MpKit.push_custom_to(peer_id, channel, {"k": "all", "values": out})
