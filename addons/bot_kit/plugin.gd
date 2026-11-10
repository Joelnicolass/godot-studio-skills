@tool
extends EditorPlugin

## BotKit in the editor: select a Bot3D to see its sight, fire cone and fight distance in the 3D view and drag its
## eye and aim heights; select a BotGoal3D to drag its reach (editor/bot_gizmo_3d.gd). Every drag is one step of the
## editor's history. The nodes work without the plugin.

var _gizmos: EditorNode3DGizmoPlugin


func _enter_tree() -> void:
	_gizmos = preload("editor/bot_gizmo_3d.gd").new()
	add_node_3d_gizmo_plugin(_gizmos)


func _exit_tree() -> void:
	remove_node_3d_gizmo_plugin(_gizmos)
