@tool
extends EditorPlugin

const BLOCK := preload("res://addons/stat_kit/nodes/stat_block.gd")


func _enter_tree() -> void:
	add_custom_type("StatBlock", "Node", BLOCK, preload("res://addons/stat_kit/icons/stat_block.svg"))


func _exit_tree() -> void:
	remove_custom_type("StatBlock")
