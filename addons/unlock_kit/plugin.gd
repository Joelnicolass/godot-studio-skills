@tool
extends EditorPlugin

const TREE := preload("res://addons/unlock_kit/nodes/unlock_tree.gd")
const ENTRY := preload("res://addons/unlock_kit/nodes/unlock_entry.gd")
const VIEW := preload("res://addons/unlock_kit/nodes/unlock_tree_view.gd")


func _enter_tree() -> void:
	add_custom_type("UnlockTree", "Node", TREE, preload("res://addons/unlock_kit/icons/unlock_tree.svg"))
	add_custom_type("UnlockEntry", "Node", ENTRY, preload("res://addons/unlock_kit/icons/unlock_entry.svg"))
	add_custom_type("UnlockTreeView", "Control", VIEW, preload("res://addons/unlock_kit/icons/unlock_tree_view.svg"))


func _exit_tree() -> void:
	remove_custom_type("UnlockTreeView")
	remove_custom_type("UnlockEntry")
	remove_custom_type("UnlockTree")
