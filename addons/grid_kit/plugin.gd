@tool
extends EditorPlugin

## GridKit in the editor. Select a GridBoard (or its GridView3D) and the 3D view gets the «GridKit» bar on top: one
## brush per tile, Erase, Add cells and Remove cells (editor/grid_paint_tool.gd). A stroke is one step of the editor's
## undo history.

const BOARD := preload("res://addons/grid_kit/nodes/grid_board.gd")
const VIEW_3D := preload("res://addons/grid_kit/nodes/grid_view_3d.gd")
const CURSOR := preload("res://addons/grid_kit/nodes/grid_cursor.gd")
const PaintTool := preload("res://addons/grid_kit/editor/grid_paint_tool.gd")

var _tool: PaintTool


func _enter_tree() -> void:
	add_custom_type("GridBoard", "Node", BOARD, null)
	add_custom_type("GridView3D", "Node3D", VIEW_3D, null)
	add_custom_type("GridCursor", "Node3D", CURSOR, null)
	_tool = PaintTool.new()
	add_child(_tool)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _tool.bar())


func _exit_tree() -> void:
	remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _tool.bar())
	_tool.bar().queue_free()
	_tool.queue_free()
	remove_custom_type("GridCursor")
	remove_custom_type("GridView3D")
	remove_custom_type("GridBoard")


func _handles(object: Object) -> bool:
	return object is GridBoard or object is GridView3D


func _edit(object: Object) -> void:
	_tool.edit(object)


func _make_visible(visible: bool) -> void:
	_tool.set_visible(visible)


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	return _tool.input(camera, event)


## A layout that is a .tres of its own is written when the editor saves (Ctrl+S, Save All, before running the game).
func _save_external_data() -> void:
	_tool.save_unsaved_layouts()


func _get_unsaved_status(for_scene: String) -> String:
	return _tool.unsaved_status(for_scene)
