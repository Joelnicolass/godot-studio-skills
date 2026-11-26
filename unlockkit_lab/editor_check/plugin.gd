@tool
extends EditorPlugin

## Checks UnlockKit in the real editor: it opens a copy of the example, reads the tree view the editor draws, edits
## entries through the editor's own undo history (as the inspector and the Scene dock do), undoes with the keyboard
## shortcut and saves. It does nothing at all unless the editor was started with the user argument
## `--unlockkit-editor-check`:
##   godot --headless --editor --path unlockkit_lab -- --unlockkit-editor-check
## It prints one PASS or FAIL line per check, then UNLOCKKIT EDITOR CHECK PASS (n) or FAIL: k of n, and exits with 0
## or 1. It works on a copy in res://editor_check/tmp, which it deletes at the end.

const ARG := "--unlockkit-editor-check"
const TMP := "res://editor_check/tmp"
const EXAMPLE := "res://addons/unlock_kit/examples/minimal/minimal.tscn"
const TIMEOUT_SECONDS := 120.0
const ENTRY_COUNT := 9

var _passes := 0
var _fails := 0
var _done := false
var _draws := 0
var _rebuilds := 0


func _enter_tree() -> void:
	if not OS.get_cmdline_user_args().has(ARG):
		return
	_run.call_deferred()


func _run() -> void:
	get_tree().create_timer(TIMEOUT_SECONDS).timeout.connect(_on_timeout)
	await _frames(30)
	var path := TMP + "/minimal.tscn"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP))
	DirAccess.copy_absolute(ProjectSettings.globalize_path(EXAMPLE), ProjectSettings.globalize_path(path))
	await _scan()
	EditorInterface.open_scene_from_path(path)
	await _frames(20)
	EditorInterface.set_main_screen_editor("2D")
	await _frames(10)
	var root := EditorInterface.get_edited_scene_root()
	var tree := root.get_node_or_null(^"%Tree") as UnlockTree if root != null else null
	var view := root.get_node_or_null(^"%View") as UnlockTreeView if root != null else null
	_check("a: the example opens with its tree and its view", tree != null and view != null)
	if tree != null and view != null:
		view.draw.connect(func() -> void: _draws += 1)
		tree.rebuilt.connect(func() -> void: _rebuilds += 1)
		await _check_drawn(tree, view)
		await _check_edit_and_undo(tree, view)
		await _check_rename(tree)
		await _check_cycle_warning(tree)
		await _check_save(tree, path)
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
		print("UNLOCKKIT EDITOR CHECK PASS (%d)" % total)
	else:
		print("UNLOCKKIT EDITOR CHECK FAIL: %d of %d" % [_fails, total])
	get_tree().quit(0 if _fails == 0 else 1)


# --- the checks -------------------------------------------------------------------------------


# What a person sees on opening the scene: every box drawn, the start state, no warnings.
func _check_drawn(tree: UnlockTree, view: UnlockTreeView) -> void:
	_draws = 0
	view.queue_redraw()
	await _frames(3)
	_check("b: the view draws in the editor", view.is_visible_in_tree() and _draws > 0)
	var boxes := 0
	for id in tree.graph.ids():
		if view.box_rect(id).has_area():
			boxes += 1
	_check("b: a box per entry (%d)" % boxes, boxes == ENTRY_COUNT)
	_check("b: its minimum size fits them", view.get_combined_minimum_size().x >= view.box_rect(&"Aqueduct").end.x)
	_check("b: the editor shows the start: only Farming", tree.unlocked_ids() == ([&"Farming"] as Array[StringName]))
	_check("b: Market needs one of two", tree.requires_any(&"Market").size() == 2)
	var warnings := tree._get_configuration_warnings().size() + view._get_configuration_warnings().size()
	for item in tree.entries():
		warnings += item._get_configuration_warnings().size()
	_check("b: no warnings on the tree, the view or an entry", warnings == 0)


# Inspector edits of an entry reach the graph and the view at once, and the editor's undo takes them back.
func _check_edit_and_undo(tree: UnlockTree, view: UnlockTreeView) -> void:
	var market := tree.entry(&"Market")
	var irrigation := tree.entry(&"Irrigation")
	var masonry := tree.entry(&"Masonry")
	var auto := view.box_rect(&"Market").position
	_draws = 0
	_rebuilds = 0
	_set_value(market, &"view_position", Vector2(700, 300))
	await _frames(3)
	_check("c: view_position moves the box", view.box_rect(&"Market").position == Vector2(700, 300))
	_check("c: the tree rebuilt once and the view redrew", _rebuilds == 1 and _draws > 0)
	_check("c: and the minimum size grew with it", view.get_combined_minimum_size().x >= 700.0 + view.box_size.x)
	await _editor_undo()
	await _frames(3)
	_check("c: Ctrl+Z puts the box back in its column", view.box_rect(&"Market").position == auto)
	_set_value(irrigation, &"cost", {&"points": 7} as Dictionary[StringName, int])
	await _frames(3)
	_check("d: a new cost reaches the graph", _points(tree, &"Irrigation") == 7)
	var tip := view._get_tooltip(view.box_rect(&"Irrigation").get_center())
	_check("d: and the box's tooltip", tip.contains("7 points"))
	await _editor_undo()
	await _frames(3)
	_check("d: Ctrl+Z gives the old cost back", _points(tree, &"Irrigation") == 2)
	await _editor_redo()
	await _frames(3)
	_check("d: Ctrl+Shift+Z sets it again", _points(tree, &"Irrigation") == 7)
	_set_value(masonry, &"start_unlocked", true)
	await _frames(3)
	_check("e: start_unlocked shows at once", tree.is_unlocked(&"Masonry") and tree.can_unlock(&"Walls"))
	await _editor_undo()
	await _frames(3)
	_check("e: and undoing it locks it again", not tree.is_unlocked(&"Masonry"))


# Renaming a node in the Scene dock renames the entry: its id comes from the name, and the links follow.
func _check_rename(tree: UnlockTree) -> void:
	var pottery := tree.entry(&"Pottery")
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Rename Node")
	undo_redo.add_do_method(pottery, &"set_name", "Ceramics")
	undo_redo.add_undo_method(pottery, &"set_name", "Pottery")
	undo_redo.commit_action()
	await _frames(3)
	_check("f: the renamed entry has the new id", tree.graph.has(&"Ceramics") and not tree.graph.has(&"Pottery"))
	_check("f: Market's requires_any follows it", tree.requires_any(&"Market").has(&"Ceramics"))
	await _editor_undo()
	await _frames(3)
	_check("f: undo gives the old name back", tree.graph.has(&"Pottery") and tree.entry(&"Pottery") == pottery)


# A link that closes a circle shows warnings on the entries and the tree, and undoing it clears them.
func _check_cycle_warning(tree: UnlockTree) -> void:
	var farming := tree.entry(&"Farming")
	var aqueduct := tree.entry(&"Aqueduct")
	_set_value(farming, &"requires", [aqueduct] as Array[Node])
	await _frames(3)
	var circle := 0
	for id: StringName in [&"Farming", &"Irrigation", &"Aqueduct"]:
		for line in tree.entry(id)._get_configuration_warnings():
			if line.contains("circle"):
				circle += 1
	_check("g: the three entries of the circle warn", circle == 3)
	_check("g: and so does the tree", tree._get_configuration_warnings().size() == 1)
	await _editor_undo()
	await _frames(3)
	_check("g: undo clears them", tree._get_configuration_warnings().is_empty())


# The editor's own save writes the entries' values to the scene file.
func _check_save(tree: UnlockTree, path: String) -> void:
	_check("h: the cost is still 7 before saving", _points(tree, &"Irrigation") == 7)
	EditorInterface.save_scene_as(path, false)
	await _frames(10)
	var text := FileAccess.get_file_as_string(path)
	_check("h: the saved scene has the new cost", text.contains('&"points": 7'))
	_check("h: and still Market's requires_any", text.contains("requires_any = ["))


func _points(tree: UnlockTree, id: StringName) -> int:
	return tree.cost_of(id).get(&"points", 0)


# --- driving the editor -----------------------------------------------------------------------


# A property change as the inspector makes it: one step in the scene's undo history.
func _set_value(node: Node, property: StringName, value: Variant) -> void:
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Set %s" % property)
	undo_redo.add_do_property(node, property, value)
	undo_redo.add_undo_property(node, property, node.get(property))
	undo_redo.commit_action()


func _scan() -> void:
	var files := EditorInterface.get_resource_filesystem()
	files.scan()
	await _frames(5)
	while files.is_scanning():
		await _frames(2)


# Undo and redo as a person does, with the editor's shortcut: the editor keeps its own list of every history's
# steps, and calling `UndoRedo.undo()` on a history directly leaves that list behind ("Inconsistent redo history").
func _editor_undo() -> void:
	await _press_z(false)


func _editor_redo() -> void:
	await _press_z(true)


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
