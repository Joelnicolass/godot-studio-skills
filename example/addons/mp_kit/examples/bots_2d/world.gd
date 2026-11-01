extends Node2D

## A match that waits in the world until its host starts it (the boot's MpFlow: start_on_timeout off; the HUD's Start
## button), with a bot in every seat nobody holds, and late players who take a bot's seat (MpFlow: late_join on).
## The bot (bot.gd) only presses keys: the player's own mp_move moves it. Server and solo only.

const BOT := preload("res://addons/mp_kit/examples/bots_2d/bot.gd")

@onready var players: MpSlotSpawner = $MpWorld/Players


func _ready() -> void:
	if not MpKit.is_authority():
		return
	if not MpKit.is_networked():
		## Solo: the gate has no seats; the free ones are every seat but this player's.
		for slot in range(2, $MpWorld.seats + 1):
			_bot_in(slot)
		return
	var gate := Mp.gate()
	gate.started.connect(func(_why: String) -> void: _fill_free_seats())
	gate.joined_late.connect(func(slot: int) -> void: print("P%d took a bot's seat" % slot))
	if gate.phase == MpMatchGate.Phase.RUNNING:
		_fill_free_seats()


func _fill_free_seats() -> void:
	for slot in Mp.gate().vacant_slots():
		_bot_in(slot)


## The slot's pawn, with a bot on it. A player who takes the seat later gets this same pawn.
func _bot_in(slot: int) -> void:
	var pawn := players.spawn_slot(slot)
	if pawn == null or pawn.has_node(^"Bot"):
		return
	var bot := BOT.new()
	bot.name = "Bot"
	pawn.add_child(bot)
