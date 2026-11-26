@tool
extends EditorPlugin

## Checks StatKit's "Values" group in the real editor: it opens the example, selects the StatBlock and reads the values
## the inspector shows; then it opens a copy, edits a modifier resource, the limits, the bases and the start modifiers
## the way the inspector does (through the editor's undo history), undoes with the shortcut and saves. It does nothing
## at all unless the editor was started with the user argument `--statkit-editor-check`:
##   godot --headless --editor --path statkit_lab -- --statkit-editor-check
## It prints one PASS or FAIL line per check, then STATKIT EDITOR CHECK PASS (n) or FAIL: k of n, and exits with 0 or 1.
## It never writes the example's files: the edits go to copies in res://editor_check/tmp, which it deletes at the end.

const ARG := "--statkit-editor-check"
const TMP := "res://editor_check/tmp"
const EXAMPLE := "res://addons/stat_kit/examples/minimal"
const TIMEOUT_SECONDS := 120.0
# Longer than the inspector's own refresh (docs/property_editor/auto_refresh_interval).
const REFRESH_SECONDS := 0.8

var _passes := 0
var _fails := 0
var _done := false


func _enter_tree() -> void:
	if not OS.get_cmdline_user_args().has(ARG):
		return
	_run.call_deferred()


func _run() -> void:
	var armed := get_tree().create_timer(TIMEOUT_SECONDS).timeout.connect(_on_timeout)
	_check("arms its own timeout", armed == OK)
	await _frames(30)
	var before := _fingerprint(EXAMPLE)
	await _check_example()
	_prepare()
	await _scan()
	await _check_edits()
	_check("i: the example's files on disk are untouched", _fingerprint(EXAMPLE) == before)
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
		print("STATKIT EDITOR CHECK PASS (%d)" % total)
	else:
		print("STATKIT EDITOR CHECK FAIL: %d of %d" % [_fails, total])
	get_tree().quit(0 if _fails == 0 else 1)


# --- the checks -------------------------------------------------------------------------------


# The example as it is on disk: the Hero shows its final values with nothing running.
func _check_example() -> void:
	var root := await _open(EXAMPLE + "/minimal.tscn")
	var hero: StatBlock = null
	if root != null:
		hero = root.get_node_or_null(^"Hero") as StatBlock
	if hero == null:
		_check("a: the example opens with its Hero", false)
		return
	_select(hero)
	await _frames(10)
	_check_shown("a", "value_attack", "Attack", 7.0)
	_check_shown("a", "value_defense", "Defense", 4.0)
	_check_shown("a", "value_moves", "Moves", 3.0)
	_check("a: the example's Hero has no warnings", hero._get_configuration_warnings().is_empty())


# A copy, edited the way a person edits it in the inspector.
func _check_edits() -> void:
	var root := await _open(TMP + "/hero.tscn")
	var block: StatBlock = null
	if root != null:
		block = root.get_node_or_null(^"Hero") as StatBlock
	if block == null:
		_check("b: the copy opens with its Hero", false)
		return
	_select(block)
	await _frames(10)
	_check_shown("b", "value_attack", "Attack", 10.5)
	var sword := block.start_modifiers[0]
	_change(sword, &"amount", 3.0)
	await _wait_refresh()
	_check_shown("c: an edit inside sword.tres", "value_attack", "Attack", 12.0)
	await _editor_undo()
	await _wait_refresh()
	_check("d: the shortcut undoes the edit of sword.tres", is_equal_approx(sword.amount, 2.0))
	_check_shown("d", "value_attack", "Attack", 10.5)
	var maxs: Dictionary[StringName, float] = {&"attack": 10.0}
	_change(block, &"max_values", maxs)
	await _wait_refresh()
	_check_shown("e: max_values", "value_attack", "Attack", 10.0)
	var bases: Dictionary[StringName, float] = {&"attack": 5.0, &"defense": 4.0, &"luck": 1.0}
	_change(block, &"base_values", bases)
	await _wait_refresh()
	_check_shown("f: a new stat in base_values", "value_luck", "Luck", 1.0)
	var list := block.start_modifiers.duplicate()
	list.append(StatModifier.times(&"defense", 0, &"curse"))
	_change(block, &"start_modifiers", list)
	await _wait_refresh()
	var warned := false
	for line in block._get_configuration_warnings():
		warned = warned or line.contains("by 0")
	_check("g: a MUL of 0 in start_modifiers warns", warned)
	_check_shown("g", "value_defense", "Defense", 0.0)
	await _editor_undo()
	await _wait_refresh()
	_check("g: the shortcut takes it out again", block.start_modifiers.size() == 2)
	_check_shown("g", "value_defense", "Defense", 4.0)
	_save_edited_scene()
	await _frames(10)
	var text := FileAccess.get_file_as_string(TMP + "/hero.tscn")
	_check("h: the Values group is not saved in the scene", not text.is_empty() and not text.contains("value_"))
	_check("h: the inspector values are", text.contains("max_values") and text.contains('&"luck"'))


# One read-only property of the Values group, as the inspector shows it: its label, that it is read only, the number.
func _check_shown(label: String, property: String, title: String, expected: float) -> void:
	var editor := _find_property(EditorInterface.get_inspector(), property)
	if editor == null:
		_check("%s: the inspector shows %s" % [label, property], false)
		return
	var shown := _number_in(editor)
	_check(
		"%s: Values shows %s = %s, read only (shows %s %s)" % [label, title, expected, editor.label, shown],
		editor.label == title and editor.read_only and is_equal_approx(shown, expected)
	)


# --- the files --------------------------------------------------------------------------------


func _prepare() -> void:
	var results: Array[Error] = []
	results.append(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP)))
	results.append(ResourceSaver.save(StatModifier.plus(&"attack", 2, &"sword"), TMP + "/sword.tres"))
	results.append(ResourceSaver.save(StatModifier.percent(&"attack", 0.5, &"ring"), TMP + "/ring.tres"))
	var root := Node.new()
	root.name = "Card"
	var block := StatBlock.new()
	block.name = "Hero"
	root.add_child(block)
	block.owner = root
	block.base_values = {&"attack": 5.0, &"defense": 4.0}
	var start: Array[StatModifier] = [
		ResourceLoader.load(TMP + "/sword.tres") as StatModifier,
		ResourceLoader.load(TMP + "/ring.tres") as StatModifier
	]
	block.start_modifiers = start
	var packed := PackedScene.new()
	results.append(packed.pack(root))
	results.append(ResourceSaver.save(packed, TMP + "/hero.tscn"))
	root.free()
	_check(
		"b: the copies are written to %s (%s)" % [TMP, results],
		results.all(func(code: Error) -> bool: return code == OK)
	)


# Every file under `dir` with its contents' hash and modified time.
func _fingerprint(dir_path: String) -> Dictionary:
	var found := {}
	for sub in DirAccess.get_directories_at(dir_path):
		found.merge(_fingerprint(dir_path.path_join(sub)))
	for file in DirAccess.get_files_at(dir_path):
		var path := dir_path.path_join(file)
		found[path] = "%s %d" % [FileAccess.get_md5(path), FileAccess.get_modified_time(path)]
	return found


# The editor's own save, without the thumbnail: headless has no viewport texture to make one from.
func _save_edited_scene() -> void:
	EditorInterface.save_scene_as(EditorInterface.get_edited_scene_root().scene_file_path, false)


func _scan() -> void:
	var files := EditorInterface.get_resource_filesystem()
	files.scan()
	await _frames(5)
	while files.is_scanning():
		await _frames(2)


func _open(path: String) -> Node:
	EditorInterface.open_scene_from_path(path)
	await _frames(20)
	return EditorInterface.get_edited_scene_root()


# --- driving the editor -----------------------------------------------------------------------


func _select(node: Node) -> void:
	EditorInterface.get_selection().clear()
	EditorInterface.edit_node(node)
	EditorInterface.get_selection().add_node(node)


# A change the way the inspector makes it: one action in the editor's undo history.
func _change(object: Object, property: StringName, new_value: Variant) -> void:
	var history := get_undo_redo()
	history.create_action("Set %s" % property)
	history.add_do_property(object, property, new_value)
	history.add_undo_property(object, property, object.get(property))
	history.commit_action()


# Undo as a person does, with the editor's shortcut: the editor keeps its own list of every history's steps, and
# calling `UndoRedo.undo()` on a history directly leaves that list behind.
func _editor_undo() -> void:
	await _press_z()


func _press_z() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_Z
	key.command_or_control_autoremap = true
	key.pressed = true
	await _send(key)
	var up := key.duplicate() as InputEventKey
	up.pressed = false
	await _send(up)


func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _frames(2)


func _wait_refresh() -> void:
	await get_tree().create_timer(REFRESH_SECONDS).timeout
	await _frames(2)


func _find_property(node: Node, property: String) -> EditorProperty:
	var editor := node as EditorProperty
	if editor != null and editor.get_edited_property() == StringName(property):
		return editor
	for child in node.get_children():
		var hit := _find_property(child, property)
		if hit != null:
			return hit
	return null


# The number a float property editor shows (its spin slider), or NAN when it has none.
func _number_in(editor: EditorProperty) -> float:
	var sliders := editor.find_children("*", "EditorSpinSlider", true, false)
	return (sliders[0] as EditorSpinSlider).value if not sliders.is_empty() else NAN


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
		if dir.remove(file) != OK:
			push_warning("StatKit editor check: could not delete %s" % path.path_join(file))
	if DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) != OK:
		push_warning("StatKit editor check: could not delete %s" % path)
