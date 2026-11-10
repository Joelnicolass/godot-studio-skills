@tool
@icon("res://addons/bot_kit/editor/bot_mode.svg")
class_name BotMode
extends Node

## Something your bot does besides fighting and roaming: flee when hurt, guard a door, follow a leader, carry a flag
## home. Add it as a child of a Bot3D and override `_want()` and `_tick()` (both get the bot). On each think the bot
## does what wants it most: its own fight wants `Bot3D.fight_want` (1) while it has an enemy in sight, its roam
## `Bot3D.roam_want` (0.1) always; ties keep what it is doing. The bot's helpers (`walk_to`, `aim_and_fire`, `move`,
## `look_toward`, `press`) are what a mode uses.

## Off: the bot never picks it.
@export var enabled := true


## How much it wants to run now (0: not at all). Called on each think.
func _want(_bot: Bot3D) -> float:
	return 0.0


## It starts running.
func _enter(_bot: Bot3D) -> void:
	pass


## Every physics frame while it runs.
func _tick(_bot: Bot3D, _delta: float) -> void:
	pass


## It stops running (another mode won, or the bot was turned off).
func _exit(_bot: Bot3D) -> void:
	pass


func _get_configuration_warnings() -> PackedStringArray:
	if not get_parent() is Bot3D:
		return PackedStringArray(["A BotMode works as a child of a Bot3D."])
	return PackedStringArray()
