@tool
extends EditorPlugin

const GESTURE_AREA := preload("res://addons/gesture_kit/nodes/gesture_area.gd")


func _enter_tree() -> void:
	add_custom_type("GestureArea", "Control", GESTURE_AREA, preload("res://addons/gesture_kit/icons/gesture_area.svg"))


func _exit_tree() -> void:
	remove_custom_type("GestureArea")
