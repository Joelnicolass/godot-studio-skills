@tool
extends EditorPlugin

const DICE_ROLLER := preload("res://addons/dice_kit/nodes/dice_roller.gd")
const DICE_TRAY_3D := preload("res://addons/dice_kit/nodes/dice_tray_3d.gd")


func _enter_tree() -> void:
	add_custom_type("DiceRoller", "Node", DICE_ROLLER, preload("res://addons/dice_kit/icons/dice_roller.svg"))
	add_custom_type("DiceTray3D", "Node3D", DICE_TRAY_3D, preload("res://addons/dice_kit/icons/dice_tray_3d.svg"))


func _exit_tree() -> void:
	remove_custom_type("DiceTray3D")
	remove_custom_type("DiceRoller")
