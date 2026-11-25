@tool
extends EditorPlugin

const COMMANDS := preload("res://addons/command_kit/nodes/game_commands.gd")


func _enter_tree() -> void:
	add_custom_type("GameCommands", "Node", COMMANDS, preload("res://addons/command_kit/icons/game_commands.svg"))


func _exit_tree() -> void:
	remove_custom_type("GameCommands")
