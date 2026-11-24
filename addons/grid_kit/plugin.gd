@tool
extends EditorPlugin

const BOARD := preload("res://addons/grid_kit/nodes/grid_board.gd")
const VIEW_3D := preload("res://addons/grid_kit/nodes/grid_view_3d.gd")
const CURSOR := preload("res://addons/grid_kit/nodes/grid_cursor.gd")


func _enter_tree() -> void:
	add_custom_type("GridBoard", "Node", BOARD, null)
	add_custom_type("GridView3D", "Node3D", VIEW_3D, null)
	add_custom_type("GridCursor", "Node3D", CURSOR, null)


func _exit_tree() -> void:
	remove_custom_type("GridCursor")
	remove_custom_type("GridView3D")
	remove_custom_type("GridBoard")
