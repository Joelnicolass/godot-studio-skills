@tool
extends EditorPlugin

## The lab's check of PropKit in a real editor, the way a person uses it: «Scatter» and «Clear»
## with undo and redo, a hand edit that undo keeps, «Bake» (a separate Godot) and the scene it
## reloads, and the saved bake's warning when the props change. Nothing unless the editor starts
## with PROPKIT_EDITOR_CHECK=1:
##   PROPKIT_EDITOR_CHECK=1 godot --headless --editor --path propkit_lab
## Prints one line per check and EDITOR CHECK PASS (exit 0) or EDITOR CHECK FAIL: n (exit 1).

const SOURCE := "res://addons/prop_kit/examples/forest_3d/forest_3d.tscn"
const COPY := "res://scratch/editor_check/forest.tscn"
const SCATTER_EDIT := "res://addons/prop_kit/editor/prop_scatter_edit.gd"
const BAKE_RUN := "res://addons/prop_kit/editor/prop_bake_run.gd"

var _fails := 0


func _enter_tree() -> void:
	if OS.get_environment("PROPKIT_EDITOR_CHECK") == "1":
		_run.call_deferred()
	elif not OS.get_environment("PROPKIT_EDITOR_SHOTS").is_empty():
		_shots.call_deferred(OS.get_environment("PROPKIT_EDITOR_SHOTS"))


func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _run() -> void:
	await _frames(10)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(COPY.get_base_dir()))
	for old in ["forest.tscn", "forest_nav.res"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(COPY.get_base_dir().path_join(old)))
	var text := FileAccess.get_file_as_string(SOURCE)
	# Its own scene: no uid of the example's.
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
	await _frames(10)
	var root := EditorInterface.get_edited_scene_root()
	_check(root != null and root.scene_file_path == COPY, "the copy of the example is open")
	var scatter := root.find_children("*", "PropScatter3D", true, false)[0] as PropScatter3D
	var history := EditorInterface.get_editor_undo_redo()
	var scatter_edit := load(SCATTER_EDIT)

	scatter_edit.scatter(scatter)
	var planted := scatter.get_child_count()
	_check(planted > 300, "«Scatter» plants the forest (%d)" % planted)
	var first := scatter.get_child(0) as Node3D
	_check(first.owner == root, "each prop is owned by the scene, so it is saved")
	var undo := history.get_history_undo_redo(history.get_object_history_id(scatter))
	undo.undo()
	_check(scatter.get_child_count() == 0, "undo takes the scatter back (%d)" % scatter.get_child_count())
	undo.redo()
	_check(scatter.get_child_count() == planted and scatter.get_child(0) == first, "redo puts the same props back")
	_check(first.owner == root, "owned by the scene again")

	first.position += Vector3(3.0, 0.0, 0.0)
	var moved := first.position
	scatter.rules.random_seed += 1
	scatter_edit.scatter(scatter)
	_check(scatter.get_child(0) != first, "«Scatter» again replaces them")
	undo.undo()
	_check(scatter.get_child(0) == first and first.position == moved, "undo brings back the hand-moved prop")
	scatter.rules.random_seed -= 1

	scatter_edit.clear(scatter)
	_check(scatter.get_child_count() == 0, "«Clear» removes them")
	undo.undo()
	_check(scatter.get_child_count() == planted, "undo puts them back")

	var zones := root.find_children("*", "PropNavZones3D", true, false)[0] as PropNavZones3D
	_check(zones.saved == null, "no saved bake yet")
	load(BAKE_RUN).bake_open_scene()
	await _frames(30)
	root = EditorInterface.get_edited_scene_root()
	zones = root.find_children("*", "PropNavZones3D", true, false)[0] as PropNavZones3D
	_check(zones.saved != null and zones.saved.resource_path == COPY.get_basename() + "_nav.res", "«Bake» saves next to the scene and the scene points at it")
	_check(zones.saved != null and zones.saved.pieces.size() == 16, "every zone is in it")
	var warnings := zones._get_configuration_warnings()
	_check(not "\n".join(warnings).contains("does not match"), "it matches the props (%s)" % [warnings])
	await _frames(60)
	_check(zones.region_of(0) != null and zones.region_of(0).navigation_mesh != null, "the editor shows the saved navmesh")

	scatter = root.find_children("*", "PropScatter3D", true, false)[0] as PropScatter3D
	scatter.rules.random_seed += 1
	load(SCATTER_EDIT).scatter(scatter)
	warnings = zones._get_configuration_warnings()
	_check("\n".join(warnings).contains("does not match"), "after a new scatter the saved bake is flagged (%s)" % [warnings])
	load(BAKE_RUN).bake_open_scene()
	await _frames(30)
	root = EditorInterface.get_edited_scene_root()
	zones = root.find_children("*", "PropNavZones3D", true, false)[0] as PropNavZones3D
	warnings = zones._get_configuration_warnings()
	_check(not "\n".join(warnings).contains("does not match"), "«Bake» again clears it (%s)" % [warnings])

	print("EDITOR CHECK PASS" if _fails == 0 else "EDITOR CHECK FAIL: %d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


## With a window: PROPKIT_EDITOR_SHOTS=<folder> saves what the 3D and 2D views show of the copy
## the check made (the scatter's ground outline and the zones) and of the 2D example.
func _shots(folder: String) -> void:
	await _frames(30)
	EditorInterface.open_scene_from_path(COPY)
	EditorInterface.set_main_screen_editor("3D")
	await _frames(20)
	var root := EditorInterface.get_edited_scene_root()
	var zones := root.find_children("*", "PropNavZones3D", true, false)[0] as Node3D
	EditorInterface.edit_node(zones)
	var camera := EditorInterface.get_editor_viewport_3d(0).get_camera_3d()
	camera.global_transform = Transform3D(Basis.looking_at(Vector3(0, -1.0, -0.8)), Vector3(0, 130, 105))
	await _frames(60)
	EditorInterface.get_editor_viewport_3d(0).get_texture().get_image().save_png(folder.path_join("editor_3d.png"))
	var scatter := root.find_children("*", "PropScatter3D", true, false)[0] as Node3D
	EditorInterface.edit_node(scatter)
	await _frames(30)
	EditorInterface.get_editor_viewport_3d(0).get_texture().get_image().save_png(folder.path_join("editor_3d_scatter.png"))
	EditorInterface.open_scene_from_path("res://addons/prop_kit/examples/grove_2d/grove_2d.tscn")
	EditorInterface.set_main_screen_editor("2D")
	await _frames(60)
	EditorInterface.get_editor_viewport_2d().get_texture().get_image().save_png(folder.path_join("editor_2d.png"))
	get_tree().quit(0)
