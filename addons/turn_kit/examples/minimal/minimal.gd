extends Control

## Three seats take turns. A turn has two phases (draw, play) and 10 seconds: Spend action uses an action, Next phase
## moves on and End turn passes; when the time runs out the turn passes by itself. Every round is opened by the next
## seat. Two rounds make a cycle and the match ends after two cycles. The bot seat passes as soon as its turn starts.

@onready var clock: TurnClock = %Turns
@onready var status: Label = %Status
@onready var log_label: Label = %Log
@onready var spend: Button = %Spend
@onready var next_phase: Button = %NextPhase
@onready var end: Button = %End


func _ready() -> void:
	clock.turn_started.connect(_on_turn_started)
	clock.action_spent.connect(func(_left: int) -> void: _refresh())
	clock.phase_started.connect(func(_phase: StringName) -> void: _refresh())
	clock.turn_timed_out.connect(func(seat: int) -> void: _note("%s ran out of time" % _name(seat)))
	clock.round_ended.connect(func(n: int) -> void: _note("Round %d over" % n))
	clock.cycle_ended.connect(func(n: int) -> void: _note("Cycle %d over" % n))
	clock.finished.connect(_on_finished)
	spend.pressed.connect(func() -> void: clock.spend_action())
	next_phase.pressed.connect(func() -> void: clock.next_phase())
	end.pressed.connect(func() -> void: clock.end_turn())


func _process(_delta: float) -> void:
	_refresh()


func _on_turn_started(seat: int) -> void:
	if seat == clock.turn_cycle.round_first_seat:
		_note("Round %d opens with %s" % [clock.turn_cycle.round_number, _name(seat)])
	var node := clock.current_seat_node()
	if node != null and node.is_bot:
		_note("%s passes" % node.display_name)
		clock.end_turn.call_deferred()


func _on_finished() -> void:
	status.text = "Match over"
	for button: Button in [spend, next_phase, end]:
		button.disabled = true
	set_process(false)


func _refresh() -> void:
	var node := clock.current_seat_node()
	if node == null:
		return
	status.text = (
		"%s · %s · actions %d · %.1f s" % [node.display_name, clock.current_phase, clock.actions_left, clock.time_left]
	)
	spend.disabled = clock.actions_left == 0 or node.is_bot


func _name(seat: int) -> String:
	return clock.seat_node(seat).display_name


func _note(line: String) -> void:
	log_label.text = (line + "\n" + log_label.text).strip_edges()
