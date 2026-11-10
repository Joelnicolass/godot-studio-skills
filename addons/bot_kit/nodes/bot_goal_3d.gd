@tool
@icon("res://addons/bot_kit/editor/bot_goal_3d.svg")
class_name BotGoal3D
extends Node3D

## A place worth walking to for a bot with nobody to fight: drop one in a pickup's scene (a weapon, health, a
## power-up). A roaming Bot3D walks to the goal of the highest `priority` within its reach, the nearest of those. A
## hidden goal (the pickup was taken and hides) or a disabled one counts for no bot. Your own rule, whether this bot
## wants it (it has that weapon with plenty of ammo, its health is full), goes in `wanted`. Its reach is drawn in the
## 3D view with a handle to drag.

## Off: no bot walks to it.
@export var enabled := true
## Bots go for the highest priority first (a power-up over a box of ammo).
@export_range(0.0, 100.0, 0.1) var priority := 1.0
## Farther than this it is not worth the walk (each bot's difficulty scales it).
@export_range(0.0, 500.0, 0.5, "suffix:m") var reach_m := 20.0:
	set(value):
		reach_m = value
		update_gizmos()
		update_configuration_warnings()

## (bot: Bot3D) -> bool: whether that bot wants it now. Empty: every bot does.
var wanted: Callable = Callable()

const GROUP := &"bot_kit_goal"


func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		add_to_group(GROUP)


func _exit_tree() -> void:
	if is_in_group(GROUP):
		remove_from_group(GROUP)


## Whether `bot` would walk to it from `from` (on, shown, in its reach, and `wanted` agrees).
func is_for(bot: Bot3D, from: Vector3) -> bool:
	if not enabled or not is_visible_in_tree() or is_queued_for_deletion():
		return false
	var reach := reach_m * bot.current_difficulty().goal_reach_scale
	if reach <= 0.0 or from.distance_to(global_position) > reach:
		return false
	return not wanted.is_valid() or bool(wanted.call(bot))


func _get_configuration_warnings() -> PackedStringArray:
	if reach_m <= 0.0:
		return PackedStringArray(["reach_m is 0: no bot walks to this goal."])
	return PackedStringArray()
