@tool
extends EditorPlugin

## Checks DiceKit in the real editor: it opens the example, looks at the tray's dice in the 3D view, edits the roller
## through the inspector (rng_seed, count, and undo with the shortcut), presses the inspector's Roll button and reads
## last_result. It does nothing at all unless the editor was started with the user argument `--dicekit-editor-check`:
##   godot --headless --editor --path dicekit_lab -- --dicekit-editor-check
## It prints one PASS or FAIL line per check, then DICEKIT EDITOR CHECK PASS (n) or FAIL: k of n, and exits with 0 or 1.
## It never saves the example: the one save is a copy in res://editor_check/tmp, which it deletes at the end.

const ARG := "--dicekit-editor-check"
const TMP := "res://editor_check/tmp"
const EXAMPLE := "res://addons/dice_kit/examples/minimal/minimal.tscn"
const EXAMPLE_DIE := "res://addons/dice_kit/examples/minimal/attack_die.tres"
const TIMEOUT_SECONDS := 120.0
# What the example's die rolls with rng_seed 7, first and second (the kit's test_examples checks the first too).
const SEED_7_FIRST: Array[int] = [5, 1, 4]
const SEED_7_SECOND: Array[int] = [5, 3, 5]

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
	for path: String in [EXAMPLE, EXAMPLE_DIE]:
		_on_disk[path] = FileAccess.get_file_as_string(path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP))
	await _check_example()
	for path in _on_disk:
		_check(
			"the example on disk is untouched: %s" % path.get_file(),
			FileAccess.get_file_as_string(path) == _on_disk[path]
		)
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
		print("DICEKIT EDITOR CHECK PASS (%d)" % total)
	else:
		print("DICEKIT EDITOR CHECK FAIL: %d of %d" % [_fails, total])
	get_tree().quit(0 if _fails == 0 else 1)


# --- the checks -------------------------------------------------------------------------------


func _check_example() -> void:
	EditorInterface.open_scene_from_path(EXAMPLE)
	await _frames(20)
	EditorInterface.set_main_screen_editor("3D")
	await _frames(10)
	var root := EditorInterface.get_edited_scene_root()
	var roller := root.get_node_or_null(^"%Roller") as DiceRoller
	var tray := root.get_node_or_null(^"%Tray") as DiceTray3D
	_check("a: the example has its roller and its tray", roller != null and tray != null)
	if roller == null or tray == null:
		return
	_check("a: the roller has no warnings", roller._get_configuration_warnings().is_empty())
	_check("b: the tray shows the roller's 3 dice at rest", tray.dice_shown() == 3 and tray.shown_roll == null)
	_check("b: first face up", tray.face_on_top(0) == roller.die.faces[0])
	_check(
		"b: in the 3D view's world", tray.get_world_3d() == EditorInterface.get_editor_viewport_3d(0).find_world_3d()
	)
	var first_die := tray.get_child(0, true) as Node3D
	_check("b: as nodes of the tray, visible", first_die != null and first_die.is_visible_in_tree())
	_check("b: and not part of the scene", tray.get_child_count() == 0 and first_die.owner == null)
	_check("b: nothing runs every frame at rest", not tray.is_processing())
	await _select(roller)
	_check("c: the inspector has the Roll button", _roll_button() != null and _roll_button().is_visible_in_tree())
	var result := _last_result()
	_check("c: last_result is shown, read only", result != null and result.read_only)
	_check("c: it says to press Roll", _shown_text(result) == "(press Roll)")
	await _set_in_inspector(roller, &"rng_seed", 7)
	_check("d: rng_seed was set through the inspector", roller.rng_seed == 7)
	await _press_roll()
	_check("d: Roll rolled count dice", roller.last_roll != null and roller.last_roll.size() == 3)
	_check("d: seed 7: crit, hit, blank", roller.last_roll != null and roller.last_roll.indices == SEED_7_FIRST)
	_check("d: last_result shows it", _shown_text(_last_result()) == roller.last_roll.describe())
	_check("e: the tray tumbles in the 3D view", tray.is_tumbling() and tray.is_processing())
	await _settle(tray)
	_check("e: and lands on the faces that came up", _tops_match(tray, roller.last_roll))
	_check("e: then stops running", not tray.is_processing())
	await _press_roll()
	var second := roller.last_roll.indices
	await _set_in_inspector(roller, &"rng_seed", 7)
	await _press_roll()
	_check("f: rng_seed 7 again: the same first roll", roller.last_roll.indices == SEED_7_FIRST)
	_check("f: after a second roll that went on with the sequence", second == SEED_7_SECOND)
	await _settle(tray)
	await _set_in_inspector(roller, &"count", 2)
	_check("g: count 2 in the inspector: 2 dice at rest at once", tray.dice_shown() == 2 and tray.shown_roll == null)
	await _editor_undo()
	_check("g: undo with the shortcut: count 3 and 3 dice", roller.count == 3 and tray.dice_shown() == 3)
	var copy := TMP + "/minimal_copy.tscn"
	EditorInterface.save_scene_as(copy, false)
	await _frames(10)
	var saved := FileAccess.get_file_as_string(copy)
	_check("h: a copy of the scene was saved", saved.contains("DiceRoller") or saved.contains("dice_roller.gd"))
	_check("h: with the inspector's rng_seed", saved.contains("rng_seed = 7"))
	_check("h: without last_result", not saved.contains("last_result"))
	_check("h: without the tray's dice", not saved.contains("Label3D") and not saved.contains("BoxMesh"))


# --- driving the editor -----------------------------------------------------------------------


func _select(node: Node) -> void:
	EditorInterface.get_selection().clear()
	EditorInterface.edit_node(node)
	EditorInterface.get_selection().add_node(node)
	await _frames(10)
	await _unfold()


# Opens the Try it group when it is folded, as a person does: a click on its header.
func _unfold() -> void:
	var button := _roll_button()
	if button == null or button.is_visible_in_tree():
		return
	for node in EditorInterface.get_inspector().find_children("*", "Container", true, false):
		var section := node as Control
		if section.get_class() == "EditorInspectorSection" and section.is_ancestor_of(button):
			await _click(section.global_position + Vector2(12, 6))
			return


func _click(at: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	down.global_position = at
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	await _send(down)
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	up.button_mask = 0
	await _send(up)


func _roll_button() -> Button:
	for node in EditorInterface.get_inspector().find_children("*", "Button", true, false):
		if (node as Button).text == "Roll":
			return node as Button
	return null


func _property(name: StringName) -> EditorProperty:
	for node in EditorInterface.get_inspector().find_children("*", "EditorProperty", true, false):
		if (node as EditorProperty).get_edited_property() == name:
			return node as EditorProperty
	return null


func _last_result() -> EditorProperty:
	return _property(&"last_result")


func _shown_text(property: EditorProperty) -> String:
	if property == null:
		return ""
	for node in property.find_children("*", "LineEdit", true, false):
		return (node as LineEdit).text
	return ""


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
	await _unfold()


func _press_roll() -> void:
	var button := _roll_button()
	if button == null:
		_check("the Roll button is there", false)
		return
	button.pressed.emit()
	await _frames(5)
	await _unfold()


func _settle(tray: DiceTray3D) -> void:
	var start := Time.get_ticks_msec()
	while tray.is_tumbling() and Time.get_ticks_msec() - start < 5000:
		await _frames(1)
	await _frames(2)


func _tops_match(tray: DiceTray3D, roll: DiceRoll) -> bool:
	var faces := roll.faces
	var same := tray.dice_shown() == faces.size()
	for slot in faces.size():
		same = same and tray.face_on_top(slot) == faces[slot]
	return same


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
