@tool
extends EditorPlugin

## SpillKit in the editor: the cost line at the top of a SpillPool3D's and a SpillSource3D's
## inspector (editor/spill_inspector.gd). The "Try it" buttons (spray, heavy spray, die, clear) and
## the warnings are the nodes' own; the nodes work without the plugin.

var _inspector: EditorInspectorPlugin


func _enter_tree() -> void:
	_inspector = preload("editor/spill_inspector.gd").new()
	add_inspector_plugin(_inspector)


func _exit_tree() -> void:
	remove_inspector_plugin(_inspector)
