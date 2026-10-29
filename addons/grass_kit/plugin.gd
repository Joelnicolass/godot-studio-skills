@tool
extends EditorPlugin

## In the 3D view: a GrassClear3D's circles (where grass stops and where it is full again) and a
## GrassField3D's ground area. Enabling the plugin adds GrassKit's global shader uniforms to
## Project Settings > Shader Globals (the wind, and where the grass ends), only the ones missing and
## no other, so the game's own shaders that include grass_wind.gdshaderinc or
## grass_ground.gdshaderinc compile from the start. Disabling it leaves them: a game's shader may
## still read them (remove them by hand there if none does).

var _gizmos: EditorNode3DGizmoPlugin


func _enable_plugin() -> void:
	if GrassGlobals.add_to_project():
		ProjectSettings.save()


func _enter_tree() -> void:
	_gizmos = preload("editor/grass_gizmos.gd").new()
	add_node_3d_gizmo_plugin(_gizmos)


func _exit_tree() -> void:
	remove_node_3d_gizmo_plugin(_gizmos)
