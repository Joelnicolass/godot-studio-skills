class_name MpMatchAgent
extends Node

## Dedicated-match side of the launcher. Reads `--match-ticket-file`, names the seats of the token hashes (seat_of) and arms the
## match's start gate with them (MpKit.gate: the wait for every seat, the rejoin grace, how it starts, late join), writes
## state.json as a heartbeat (with whether the match started and the seats nobody may take any more), writes result.json when
## the match ends, and quits when nobody is left or the room server (`--room-pid`) is gone. After the result it quits
## result_quit_delay_s later or, with stay_after_finish_s, once its players left (they read the game's end screen).
## The glue starts the dedicated host (MpKit.host_dedicated) and calls `report_result()`. Not: the grace or the wait (the gate).
## The agent never sees the plain token: it compares sha256(presented) with the ticket.
## Rows of the ticket without `token_sha256` (bot seats) are ignored: they are never admitted.

signal ticket_loaded(ticket: Dictionary)
signal result_reported(data: Dictionary)

@export var config: MpLobbyConfig
## Start by itself in _ready when `--match-ticket-file` is present.
@export var auto_start: bool = true

const GROUP := &"mp_match_agent"
## Result reason when the relay refused this match's port (another live host): the launcher retries another port.
const PORT_IN_USE := "port_in_use"

var ticket: Dictionary = {}
var match_id: String = ""
var finished: bool = false

var _root: String = ""
var _room_pid: int = 0
var _started_ms: int = 0
var _hb_accum: float = 0.0
var _parent_accum: float = 0.0
var _empty_since_ms: int = 0
var _ever_joined: bool = false
## slot -> {sha, meta, used: bool, peer: int}
var _seats: Dictionary = {}
## After the result, while the match stays up for its players (stay_after_finish_s): since when.
var _staying: bool = false
var _finished_ms: int = 0


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	## Infrastructure: it keeps the heartbeat and the state going while the match is paused (MpMatch waits for seats).
	process_mode = Node.PROCESS_MODE_ALWAYS
	if config == null:
		config = MpLobbyConfig.new()
	config = config.with_cli_overrides()
	if auto_start and not MpBoot.user_value("match-ticket-file", "").is_empty():
		start()


## Loads the ticket and arms the admission. Returns false if the ticket is unusable.
func start(ticket_path: String = "") -> bool:
	if ticket_path.is_empty():
		ticket_path = MpBoot.user_value("match-ticket-file", "")
	ticket = MpMatchFiles.read_json(ticket_path)
	match_id = str(ticket.get("match_id", ""))
	if not MpMatchFiles.is_valid_id(match_id) or ticket.get("seats", []).is_empty():
		push_error("MpMatchAgent: unusable ticket %s" % ticket_path)
		get_tree().quit(1)
		return false
	_root = ticket_path.get_base_dir().get_base_dir()
	_room_pid = int(MpBoot.user_value("room-pid", str(ticket.get("room_pid", 0))))
	_started_ms = MpMatchFiles.now_ms()
	for seat in ticket["seats"]:
		var row: Dictionary = seat
		## A row without a token hash (a bot seat) is never admitted.
		if str(row.get("token_sha256", "")).is_empty():
			continue
		_seats[int(row["slot"])] = {
			"sha": str(row["token_sha256"]), "meta": row.get("meta", {}),
			"used": false, "peer": 0,
		}
	## Until the gate is armed (the first frame at the latest), the same identity guards the door.
	MpKit.admission = seat_of
	MpKit.peer_joined.connect(_on_peer_joined)
	MpKit.peer_left.connect(_on_peer_left)
	set_process(true)
	_write_state()
	ticket_loaded.emit(ticket)
	return true


func seat_meta(slot: int) -> Dictionary:
	return _seats.get(slot, {}).get("meta", {})


func connected_slots() -> Array[int]:
	var out: Array[int] = []
	for slot in _seats.keys():
		if int(_seats[slot]["peer"]) != 0:
			out.append(int(slot))
	return out


## Writes result.json, tells the clients and quits after `result_quit_delay_s`, or with `stay_after_finish_s` once its players
## left (never before result_quit_delay_s, never after stay_after_finish_s). Only the first call counts.
func report_result(data: Dictionary) -> void:
	if finished:
		return
	finished = true
	var out := data.duplicate(true)
	out["match_id"] = match_id
	if not out.has("reason"):
		out["reason"] = "result"
	out["ended_ms"] = MpMatchFiles.now_ms()
	MpMatchFiles.write_json(MpMatchFiles.path_of(_root, match_id, MpMatchFiles.RESULT), out)
	_write_state()
	MpKit.broadcast_session_ended(out)
	result_reported.emit(out)
	var at_once: bool = out["reason"] == "room_gone" or out["reason"] == PORT_IN_USE
	var delay := 0.0 if at_once else config.result_quit_delay_s
	if not at_once and config.stay_after_finish_s > 0.0:
		## It stays while its players read the result: _process quits once they left.
		_staying = true
		_finished_ms = MpMatchFiles.now_ms()
	elif delay <= 0.0:
		get_tree().quit()
	else:
		## Real time: the result must reach the room server and the players before the process goes.
		MpKit.after_real(delay, func() -> void: get_tree().quit())


## Arms MpKit.gate with the ticket's human seats: identity = seat_of, and from `config` the grace, the load timeout, whether it
## starts by itself (start_on_timeout), who may start it (starter_slot) and late join. `--no-load-hold` (tests whose clients
## never load the world) runs at once. Idempotent; MpFlow calls it right after hosting.
func arm_gate() -> void:
	if ticket.is_empty() or finished or not MpKit.is_server() or MpKit.gate.is_armed():
		return
	var gate := MpKit.gate
	gate.rejoin_grace_s = config.rejoin_grace_s
	gate.load_timeout_s = config.load_timeout_s
	gate.start_on_timeout = config.start_on_timeout
	gate.starter_slot = config.starter_slot
	gate.late_join = config.late_join
	gate.pause_while_waiting = config.pause_while_waiting
	gate.host_present = false
	## state.json follows the start and the seats that close, free or are held (an issuer room lists only what may still be
	## taken, and gives a held seat to its own player only).
	for changed: Signal in [gate.started, gate.seat_abandoned, gate.joined_late, gate.seat_admitted, gate.seat_closed]:
		if not changed.is_connected(_on_gate_changed):
			changed.connect(_on_gate_changed)
	var slots: Array[int] = []
	for slot in _seats.keys():
		slots.append(int(slot))
	gate.arm(slots, 0, seat_of, not MpBoot.user_flag("no-load-hold"))


func _process(delta: float) -> void:
	if ticket.is_empty():
		return
	if finished:
		_stay_after_finish(delta)
		return
	arm_gate()
	## Through the relay this port's room has another live host: say so, the launcher tries another port.
	if MpKit.listen_refused():
		report_result({"reason": PORT_IN_USE})
		return
	_hb_accum += delta
	if _hb_accum >= config.heartbeat_s:
		_hb_accum = 0.0
		_write_state()
	_parent_accum += delta
	if _parent_accum >= config.parent_check_s:
		_parent_accum = 0.0
		if _room_pid > 0 and not MpProcessRunner.pid_alive(_room_pid):
			report_result({"reason": "room_gone"})
			return
	_check_idle()


## A finished match that stays (stay_after_finish_s): the heartbeat goes on, and it quits once nobody is in (after
## result_quit_delay_s, so the result reached everybody), once stay_after_finish_s passed, or when the room server is gone.
func _stay_after_finish(delta: float) -> void:
	if not _staying:
		return
	_hb_accum += delta
	if _hb_accum >= config.heartbeat_s:
		_hb_accum = 0.0
		_write_state()
	var room_gone := false
	_parent_accum += delta
	if _parent_accum >= config.parent_check_s:
		_parent_accum = 0.0
		room_gone = _room_pid > 0 and not MpProcessRunner.pid_alive(_room_pid)
	var since_s := float(MpMatchFiles.now_ms() - _finished_ms) / 1000.0
	var nobody := since_s >= config.result_quit_delay_s and connected_slots().is_empty()
	if room_gone or nobody or since_s >= maxf(config.stay_after_finish_s, config.result_quit_delay_s):
		_staying = false
		get_tree().quit()


func _check_idle() -> void:
	var now := MpMatchFiles.now_ms()
	if not connected_slots().is_empty():
		_empty_since_ms = 0
		return
	if not _ever_joined and now > int(ticket.get("expires_ms", 0)):
		report_result({"reason": "ticket_expired"})
		return
	if _empty_since_ms == 0:
		_empty_since_ms = _started_ms if not _ever_joined else now
	if now - _empty_since_ms > int(config.idle_no_players_s * 1000.0):
		report_result({"reason": "empty"})


## The seat a presented token names: the slot whose sha256 matches, 0 for none or after the match ended. Only identity: whether
## the seat may still sit (the match started, late join, away, past the grace) is the gate's, so a seat nobody took hears
## match_started, not rejected. The ticket's expiry only ends a match nobody ever joined (_check_idle).
func seat_of(_peer_id: int, presented: String) -> int:
	if finished:
		return 0
	var sha := MpMatchFiles.sha256(presented)
	for slot in _seats.keys():
		if _seats[slot]["sha"] == sha:
			return int(slot)
	return 0


func _on_peer_joined(peer_id: int, slot: int) -> void:
	if not _seats.has(slot):
		return
	var seat: Dictionary = _seats[slot]
	seat["used"] = true
	seat["peer"] = peer_id
	_ever_joined = true
	_write_state()


func _on_peer_left(peer_id: int, slot: int) -> void:
	if not _seats.has(slot) or int(_seats[slot]["peer"]) != peer_id:
		return
	_seats[slot]["peer"] = 0
	_write_state()


func _on_gate_changed(_a: Variant = null, _b: Variant = null) -> void:
	_write_state()


func _write_state() -> void:
	var slots := {}
	for slot in _seats.keys():
		slots[str(slot)] = int(_seats[slot]["peer"]) != 0
	var listening := MpKit.is_listening()
	var gate := MpKit.gate
	MpMatchFiles.write_json(MpMatchFiles.path_of(_root, match_id, MpMatchFiles.STATE), {
		"match_id": match_id, "pid": OS.get_process_id(), "listening": listening,
		"heartbeat_ms": MpMatchFiles.now_ms(), "started_ms": _started_ms,
		"finished": finished, "slots": slots,
		## The match runs (the gate let it start), and the seats nobody holds that no ticket may take any more.
		"started": gate.phase == MpMatchGate.Phase.RUNNING, "closed": gate.closed_slots(), "held": gate.held_slots(),
	})
