@tool
extends EditorPlugin

## The lab's check of GrassKit in a real editor, the way a person uses it: the grass shows around
## the 3D view's camera with the editor's smaller radius, the field warns that its ground is flat,
## «Bake ground» reads the hills and saves next to the scene, the warning goes, and a GrassClear3D
## has its gizmo. Nothing unless the editor starts with GRASSKIT_EDITOR_CHECK=1:
##   GRASSKIT_EDITOR_CHECK=1 godot --headless --editor --path grasskit_lab
## (headless, the field is told to draw anyway). With a window, GRASSKIT_EDITOR_SHOTS=<folder>
## saves what the 3D view shows. Prints EDITOR CHECK PASS (exit 0) or EDITOR CHECK FAIL: n.

const SOURCE := "res://addons/grass_kit/examples/grass_3d/grass_3d.tscn"
const COPY := "res://scratch/editor_check/grass.tscn"

var _fails := 0


func _enter_tree() -> void:
	if OS.get_environment("GRASSKIT_EDITOR_CHECK") == "1":
		_run.call_deferred()
	elif not OS.get_environment("GRASSKIT_EDITOR_SHOTS").is_empty():
		_shots.call_deferred(OS.get_environment("GRASSKIT_EDITOR_SHOTS"))


func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _open_copy() -> Node:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(COPY.get_base_dir()))
	for old in ["grass.tscn", "grass_grass_ground.res"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(COPY.get_base_dir().path_join(old)))
	var text := FileAccess.get_file_as_string(SOURCE)
	text = RegEx.create_from_string(" uid=\"uid://[a-z0-9]+\"").sub(text, "", false)
	var file := FileAccess.open(COPY, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	EditorInterface.get_resource_filesystem().scan()
	await _frames(30)
	# The editor may reopen it from the last session, as it was then: read the fresh copy.
	if EditorInterface.get_open_scenes().has(COPY):
		EditorInterface.reload_scene_from_path(COPY)
	EditorInterface.open_scene_from_path(COPY)
	EditorInterface.set_main_screen_editor("3D")
	await _frames(30)
	return EditorInterface.get_edited_scene_root()


func _field(root: Node) -> GrassField3D:
	return root.find_children("*", "GrassField3D", true, false)[0] as GrassField3D


func _run() -> void:
	GrassField3D.draw_anywhere = true
	await _frames(10)
	var root := await _open_copy()
	_check(root != null and root.scene_file_path == COPY, "the copy of the example is open")
	var field := _field(root)
	field.enabled = false
	field.enabled = true
	await _frames(30)
	_check(field.stats.cells > 0, "the grass shows in the editor, around the 3D view's camera (%s)" % field.stats)
	var play_ring := field.quality.blades_in_ring()
	_check(field.stats.blades < play_ring, "with the editor's smaller radius (%d < %d)" % [field.stats.blades, play_ring])
	_check(field.get_child_count() == 0 and field.get_child_count(true) > 0, "its cells are internal: not in the scene")
	var warnings := "\n".join(field._get_configuration_warnings())
	_check(warnings.contains("Bake ground"), "it warns that the ground is flat (%s)" % warnings)
	await get_tree().physics_frame
	field.bake_button.call()
	var saved := COPY.get_basename() + "_grass_ground.res"
	_check(field.ground.data != null and field.ground.resource_path == saved, "«Bake ground» reads the hills and saves next to the scene (%s)" % field.ground.resource_path)
	_check(FileAccess.file_exists(saved), "the file is there")
	var hills := root.get_node("Hills")
	_check(absf(field.ground.height_at(Vector2(4, 7)) - float(hills.call(&"height_at", 4.0, 7.0))) < 0.1, "with the hills' height")
	warnings = "\n".join(field._get_configuration_warnings())
	_check(not warnings.contains("Bake ground"), "the warning is gone (%s)" % warnings)
	var clear := root.find_children("*", "GrassClear3D", true, false)[0] as Node3D
	_check(clear.get_gizmos().size() > 0, "the GrassClear3D has its gizmo")
	GrassField3D.draw_anywhere = false
	print("EDITOR CHECK PASS" if _fails == 0 else "EDITOR CHECK FAIL: %d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _shots(folder: String) -> void:
	await _frames(30)
	var root := await _open_copy()
	var field := _field(root)
	await get_tree().physics_frame
	field.bake_button.call()
	var camera := EditorInterface.get_editor_viewport_3d(0).get_camera_3d()
	camera.global_transform = Transform3D(Basis.looking_at(Vector3(-0.5, -0.45, -1.0)), Vector3(12, 14, 28))
	EditorInterface.edit_node(root.find_children("*", "GrassClear3D", true, false)[0])
	await _frames(90)
	EditorInterface.get_editor_viewport_3d(0).get_texture().get_image().save_png(folder.path_join("editor_3d.png"))
	get_tree().quit(0)
