@tool
extends EditorPlugin

## Checks GestureKit in the real editor: it opens the example, finds the GestureArea in the 2D view, edits it
## through the inspector (a threshold, then undo with the shortcut; a swipe action that does not exist, then one that
## does) and saves a copy. It does nothing at all unless the editor was started with `--gesturekit-editor-check`:
##   godot --headless --editor --path gesturekit_lab -- --gesturekit-editor-check
## It prints one PASS or FAIL line per check, then GESTUREKIT EDITOR CHECK PASS (n) or FAIL: k of n, and exits with 0
## or 1. It never saves the example: the one save is a copy in res://editor_check/tmp, which it deletes at the end.

const ARG := "--gesturekit-editor-check"
const TMP := "res://editor_check/tmp"
const EXAMPLE := "res://addons/gesture_kit/examples/minimal/minimal.tscn"
const ICON := "res://addons/gesture_kit/icons/gesture_area.svg"
const TIMEOUT_SECONDS := 120.0

var _passes := 0
var _fails := 0
var _done := false
var _on_disk: Dictionary[String, String] = {}


func _enter_tree() -> void:
	if not OS.get_cmdline_user_args().has(ARG):
		return
	_run.call_deferred()


func _run() -> void:
	get_tree().create_timer(TIMEOUT_SECONDS).timeout.connect(_on_timeout)
	await _frames(30)
	_on_disk[EXAMPLE] = FileAccess.get_file_as_string(EXAMPLE)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP))
	_check_the_class()
	await _check_example()
	_check("the example on disk is untouched", FileAccess.get_file_as_string(EXAMPLE) == _on_disk[EXAMPLE])
	_finish()


func _on_timeout() -> void:
	if not _done:
		_check("finishes in time", false)
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	_remove_dir(TMP)
	var total := _passes + _fails
	if _fails == 0:
		print("GESTUREKIT EDITOR CHECK PASS (%d)" % total)
	else:
		print("GESTUREKIT EDITOR CHECK FAIL: %d of %d" % [_fails, total])
	get_tree().quit(0 if _fails == 0 else 1)


# --- the checks -------------------------------------------------------------------------------


func _check_the_class() -> void:
	var found := {}
	for entry in ProjectSettings.get_global_class_list():
		if entry["class"] == &"GestureArea":
			found = entry
	_check("a: GestureArea is a class of the project, a Control", not found.is_empty() and found["base"] == &"Control")
	_check("a: with its icon", not found.is_empty() and found["icon"] == ICON)


func _check_example() -> void:
	EditorInterface.open_scene_from_path(EXAMPLE)
	await _frames(20)
	EditorInterface.set_main_screen_editor("2D")
	await _frames(10)
	var root := EditorInterface.get_edited_scene_root()
	var area := root.get_node_or_null(^"%Area") as GestureArea
	_check("b: the example has its GestureArea", area != null)
	if area == null:
		return
	_check("b: it has no warnings", area._get_configuration_warnings().is_empty())
	_check("b: it covers the scene", area.size == root.size and area.is_visible_in_tree())
	_check("b: it runs nothing in the editor", not area.is_processing())
	await _select(area)
	for name: StringName in [
		&"units", &"slop_px", &"long_press_s", &"swipe_min_px", &"swipe_directions", &"swipe_left_action"
	]:
		_check("c: the inspector shows %s" % name, _property(name) != null)
	await _set_in_inspector(area, &"swipe_min_px", 90.0)
	_check("d: swipe_min_px set through the inspector", area.swipe_min_px == 90.0)
	_check("d: it reaches the reader", area.reader.swipe_min_px == 90.0)
	await _editor_undo()
	_check(
		"d: undo with the shortcut: 60 again, in the reader too",
		area.swipe_min_px == 60.0 and area.reader.swipe_min_px == 60.0
	)
	await _set_in_inspector(area, &"swipe_left_action", &"gk_no_such_action")
	var warnings := area._get_configuration_warnings()
	_check(
		"e: an action that is not in the Input Map is a warning",
		warnings.size() == 1 and warnings[0].contains("gk_no_such_action")
	)
	await _set_in_inspector(area, &"swipe_left_action", &"ui_left")
	_check("e: one that is (ui_left) is not", area._get_configuration_warnings().is_empty())
	await _set_in_inspector(area, &"mouse_filter", Control.MOUSE_FILTER_IGNORE)
	_check("e: mouse_filter Ignore is a warning", area._get_configuration_warnings().size() == 1)
	await _editor_undo()
	_check(
		"e: undo: Stop again, no warning",
		area.mouse_filter == Control.MOUSE_FILTER_STOP and area._get_configuration_warnings().is_empty()
	)
	var copy := TMP + "/minimal_copy.tscn"
	EditorInterface.save_scene_as(copy, false)
	await _frames(10)
	var saved := FileAccess.get_file_as_string(copy)
	_check("f: a copy of the scene was saved", saved.contains("gesture_area.gd"))
	_check("f: with the inspector's action", saved.contains('swipe_left_action = &"ui_left"'))
	_check("f: without the reader", not saved.contains("reader"))


# --- driving the editor -----------------------------------------------------------------------


func _select(node: Node) -> void:
	EditorInterface.get_selection().clear()
	EditorInterface.edit_node(node)
	EditorInterface.get_selection().add_node(node)
	await _frames(10)


func _property(name: StringName) -> EditorProperty:
	for node in EditorInterface.get_inspector().find_children("*", "EditorProperty", true, false):
		if (node as EditorProperty).get_edited_property() == name:
			return node as EditorProperty
	return null


# Sets a value the way the inspector's own field does: the inspector makes the undoable step.
func _set_in_inspector(node: Node, name: StringName, value: Variant) -> void:
	var property := _property(name)
	if property == null:
		_check("the inspector shows %s" % name, false)
		return
	property.emit_changed(name, value)
	await _frames(5)
	if EditorInterface.get_inspector().get_edited_object() != node:
		await _select(node)


# Undo as a person does, with the editor's shortcut: the editor keeps its own list of every history's steps, and
# calling `UndoRedo.undo()` on a history directly leaves that list behind ("Inconsistent redo history").
func _editor_undo() -> void:
	await _press_z(false)
	await _frames(3)


func _press_z(shift: bool) -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_Z
	key.command_or_control_autoremap = true
	key.shift_pressed = shift
	key.pressed = true
	await _send(key)
	var up := key.duplicate() as InputEventKey
	up.pressed = false
	await _send(up)


func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _frames(2)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _check(what: String, ok: bool) -> void:
	if ok:
		_passes += 1
	else:
		_fails += 1
	print("%s %s" % ["PASS" if ok else "FAIL", what])


func _remove_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_remove_dir(path.path_join(sub))
	for file in dir.get_files():
		dir.remove(file)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
