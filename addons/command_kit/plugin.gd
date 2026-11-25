@tool
extends EditorPlugin

const BUS := preload("res://addons/command_kit/nodes/command_bus.gd")


func _enter_tree() -> void:
	add_custom_type("CommandBus", "Node", BUS, null)


func _exit_tree() -> void:
	remove_custom_type("CommandBus")
