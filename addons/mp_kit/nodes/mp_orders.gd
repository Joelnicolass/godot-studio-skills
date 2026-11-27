@icon("res://addons/mp_kit/icons/mp_orders.svg")
class_name MpOrders
extends Node

## The moves of a game whose seats send orders instead of moving a pawn: by turns, cards, a board, an RTS's orders.
## Put one in the world scene (no pawn, no MpActor needed):
## 1. A seat sends a move with `submit(name, args)`: from a client it travels to the server; solo and on the listen
##    host it runs here at once.
## 2. The server asks your game's `judge` (who may, is it legal), numbers the moves it takes and sends them to every
##    peer in order: `applied(seq, slot, name, args)`, the server too. A move it refuses goes back to its seat only:
##    `rejected(name, args, reason)`.
## 3. It keeps every move since `begin(start)` and sends them to a peer that loads the world late or comes back:
##    that peer gets `began(start)` and every `applied` again (`is_replaying()`), so it rebuilds the match, and
##    `caught_up(seq)` when it has them all.
## With `state_hash`, each move carries the server's hash after it; a peer whose own differs gets `desynced(seq)`.
## Its messages go through the custom tunnel on `channel` (add it to custom_channels if your game lists them).

## The match starts from scratch with `start` (your seed, the seats' choices): a new match, or a peer that loaded
## late, came back or asked for `resync()` and is about to get every move again.
signal began(start: Dictionary)
## A move the server took, in order (seq 1, 2, 3…), on every peer and on the server: apply it to your game.
signal applied(seq: int, slot: int, name: StringName, args: Array)
## Only on the machine of the seat that sent it: the server refused it, with your judge's reason. Or the move never
## reached your judge: MpKit.CUSTOM_RATE_LIMITED (more moves a second than MpKit.custom_limit), CUSTOM_TOO_BIG or
## CUSTOM_NO_SEAT. A submit always ends in `applied` or `rejected`.
signal rejected(name: StringName, args: Array, reason: String)
## This peer's `state_hash` differs from the server's after move `seq`. `resync()` gets every move again.
signal desynced(seq: int)
## A client has every move the server had for it: after it loaded (late or not), came back or asked for `resync()`,
## the history is applied (`seq` is `last_seq()`, 0 with no move yet) and `is_replaying()` is false again. The server
## and solo never wait for one.
signal caught_up(seq: int)

const GROUP := &"mp_orders"
## Moves per history message to a peer that loads late (each message stays well under the relay's 256 KB).
const HISTORY_CHUNK := 200

## Its channel in the custom tunnel. Two MpOrders in one world need two channels.
@export var channel := &"mp_orders"

## Server: `(slot: int, name: StringName, args: Array) -> String`, your game's rules: "" takes the move, any other
## text refuses it and is the reason its seat gets. Empty: every move is taken.
var judge: Callable = Callable()
## `() -> int`, a hash of your game's state (the same rules give the same number on every peer). The server sends it
## with each move and every peer compares its own after applying it (`desynced`). Empty: no check.
var state_hash: Callable = Callable()

var _start: Dictionary = {}
## [slot, name, args, hash] per move; move `seq` is at seq - 1.
var _moves: Array = []
var _replaying := false
var _desynced_at := 0


## The MpOrders of the current scene (the one on `on_channel`, if there are several), or null.
static func of(from: Node, on_channel: StringName = &"") -> MpOrders:
	if from == null or not from.is_inside_tree():
		return null
	for node in from.get_tree().get_nodes_in_group(GROUP):
		if on_channel == &"" or (node as MpOrders).channel == on_channel:
			return node as MpOrders
	return null


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	MpKit.custom_received.connect(_on_custom)
	MpKit.custom_refused.connect(_on_refused)
	MpKit.client_world_ready.connect(_on_world_ready)


func _exit_tree() -> void:
	if MpKit.custom_received.is_connected(_on_custom):
		MpKit.custom_received.disconnect(_on_custom)
	if MpKit.custom_refused.is_connected(_on_refused):
		MpKit.custom_refused.disconnect(_on_refused)
	if MpKit.client_world_ready.is_connected(_on_world_ready):
		MpKit.client_world_ready.disconnect(_on_world_ready)


## Sends this machine's seat's move. A dedicated server has no seat: it moves for a seat with `submit_as`.
func submit(move_name: StringName, args: Array = []) -> void:
	if MpKit.is_dedicated():
		push_error("MpOrders.submit: a dedicated server has no seat; use submit_as(slot, name, args).")
		return
	MpKit.send_custom(channel, {"k": "submit", "n": String(move_name), "a": args})


## Server: a move for `slot` (a bot, a timer that ends a turn), judged like any other.
func submit_as(slot: int, move_name: StringName, args: Array = []) -> void:
	if not MpKit.is_authority():
		push_error("MpOrders.submit_as: only the server moves for a seat.")
		return
	_take(slot, move_name, args, 0)


## Server: a new match from scratch with `start` (a seed, the seats' choices): every peer gets `began(start)` and
## the moves start again at 1.
func begin(start: Dictionary = {}) -> void:
	if not MpKit.is_authority():
		push_error("MpOrders.begin: only the server starts a match.")
		return
	_start = start.duplicate(true)
	_moves.clear()
	_desynced_at = 0
	began.emit(_start.duplicate(true))
	if MpKit.is_server():
		MpKit.broadcast_custom(channel, {"k": "begin", "start": _start}, true)


## Client: asks the server for every move again (after `desynced`). It comes as `began` and every `applied`.
func resync() -> void:
	if MpKit.is_authority():
		return
	MpKit.send_custom(channel, {"k": "want"})


## While a peer gets the moves again (it loaded late, came back or resynced): skip sounds and animations.
func is_replaying() -> bool:
	return _replaying


## The last move applied here (0: none since `begin`).
func last_seq() -> int:
	return _moves.size()


## What the match started from (`begin`).
func start() -> Dictionary:
	return _start.duplicate(true)


## Every move applied here since `begin`, oldest first: {slot, name, args}. To save the match, or replay it.
func moves() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for move: Array in _moves:
		out.append({"slot": move[0], "name": StringName(move[1]), "args": (move[2] as Array).duplicate(true)})
	return out


func _on_custom(on_channel: StringName, data: Dictionary, from_peer: int) -> void:
	if on_channel != channel:
		return
	var kind := str(data.get("k", ""))
	if MpKit.is_authority():
		match kind:
			"submit":
				var move_name: Variant = data.get("n")
				var args: Variant = data.get("a")
				if (
					not (move_name is String or move_name is StringName)
					or str(move_name).is_empty()
					or not args is Array
				):
					return
				_take(MpKit.slot_of_sender(from_peer), StringName(move_name), args, from_peer)
			"want":
				if from_peer != 1:
					_send_history(from_peer)
		return
	_from_server(data)


## A client: what the server sends.
func _from_server(data: Dictionary) -> void:
	match str(data.get("k", "")):
		"begin":
			_start_over(data.get("start", {}) as Dictionary)
		"applied":
			_receive(data)
		"rejected":
			rejected.emit(StringName(str(data.get("n", ""))), data.get("a", []) as Array, str(data.get("r", "")))
		"history":
			_replaying = true
			if int(data.get("from", 1)) == 1:
				_start_over(data.get("start", {}) as Dictionary)
			for row: Variant in data.get("o", []) as Array:
				var move := row as Array
				if move != null and move.size() == 5:
					_apply(int(move[0]), int(move[1]), StringName(str(move[2])), move[3] as Array, move[4])
			_replaying = not bool(data.get("last", true))
			if not _replaying:
				caught_up.emit(_moves.size())


## A message of this channel the tunnel did not take: a move comes back as `rejected`, a resync asks again.
func _on_refused(on_channel: StringName, data: Dictionary, reason: String) -> void:
	if on_channel != channel:
		return
	match str(data.get("k", "")):
		"submit":
			rejected.emit(StringName(str(data.get("n", ""))), data.get("a", []) as Array, reason)
		"want":
			if reason == MpKit.CUSTOM_RATE_LIMITED:
				MpKit.after_real(0.5, resync)


## Server: judges a move and, taken, applies it here and sends it to every peer with the world loaded.
func _take(slot: int, move_name: StringName, args: Array, from_peer: int) -> void:
	if slot <= 0:
		return
	var reason := ""
	if judge.is_valid():
		reason = str(judge.call(slot, move_name, args))
	if not reason.is_empty():
		var local := from_peer == 0 or from_peer == 1 or not MpKit.is_server()
		if local:
			rejected.emit(move_name, args, reason)
		else:
			MpKit.push_custom_to(from_peer, channel, {"k": "rejected", "n": String(move_name), "a": args, "r": reason})
		return
	var seq := _moves.size() + 1
	_moves.append([slot, String(move_name), args.duplicate(true), null])
	applied.emit(seq, slot, move_name, args.duplicate(true))
	var hash_value: Variant = int(state_hash.call()) if state_hash.is_valid() else null
	_moves[seq - 1][3] = hash_value
	if MpKit.is_server():
		var message := {"k": "applied", "s": seq, "p": slot, "n": String(move_name), "a": args, "h": hash_value}
		MpKit.broadcast_custom(channel, message, true)


func _start_over(start: Dictionary) -> void:
	_start = start.duplicate(true)
	_moves.clear()
	_desynced_at = 0
	began.emit(_start.duplicate(true))


func _receive(data: Dictionary) -> void:
	var seq := int(data.get("s", 0))
	if seq <= _moves.size():
		return  # already here (it came with the history)
	if seq > _moves.size() + 1:
		resync()  # a move went missing: get them all again
		return
	_apply(seq, int(data.get("p", 0)), StringName(str(data.get("n", ""))), data.get("a", []) as Array, data.get("h"))


func _apply(seq: int, slot: int, move_name: StringName, args: Array, hash_value: Variant) -> void:
	if seq != _moves.size() + 1:
		return
	_moves.append([slot, String(move_name), args.duplicate(true), hash_value])
	applied.emit(seq, slot, move_name, args.duplicate(true))
	if hash_value != null and state_hash.is_valid() and int(state_hash.call()) != int(hash_value):
		if _desynced_at == 0:
			_desynced_at = seq
			desynced.emit(seq)


func _on_world_ready(peer_id: int) -> void:
	if MpKit.is_server():
		_send_history(peer_id)


## Server: every move since `begin` to one peer, in chunks; the first one carries `start`.
func _send_history(peer_id: int) -> void:
	var rows: Array = []
	for i in _moves.size():
		var move: Array = _moves[i]
		rows.append([i + 1, move[0], move[1], move[2], move[3]])
	var first := 0
	while true:
		var chunk := rows.slice(first, first + HISTORY_CHUNK)
		var last := first + HISTORY_CHUNK >= rows.size()
		var message := {"k": "history", "from": first + 1, "o": chunk, "last": last}
		if first == 0:
			message["start"] = _start
		MpKit.push_custom_to(peer_id, channel, message)
		if last:
			break
		first += HISTORY_CHUNK
