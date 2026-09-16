@tool
extends EditorPlugin

const MOTOR := preload("res://addons/plat_kit/plat_motor.gd")


func _enter_tree() -> void:
	add_custom_type("PlatMotor", "Node", MOTOR, null)
	add_tool_menu_item("PlatKit: Add motor to selected CharacterBody2D", _on_add_motor)


func _exit_tree() -> void:
	remove_tool_menu_item("PlatKit: Add motor to selected CharacterBody2D")
	remove_custom_type("PlatMotor")


func _on_add_motor() -> void:
	var edited := EditorInterface.get_edited_scene_root()
	if edited == null:
		push_warning("PlatKit: open a scene first")
		return
	var selected := EditorInterface.get_selection().get_selected_nodes()
	if selected.is_empty():
		push_warning("PlatKit: select a CharacterBody2D")
		return
	var body := selected[0] as CharacterBody2D
	if body == null:
		push_warning("PlatKit: selection is not a CharacterBody2D")
		return
	if body.get_node_or_null("PlatMotor") != null:
		push_warning("PlatKit: already has PlatMotor")
		return
	var ur := get_undo_redo()
	ur.create_action("PlatKit: add motor")
	var motor := Node.new()
	motor.name = "PlatMotor"
	motor.set_script(MOTOR)
	ur.add_do_method(body, "add_child", motor)
	ur.add_do_method(motor, "set_owner", edited)
	ur.add_undo_method(body, "remove_child", motor)
	ur.add_do_reference(motor)
	ur.commit_action()
	motor.set("body", body)
