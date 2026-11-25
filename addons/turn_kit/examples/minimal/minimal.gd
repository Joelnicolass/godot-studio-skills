extends Control

## Three seats take turns: Spend uses an action, End passes the turn. Two rounds make a cycle and the match ends after
## two cycles. The bot seat passes as soon as its turn starts.

@onready var clock: TurnClock = %Turns
@onready var status: Label = %Status
@onready var log_label: Label = %Log
@onready var spend: Button = %Spend
@onready var end: Button = %End


func _ready() -> void:
	clock.turn_started.connect(_on_turn_started)
	clock.action_spent.connect(func(_left: int) -> void: _refresh())
	clock.round_ended.connect(func(n: int) -> void: _note("Round %d over" % n))
	clock.cycle_ended.connect(func(n: int) -> void: _note("Cycle %d over" % n))
	clock.finished.connect(_on_finished)
	spend.pressed.connect(func() -> void: clock.spend_action())
	end.pressed.connect(func() -> void: clock.end_turn())


func _on_turn_started(_seat: int) -> void:
	_refresh()
	var seat := clock.current_seat_node()
	if seat != null and seat.is_bot:
		_note("%s passes" % seat.display_name)
		clock.end_turn.call_deferred()


func _on_finished() -> void:
	status.text = "Match over"
	spend.disabled = true
	end.disabled = true


func _refresh() -> void:
	var seat := clock.current_seat_node()
	if seat == null:
		return
	var turns := clock.turn_cycle
	status.text = (
		"%s · actions %d · round %d · cycle %d"
		% [seat.display_name, clock.actions_left, turns.round_number, turns.cycle_number]
	)
	spend.disabled = clock.actions_left == 0 or seat.is_bot


func _note(line: String) -> void:
	log_label.text = (line + "\n" + log_label.text).strip_edges()
