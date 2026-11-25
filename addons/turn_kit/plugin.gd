@tool
extends EditorPlugin

const CLOCK := preload("res://addons/turn_kit/nodes/turn_clock.gd")
const SEAT := preload("res://addons/turn_kit/nodes/turn_seat.gd")


func _enter_tree() -> void:
	add_custom_type("TurnClock", "Node", CLOCK, preload("res://addons/turn_kit/icons/turn_clock.svg"))
	add_custom_type("TurnSeat", "Node", SEAT, preload("res://addons/turn_kit/icons/turn_seat.svg"))


func _exit_tree() -> void:
	remove_custom_type("TurnSeat")
	remove_custom_type("TurnClock")
