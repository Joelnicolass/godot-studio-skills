@tool
extends EditorPlugin

## The lab's check of PerceptionKit in a real editor, the way a person uses it:
## - 3D: the guard's sensor has the kit's gizmo; dragging its sight radius, angle and eye height
##   handles from the 3D view's camera changes them, each one step that undoes and redoes; lose
##   under sight warns; the saved scene keeps the values and no internal shape;
## - 2D: selecting the 2D guard's sensor gives its handles; a press on the sight handle, a drag and
##   a release change it as one step that undoes; a press away from them is left to the editor.
## Nothing unless the editor starts with PERCEPTIONKIT_EDITOR_CHECK=1:
##   PERCEPTIONKIT_EDITOR_CHECK=1 godot --headless --editor --path perceptionkit_lab
## Prints EDITOR CHECK PASS (exit 0) or EDITOR CHECK FAIL: n.

const EXAMPLES := "res://addons/perception_kit/examples"
const FOLDER := "res://scratch/editor_check"

var _fails := 0


func _enter_tree() -> void:
	if OS.get_environment("PERCEPTIONKIT_EDITOR_CHECK") == "1":
		_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


## A copy of an example (the addon's own files stay as they are).
func _open_copy(source: String, name: String) -> Node:
	var folder := FOLDER.path_join("run_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var copy := folder.path_join(name)
	var text := FileAccess.get_file_as_string(source)
	text = RegEx.create_from_string(" uid=\"uid://[a-z0-9]+\"").sub(text, "", true)
	var file := FileAccess.open(copy, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	EditorInterface.get_resource_filesystem().scan()
	await _frames(20)
	EditorInterface.open_scene_from_path(copy)
	await _frames(20)
	return EditorInterface.get_edited_scene_root()


func _history(object: Object) -> UndoRedo:
	var manager := EditorInterface.get_editor_undo_redo()
	return manager.get_history_undo_redo(manager.get_object_history_id(object))


## PerceptionKit's own plugin, as the editor runs it.
func _kit_plugin() -> EditorPlugin:
	for node in get_tree().root.find_children("*", "EditorPlugin", true, false):
		var script := node.get_script() as Script
		if script != null and script.resource_path == "res://addons/perception_kit/plugin.gd":
			return node as EditorPlugin
	return null


func _run() -> void:
	await _frames(10)
	if DirAccess.dir_exists_absolute(FOLDER):
		for old in DirAccess.get_directories_at(FOLDER):
			_remove(FOLDER.path_join(old))
	var kit := _kit_plugin()
	_check(kit != null, "the PerceptionKit plugin is on")
	await _check_3d(kit)
	await _check_2d(kit)
	print("EDITOR CHECK PASS" if _fails == 0 else "EDITOR CHECK FAIL: %d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _check_3d(kit: EditorPlugin) -> void:
	var root := await _open_copy(EXAMPLES.path_join("minimal_3d/minimal_3d.tscn"), "guard.tscn")
	_check(root != null and root.name == &"Minimal3D", "the copy of minimal_3d is open")
	EditorInterface.set_main_screen_editor("3D")
	var sensor := root.get_node(^"Guard/Head/Sensor") as PerceptionSensor3D
	EditorInterface.edit_node(sensor)
	await _frames(10)
	var plugin: EditorNode3DGizmoPlugin = kit.get(&"_gizmos")
	var gizmo: EditorNode3DGizmo = null
	for each in sensor.get_gizmos():
		if (each as EditorNode3DGizmo).get_plugin() == plugin:
			gizmo = each
	_check(gizmo != null, "the sensor has the kit's gizmo")
	if gizmo == null:
		return
	var viewport := EditorInterface.get_editor_viewport_3d(0)
	var camera := viewport.get_camera_3d()
	var eye := sensor.eye_position()
	camera.global_transform = Transform3D(Basis.looking_at(Vector3(0, -1, -0.6)), eye + Vector3(0, 14, 6))
	await _frames(3)
	var forward := -sensor.global_basis.z
	# The sight radius: from 12 to 9 m.
	var restore: Variant = plugin._get_handle_value(gizmo, 0, false)
	plugin._set_handle(gizmo, 0, false, camera, camera.unproject_position(eye + forward * 9.0))
	plugin._commit_handle(gizmo, 0, false, restore, false)
	_check(absf(sensor.sight_radius_m - 9.0) < 0.15, "dragging the sight handle 9 m ahead (%.1f)" % sensor.sight_radius_m)
	_history(sensor).undo()
	_check(is_equal_approx(sensor.sight_radius_m, 12.0), "Ctrl+Z: back to 12 m")
	_history(sensor).redo()
	_check(absf(sensor.sight_radius_m - 9.0) < 0.15, "Ctrl+Shift+Z: 9 m again")
	# The angle: its handle 45° off ahead, a 90° view.
	restore = plugin._get_handle_value(gizmo, 2, false)
	var side := forward.rotated(Vector3.UP, deg_to_rad(-45.0)) * 8.0
	plugin._set_handle(gizmo, 2, false, camera, camera.unproject_position(eye + side))
	plugin._commit_handle(gizmo, 2, false, restore, false)
	_check(absf(sensor.view_angle_deg - 90.0) <= 2.0, "dragging the angle handle: a 90° view (%.0f)" % sensor.view_angle_deg)
	_history(sensor).undo()
	_check(is_equal_approx(sensor.view_angle_deg, 100.0), "Ctrl+Z: 100° again")
	# The eyes: seen from the side, 0.5 m higher.
	camera.global_transform = Transform3D(Basis.looking_at(Vector3(-1, 0, 0)), sensor.global_position + Vector3(10, 0.5, 0))
	await _frames(3)
	restore = plugin._get_handle_value(gizmo, 4, false)
	plugin._set_handle(gizmo, 4, false, camera, camera.unproject_position(sensor.global_position + Vector3(0, 0.5, 0)))
	plugin._commit_handle(gizmo, 4, false, restore, false)
	_check(absf(sensor.eye_height_m - 0.5) < 0.05, "dragging the eye handle up 0.5 m (%.2f)" % sensor.eye_height_m)
	_history(sensor).undo()
	_check(is_zero_approx(sensor.eye_height_m), "Ctrl+Z: the eyes back at the sensor")
	# Cancelled: the value as it was.
	restore = plugin._get_handle_value(gizmo, 3, false)
	plugin._set_handle(gizmo, 3, false, camera, camera.unproject_position(eye - forward * 5.0))
	plugin._commit_handle(gizmo, 3, false, restore, true)
	_check(is_equal_approx(sensor.near_radius_m, 2.0), "a cancelled drag (Esc, right click) leaves the near radius")
	# The inspector's warning.
	sensor.lose_radius_m = 5.0
	_check(sensor._get_configuration_warnings().size() == 1, "lose under sight: the scene tree warns")
	sensor.lose_radius_m = 16.0
	_check(sensor._get_configuration_warnings().is_empty(), "and stops warning")
	# Saved: the values, no internal shape.
	EditorInterface.save_scene()
	await _frames(5)
	var saved := FileAccess.get_file_as_string(root.scene_file_path)
	_check(saved.contains("sight_radius_m = 9.0") or saved.contains("sight_radius_m = 9"), "the saved scene has the dragged radius")
	_check(not saved.contains("parent=\"Guard/Head/Sensor\""), "and no shape under the sensor (its own is internal)")


func _check_2d(kit: EditorPlugin) -> void:
	var root := await _open_copy(EXAMPLES.path_join("minimal_2d/minimal_2d.tscn"), "guard_2d.tscn")
	_check(root != null and root.name == &"Minimal2D", "the copy of minimal_2d is open")
	EditorInterface.set_main_screen_editor("2D")
	var sensor := root.get_node(^"Guard/Sensor") as PerceptionSensor2D
	EditorInterface.edit_node(sensor)
	await _frames(10)
	_check(kit._handles(sensor) and kit.get(&"_sensor") == sensor, "selecting the 2D sensor: the kit edits it")
	var handles: PackedVector2Array = kit.call(&"screen_handles", sensor)
	_check(handles.size() == 4, "four handles on the 2D view")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = handles[0] + Vector2(2, 1)
	_check(kit._forward_canvas_gui_input(press), "a press on the sight handle grabs it")
	var to_screen := sensor.get_viewport_transform() * Transform2D(sensor.global_rotation, sensor.global_position)
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = to_screen * Vector2(250, 0)
	_check(kit._forward_canvas_gui_input(motion), "the drag is the kit's")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = motion.position
	kit._forward_canvas_gui_input(release)
	_check(absf(sensor.sight_radius_px - 250.0) <= 1.0, "dragged to 250 px (%.0f)" % sensor.sight_radius_px)
	_history(sensor).undo()
	_check(is_equal_approx(sensor.sight_radius_px, 340.0), "Ctrl+Z: 340 px again")
	press.position = to_screen * Vector2(150, 150)
	_check(not kit._forward_canvas_gui_input(press), "a press away from the handles is left to the editor")


func _remove(folder: String) -> void:
	for name in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join(name)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
