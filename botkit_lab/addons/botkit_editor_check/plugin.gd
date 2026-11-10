@tool
extends EditorPlugin

## The lab's check of BotKit in a real editor, the way a person uses it:
## - the robot's Bot3D has the kit's gizmo; dragging its eye and aim handles from the 3D view's camera changes them,
##   each one step that undoes and redoes; a cancelled drag leaves the value; the warnings; the saved scene keeps the
##   values, no drawing and no body (empty is its parent);
## - a pickup's BotGoal3D has the gizmo; dragging its reach handle from above, undone and redone.
## Nothing unless the editor starts with BOTKIT_EDITOR_CHECK=1:
##   BOTKIT_EDITOR_CHECK=1 godot --headless --editor --path botkit_lab
## Prints EDITOR CHECK PASS (exit 0) or EDITOR CHECK FAIL: n.

const EXAMPLES := "res://addons/bot_kit/examples"
const FOLDER := "res://scratch/editor_check"

var _fails := 0


func _enter_tree() -> void:
	if OS.get_environment("BOTKIT_EDITOR_CHECK") == "1":
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


func _kit_plugin() -> EditorPlugin:
	for node in get_tree().root.find_children("*", "EditorPlugin", true, false):
		var script := node.get_script() as Script
		if script != null and script.resource_path == "res://addons/bot_kit/plugin.gd":
			return node as EditorPlugin
	return null


func _gizmo_of(node: Node3D, plugin: EditorNode3DGizmoPlugin) -> EditorNode3DGizmo:
	for each in node.get_gizmos():
		if (each as EditorNode3DGizmo).get_plugin() == plugin:
			return each
	return null


func _run() -> void:
	await _frames(10)
	if DirAccess.dir_exists_absolute(FOLDER):
		for old in DirAccess.get_directories_at(FOLDER):
			_remove(FOLDER.path_join(old))
	var kit := _kit_plugin()
	_check(kit != null, "the BotKit plugin is on")
	if kit != null:
		await _check_bot(kit)
		await _check_goal(kit)
	print("EDITOR CHECK PASS" if _fails == 0 else "EDITOR CHECK FAIL: %d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _check_bot(kit: EditorPlugin) -> void:
	var root := await _open_copy(EXAMPLES.path_join("minimal_3d/minimal_3d.tscn"), "robot.tscn")
	_check(root != null and root.name == &"Minimal3D", "the copy of minimal_3d is open")
	EditorInterface.set_main_screen_editor("3D")
	var bot := root.get_node(^"Robot/Bot3D") as Bot3D
	var robot := root.get_node(^"Robot") as Node3D
	var start := robot.global_position
	EditorInterface.edit_node(bot)
	await _frames(10)
	var plugin: EditorNode3DGizmoPlugin = kit.get(&"_gizmos")
	var gizmo := _gizmo_of(bot, plugin)
	_check(gizmo != null, "the bot has the kit's gizmo")
	if gizmo == null:
		return
	var camera := EditorInterface.get_editor_viewport_3d(0).get_camera_3d()
	var feet := bot.feet()
	_check(feet.is_equal_approx(robot.global_position), "in the editor its feet are its parent's")
	camera.global_transform = Transform3D(Basis.looking_at(Vector3(-1, 0, 0)), feet + Vector3(10, 1.5, 0))
	await _frames(3)
	# The eyes: from 1.6 to 1.8 m.
	var restore: Variant = plugin._get_handle_value(gizmo, 0, false)
	plugin._set_handle(gizmo, 0, false, camera, camera.unproject_position(feet + Vector3(0, 1.8, 0)))
	plugin._commit_handle(gizmo, 0, false, restore, false)
	_check(absf(bot.eye_height_m - 1.8) < 0.03, "dragging the eye handle to 1.8 m (%.2f)" % bot.eye_height_m)
	_history(bot).undo()
	_check(is_equal_approx(bot.eye_height_m, 1.6), "Ctrl+Z: back to 1.6 m")
	_history(bot).redo()
	_check(absf(bot.eye_height_m - 1.8) < 0.03, "Ctrl+Shift+Z: 1.8 m again")
	# The aim: to 0.9 m, then a cancelled drag.
	restore = plugin._get_handle_value(gizmo, 1, false)
	plugin._set_handle(gizmo, 1, false, camera, camera.unproject_position(feet + Vector3(0, 0.9, 0)))
	plugin._commit_handle(gizmo, 1, false, restore, false)
	_check(absf(bot.aim_height_m - 0.9) < 0.03, "dragging the aim handle to 0.9 m (%.2f)" % bot.aim_height_m)
	restore = plugin._get_handle_value(gizmo, 1, false)
	plugin._set_handle(gizmo, 1, false, camera, camera.unproject_position(feet + Vector3(0, 0.3, 0)))
	plugin._commit_handle(gizmo, 1, false, restore, true)
	_check(absf(bot.aim_height_m - 0.9) < 0.03, "a cancelled drag (Esc, right click) leaves it")
	# The warnings.
	_check(bot._get_configuration_warnings().is_empty(), "no warning on the robot's bot")
	bot.target_group = &""
	_check(bot._get_configuration_warnings().size() == 1, "an empty group warns")
	bot.target_group = &"bot_target"
	var odd := BotWeapon.new()
	odd.min_m = 20.0
	odd.max_m = 5.0
	var weapons: Array[BotWeapon] = [odd]
	bot.weapons = weapons
	_check(bot._get_configuration_warnings().size() == 1, "a weapon with min_m above max_m warns")
	bot.weapons = []
	var mode := BotMode.new()
	root.add_child(mode)
	_check(mode._get_configuration_warnings().size() == 1, "a BotMode outside a bot warns")
	mode.free()
	# In the editor it never plays.
	await _frames(30)
	_check(robot.global_position.is_equal_approx(start) and bot.input.held().is_empty(), "in the editor it presses nothing and the robot stays")
	EditorInterface.save_scene()
	await _frames(5)
	var saved := FileAccess.get_file_as_string(root.scene_file_path)
	_check(saved.contains("eye_height_m = 1.8"), "the saved scene has the dragged eye height")
	_check(not saved.contains("body = NodePath") and not saved.contains("BotDebug"), "and no body (its parent) nor drawing")


func _check_goal(kit: EditorPlugin) -> void:
	var root := await _open_copy(EXAMPLES.path_join("arena_3d/arena_3d.tscn"), "arena.tscn")
	_check(root != null and root.name == &"Arena3D", "the copy of arena_3d is open")
	var goal := root.get_node(^"Health/BotGoal3D") as BotGoal3D
	EditorInterface.edit_node(goal)
	await _frames(10)
	var plugin: EditorNode3DGizmoPlugin = kit.get(&"_gizmos")
	var gizmo := _gizmo_of(goal, plugin)
	_check(gizmo != null, "the goal has the kit's gizmo")
	if gizmo == null:
		return
	var camera := EditorInterface.get_editor_viewport_3d(0).get_camera_3d()
	var at := goal.global_position
	camera.global_transform = Transform3D(Basis.looking_at(Vector3(0, -1, -0.01)), at + Vector3(0, 40, 0))
	await _frames(3)
	var restore: Variant = plugin._get_handle_value(gizmo, 0, false)
	plugin._set_handle(gizmo, 0, false, camera, camera.unproject_position(at + Vector3.RIGHT * 15.0))
	plugin._commit_handle(gizmo, 0, false, restore, false)
	_check(absf(goal.reach_m - 15.0) <= 0.5, "dragging the reach handle to 15 m (%.1f)" % goal.reach_m)
	_history(goal).undo()
	_check(is_equal_approx(goal.reach_m, 25.0), "Ctrl+Z: 25 m again")
	_history(goal).redo()
	_check(absf(goal.reach_m - 15.0) <= 0.5, "Ctrl+Shift+Z: 15 m")
	goal.reach_m = 0.0
	_check(goal._get_configuration_warnings().size() == 1, "no reach warns")


func _remove(folder: String) -> void:
	for name in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join(name)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
