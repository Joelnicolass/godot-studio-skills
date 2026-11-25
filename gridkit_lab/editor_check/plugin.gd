@tool
extends EditorPlugin

## Checks GridKit's brush in the real editor: it opens scenes, selects nodes, presses the bar's buttons, sends mouse
## events to the 3D view and reads the undo history and the files on disk. It does nothing at all unless the editor
## was started with the user argument `--gridkit-editor-check`:
##   godot --headless --editor --path gridkit_lab -- --gridkit-editor-check
## It prints one PASS or FAIL line per check, then GRIDKIT EDITOR CHECK PASS (n) or FAIL: k of n, and exits with 0 or 1.
## It works on copies in res://editor_check/tmp, which it deletes at the end.

const ARG := "--gridkit-editor-check"
const TMP := "res://editor_check/tmp"
const TIMEOUT_SECONDS := 150.0
const WATER := preload("res://addons/grid_kit/examples/minimal_3d/tiles/water.tscn")
const PLAIN := preload("res://addons/grid_kit/examples/minimal_3d/tiles/plain.tscn")
const BUTTONS: Array[String] = ["water", "plain", "Erase", "Add cells", "Remove cells", "Save shape as layout"]

var _passes := 0
var _fails := 0
var _done := false


func _enter_tree() -> void:
	if not OS.get_cmdline_user_args().has(ARG):
		return
	_run.call_deferred()


func _run() -> void:
	get_tree().create_timer(TIMEOUT_SECONDS).timeout.connect(_on_timeout)
	await _frames(30)
	_prepare()
	await _scan()
	await _check_scene_with_external_layout()
	await _check_scene_without_layout()
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
		print("GRIDKIT EDITOR CHECK PASS (%d)" % total)
	else:
		print("GRIDKIT EDITOR CHECK FAIL: %d of %d" % [_fails, total])
	get_tree().quit(0 if _fails == 0 else 1)


# --- the scenes -------------------------------------------------------------------------------


func _prepare() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP))
	_save_layout(TMP + "/ext.tres", &"plain")
	_save_layout(TMP + "/other.tres", &"plain")
	var ext := ResourceLoader.load(TMP + "/ext.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as GridLayout
	var other := ResourceLoader.load(TMP + "/other.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as GridLayout
	var root := _make_level(ext)
	var second := GridBoard.new()
	second.name = "Other"
	root.add_child(second)
	second.owner = root
	second.layout = other
	_save_scene(root, TMP + "/with_layout.tscn")
	_save_scene(_make_level(null), TMP + "/no_layout.tscn")


func _save_layout(path: String, terrain: StringName) -> void:
	var grid := HexGrid.hexagon(3)
	for cell in grid.cells():
		grid.set_value(cell, &"terrain", terrain)
	ResourceSaver.save(GridLayout.from_grid(grid), path)


func _make_level(layout: GridLayout) -> Node3D:
	var root := Node3D.new()
	root.name = "Level"
	var board := GridBoard.new()
	board.name = "Board"
	root.add_child(board)
	board.owner = root
	if layout != null:
		board.layout = layout
	else:
		board.radius = 3
	var view := GridView3D.new()
	view.name = "View"
	board.add_child(view)
	view.owner = root
	view.tiles = {&"water": WATER, &"plain": PLAIN}
	view.default_tile = PLAIN
	return root


func _save_scene(root: Node, path: String) -> void:
	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, path)
	root.free()


func _scan() -> void:
	var files := EditorInterface.get_resource_filesystem()
	files.scan()
	await _frames(5)
	while files.is_scanning():
		await _frames(2)


func _open(path: String) -> Node:
	EditorInterface.open_scene_from_path(path)
	await _frames(20)
	EditorInterface.set_main_screen_editor("3D")
	await _frames(10)
	return EditorInterface.get_edited_scene_root()


# --- the checks -------------------------------------------------------------------------------


func _check_scene_with_external_layout() -> void:
	var root := await _open(TMP + "/with_layout.tscn")
	var board := root.get_node(^"Board") as GridBoard
	var view := root.get_node(^"Board/View") as GridView3D
	await _check_bar(view, "a: view selected")
	await _check_bar(board, "b: board selected")
	var bar := _bar()
	var hit := _point(board, view, true)
	if hit.is_empty():
		_check("c: a cell under the viewport", false)
		return
	var cell: Vector2i = hit["cell"]
	var undo_redo := _history(board)
	_check("d: the layout is a file of its own", board.layout.resource_path.ends_with("ext.tres"))
	var other_path := TMP + "/other.tres"
	var other_before := FileAccess.get_file_as_string(other_path)
	var other_time := FileAccess.get_modified_time(other_path)
	await _paint_stroke(bar, "water", hit["at"])
	_check("c: the stroke painted the cell", board.get_value(cell, &"terrain") == &"water")
	_check("c: the history has 'Paint grid cells'", undo_redo.get_current_action_name() == "Paint grid cells")
	undo_redo.undo()
	await _frames(2)
	_check("c: undo gives the old value back", board.get_value(cell, &"terrain") == &"plain")
	undo_redo.redo()
	await _frames(2)
	_check("c: redo paints it again", board.get_value(cell, &"terrain") == &"water")
	_check("e: something is unsaved before saving", not _status("").is_empty())
	_check("e: and it is named for this scene", not _status(root.scene_file_path).is_empty())
	EditorInterface.save_scene()
	await _frames(10)
	var saved := ResourceLoader.load(TMP + "/ext.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as GridLayout
	_check(
		"d: the .tres on disk has the painted value", saved != null and saved.get_value(cell, &"terrain") == &"water"
	)
	_check(
		"d: another layout nobody touched was not written", FileAccess.get_file_as_string(other_path) == other_before
	)
	_check("d: nor its modified time", FileAccess.get_modified_time(other_path) == other_time)
	_check("e: nothing is unsaved after saving", _status("").is_empty())
	# Painting and undoing back to the start leaves nothing to save.
	var again_time := FileAccess.get_modified_time(TMP + "/ext.tres")
	await _paint_stroke(bar, "plain", hit["at"])
	undo_redo.undo()
	await _frames(2)
	_check("d: a stroke undone leaves the layout as saved", board.get_value(cell, &"terrain") == &"water")
	_check("e: so nothing is unsaved", _status("").is_empty())
	EditorInterface.save_scene()
	await _frames(10)
	_check("d: and the file is not written again", FileAccess.get_modified_time(TMP + "/ext.tres") == again_time)


func _check_scene_without_layout() -> void:
	var root := await _open(TMP + "/no_layout.tscn")
	var board := root.get_node(^"Board") as GridBoard
	var view := root.get_node(^"Board/View") as GridView3D
	_select(board)
	await _frames(10)
	var bar := _bar()
	var hit := _point(board, view, true)
	if hit.is_empty():
		_check("f: a cell under the viewport", false)
		return
	var cell: Vector2i = hit["cell"]
	var undo_redo := _history(board)
	await _paint_stroke(bar, "water", hit["at"])
	_check("f: the first stroke makes a layout", board.layout != null and board.get_value(cell, &"terrain") == &"water")
	_check("f: inside the scene, not a file", board.layout != null and board.layout.resource_path.is_empty())
	_check("f: nothing to write on its own", _status("").is_empty())
	EditorInterface.save_scene()
	await _frames(10)
	_check(
		"f: the scene on disk has the painted value",
		FileAccess.get_file_as_string(TMP + "/no_layout.tscn").contains("water")
	)
	undo_redo.undo()
	await _frames(2)
	_check("f: undoing the first stroke takes the layout out", board.layout == null)
	# The bar looks at the board a few times a second.
	await get_tree().create_timer(0.6).timeout
	var save := _button(_bar(), "Save shape as layout")
	_check("g: the save button is on without a layout", save != null and not save.disabled)
	save.pressed.emit()
	await _frames(2)
	_check("g: it made the layout", board.layout != null and board.layout.cells.size() == board.cells().size())
	_check("g: and the button is off", save.disabled)
	_check(
		"g: as one step: 'Save grid shape as layout'",
		undo_redo.get_current_action_name() == "Save grid shape as layout"
	)
	undo_redo.undo()
	await _frames(2)
	_check("g: undo takes it out", board.layout == null)
	# The bar looks at the board a few times a second.
	await get_tree().create_timer(0.6).timeout
	_check("g: and the button is back", not _button(_bar(), "Save shape as layout").disabled)
	var outside := _point(board, view, false)
	if outside.is_empty():
		_check("h: a point beside the board", false)
		return
	var new_cell: Vector2i = outside["cell"]
	await _paint_stroke(bar, "Add cells", outside["at"])
	_check("h: Add cells added a cell", board.has_cell(new_cell))
	undo_redo.undo()
	await _frames(2)
	_check("h: undo took it out", not board.has_cell(new_cell))
	await _paint_stroke(bar, "Remove cells", hit["at"])
	_check("h: Remove cells removed a cell", not board.has_cell(cell))
	undo_redo.undo()
	await _frames(2)
	_check("h: undo put it back", board.has_cell(cell))


func _check_bar(node: Node, label: String) -> void:
	_select(node)
	await _frames(10)
	var bar := _bar()
	_check("%s: the GridKit bar is visible" % label, bar != null and bar.is_visible_in_tree())
	var texts: Array[String] = []
	if bar != null:
		for button in bar.find_children("*", "Button", true, false):
			texts.append((button as Button).text)
	var same := texts.size() == BUTTONS.size()
	for text in BUTTONS:
		same = same and texts.has(text)
	_check("%s: a button per tile, Erase, Add cells, Remove cells, Save shape as layout" % label, same)


# --- driving the editor -----------------------------------------------------------------------


func _select(node: Node) -> void:
	EditorInterface.get_selection().clear()
	EditorInterface.edit_node(node)
	EditorInterface.get_selection().add_node(node)


func _bar() -> Control:
	return _find_bar(EditorInterface.get_base_control())


func _find_bar(node: Node) -> Control:
	if node is HBoxContainer:
		for child in node.get_children():
			if child is Label and (child as Label).text == "GridKit":
				return node as Control
	for child in node.get_children():
		var found := _find_bar(child)
		if found != null:
			return found
	return null


func _button(bar: Control, text: String) -> Button:
	if bar == null:
		return null
	for node in bar.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node as Button
	return null


func _history(board: Node) -> UndoRedo:
	var manager := EditorInterface.get_editor_undo_redo()
	return manager.get_history_undo_redo(manager.get_object_history_id(board))


# A screen point of the 3D view over a cell of the board (`on_board`) or beside it: {"at": point, "cell": cell}.
func _point(board: GridBoard, view: GridView3D, on_board: bool) -> Dictionary:
	var sub := EditorInterface.get_editor_viewport_3d(0)
	var camera := sub.get_camera_3d()
	var rect := (sub.get_parent() as Control).get_global_rect()
	for y in range(1, 20):
		for x in range(1, 20):
			var local := Vector2(rect.size.x * x / 20.0, rect.size.y * y / 20.0)
			var cell := view.cell_at_ray(camera.project_ray_origin(local), camera.project_ray_normal(local), false)
			if cell != CellGrid.NO_CELL and board.has_cell(cell) == on_board:
				return {"at": rect.position + local, "cell": cell}
	return {}


# Presses the bar's button `text` and sends press, move and release over `at`; then lets the button go.
func _paint_stroke(bar: Control, text: String, at: Vector2) -> void:
	var button := _button(bar, text)
	button.button_pressed = true
	await _frames(2)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	down.global_position = at
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	await _send(down)
	var move := InputEventMouseMotion.new()
	move.position = at + Vector2(1, 0)
	move.global_position = move.position
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	await _send(move)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = at + Vector2(1, 0)
	up.global_position = up.position
	await _send(up)
	button.button_pressed = false
	await _frames(2)


func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _frames(2)


func _status(for_scene: String) -> String:
	for node in get_tree().root.find_children("*", "EditorPlugin", true, false):
		var script := node.get_script() as Script
		if script != null and script.resource_path == "res://addons/grid_kit/plugin.gd":
			if node.has_method(&"_get_unsaved_status"):
				return node.call(&"_get_unsaved_status", for_scene)
	return ""


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
