extends Node2D

## A match that waits in the world until its host starts it (the boot's MpFlow: start_on_timeout off; the HUD's Start
## button), with a bot in every seat nobody holds, and late players who take a bot's seat (MpFlow: late_join on).
## The bots come from the SeatBots node (MpSeatBots, with bot.tscn): it puts one on each free seat's pawn when the match
## starts, and takes it off when a player takes the seat. The bot (bot.gd) only presses keys: the player's own mp_move
## moves it.


func _ready() -> void:
	if MpKit.is_authority() and MpKit.is_networked():
		Mp.gate().joined_late.connect(func(slot: int) -> void: print("P%d took a bot's seat" % slot))
