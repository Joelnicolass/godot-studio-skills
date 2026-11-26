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
const BUTTONS: Array[String] = [
	"water", "plain", "Erase", "Add cells", "Remove cells", "Raise", "Lower", "Set height", "Save shape as layout"
]

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
	await _check_heights()
	await _check_fog()
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
	_save_scene(_make_level(null), TMP + "/heights.tscn")


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


# The editor's own save, without the thumbnail: headless has no viewport texture to make one from (the engine
# reports "Parameter t is null" in texture_2d_get when it tries).
func _save_edited_scene() -> void:
	EditorInterface.save_scene_as(EditorInterface.get_edited_scene_root().scene_file_path, false)


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
	await _editor_undo()
	await _frames(2)
	_check("c: undo gives the old value back", board.get_value(cell, &"terrain") == &"plain")
	await _editor_redo()
	await _frames(2)
	_check("c: redo paints it again", board.get_value(cell, &"terrain") == &"water")
	_check("e: something is unsaved before saving", not _status("").is_empty())
	_check("e: and it is named for this scene", not _status(root.scene_file_path).is_empty())
	_save_edited_scene()
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
	await _editor_undo()
	await _frames(2)
	_check("d: a stroke undone leaves the layout as saved", board.get_value(cell, &"terrain") == &"water")
	_check("e: so nothing is unsaved", _status("").is_empty())
	_save_edited_scene()
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
	_save_edited_scene()
	await _frames(10)
	_check(
		"f: the scene on disk has the painted value",
		FileAccess.get_file_as_string(TMP + "/no_layout.tscn").contains("water")
	)
	await _editor_undo()
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
	await _editor_undo()
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
	await _editor_undo()
	await _frames(2)
	_check("h: undo took it out", not board.has_cell(new_cell))
	await _paint_stroke(bar, "Remove cells", hit["at"])
	_check("h: Remove cells removed a cell", not board.has_cell(cell))
	await _editor_undo()
	await _frames(2)
	_check("h: undo put it back", board.has_cell(cell))


# The height brushes on a board with no layout and no height key: the stroke, its undo, picking a raised cell by its
# top through the 3D view's own input, and what the saved scene holds.
func _check_heights() -> void:
	var path := TMP + "/heights.tscn"
	var root := await _open(path)
	var board := root.get_node(^"Board") as GridBoard
	var view := root.get_node(^"Board/View") as GridView3D
	_select(board)
	await _frames(10)
	var bar := _bar()
	var boxes := bar.find_children("*", "SpinBox", true, false)
	_check("i: the bar has a box for the step and one for the height", boxes.size() == 2)
	var hit := _middle(board, view)
	if hit.is_empty() or boxes.size() != 2:
		_check("i: a cell in the middle of the viewport", false)
		return
	var cell: Vector2i = hit["cell"]
	var undo_redo := _history(board)
	var tile := view.tile_at(cell)
	await _paint_stroke(bar, "Raise", hit["at"])
	_check("i: Raise gave the board a height key", board.height_key == &"height")
	_check("i: and the cell one step of height", board.get_value(cell, &"height") == 1)
	_check("i: saved in a layout", board.layout != null and board.layout.get_value(cell, &"height") == 1)
	_check("i: as one step: 'Paint grid cells'", undo_redo.get_current_action_name() == "Paint grid cells")
	await _frames(2)
	_check("i: the tile went up", view.tile_at(cell) != null and view.tile_at(cell).position.y == 1.0)
	await _editor_undo()
	await _frames(3)
	_check("j: undo takes the height key and the layout out", board.height_key == &"" and board.layout == null)
	_check("j: and the cell is on the ground", board.get_value(cell, &"height") == null)
	_check("j: with its tile", view.tile_at(cell) != null and view.tile_at(cell).position.y == 0.0)
	await _editor_redo()
	await _frames(3)
	_check("j: redo raises it again", board.height_key == &"height" and board.get_value(cell, &"height") == 1)
	_check("j: and the layout is back with it", board.layout != null and board.layout.get_value(cell, &"height") == 1)
	_check("j: the same tile all along, not a new one", tile != null and view.tile_at(cell) == tile)
	(boxes[1] as SpinBox).value = 1.5
	await _paint_stroke(bar, "Set height", _screen(view, board.cell_to_position(cell)))
	_check("k: Set height wrote the number of its box", board.get_value(cell, &"height") == 1.5)
	# The top of the raised cell is somewhere else on the screen: on the plane, that point is another cell.
	var top := _screen(view, board.cell_to_position(cell))
	var sub := EditorInterface.get_editor_viewport_3d(0)
	var rect := (sub.get_parent() as Control).get_global_rect()
	_check("k: the top of the raised cell is in the viewport", rect.has_point(top))
	var camera := sub.get_camera_3d()
	var origin := camera.project_ray_origin(top - rect.position)
	var normal := camera.project_ray_normal(top - rect.position)
	var ground: Variant = Plane(view.global_basis.y.normalized(), view.global_position).intersects_ray(origin, normal)
	var under := board.position_to_any_cell(view.to_local(ground as Vector3)) if ground != null else CellGrid.NO_CELL
	_check("k: on the plane that point is another cell", under != cell)
	_check("k: the view picks the raised cell there", view.cell_at_ray(origin, normal) == cell)
	(boxes[0] as SpinBox).value = 0.5
	await _paint_stroke(bar, "Raise", top)
	_check("k: and so does the brush: Raise by 0.5 lifts it to 2", board.get_value(cell, &"height") == 2)
	await _editor_undo()
	await _frames(2)
	_check("k: undo lowers it to 1.5", board.get_value(cell, &"height") == 1.5)
	await _editor_redo()
	await _frames(2)
	_save_edited_scene()
	await _frames(10)
	var packed := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var saved := packed.instantiate() if packed != null else null
	var saved_board := saved.get_node(^"Board") as GridBoard if saved != null else null
	_check("l: the scene on disk has the height key", saved_board != null and saved_board.height_key == &"height")
	_check(
		"l: and the height, in its layout",
		saved_board != null and saved_board.layout != null and saved_board.layout.get_value(cell, &"height") == 2
	)
	_check(
		"l: a board loaded from it stands the cell there",
		saved_board != null and saved_board.cell_to_position(cell).y == 2.0
	)
	if saved != null:
		saved.free()


# GridFog in the real editor: it does not cover the map, Preview shows the fog for a few seconds and gives every tile
# back, and nothing of it is saved with the scene.
func _check_fog() -> void:
	var root := await _open(TMP + "/no_layout.tscn")
	var view := root.get_node(^"Board/View") as GridView3D
	var fog := GridFog.new()
	fog.name = "Fog"
	view.add_child(fog)
	fog.owner = root
	await _frames(10)
	var caps := fog.get_child(0, true) as MultiMeshInstance3D
	var middle := view.tile_at(Vector2i.ZERO)
	var rim := view.tile_at(Vector2i(3, 0))
	_check("m: in the editor the fog covers nothing", caps.multimesh.instance_count == 0 and rim.visible)
	fog.preview_button.call()
	await _frames(5)
	_check("m: Preview covers the rim", caps.multimesh.instance_count > 0 and not rim.visible)
	_check("m: and leaves the middle in sight", middle.visible)
	await get_tree().create_timer(4.5).timeout
	await _frames(5)
	_check("m: after a few seconds every tile is back", caps.multimesh.instance_count == 0 and rim.visible)
	_save_edited_scene()
	await _frames(10)
	var saved := FileAccess.get_file_as_string(TMP + "/no_layout.tscn")
	_check("m: the saved scene has the fog node", saved.contains("GridFog") or saved.contains("grid_fog.gd"))
	_check(
		"m: and none of its caps or the hidden tiles",
		not saved.contains("MultiMesh") and not saved.contains("visible = false")
	)


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
	_check("%s: a button per tile, Erase, Add and Remove cells, the heights, Save shape as layout" % label, same)


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


# The cell under the middle of the 3D view, if it is on the board (or else any cell of it): {"at": point, "cell": cell}.
func _middle(board: GridBoard, view: GridView3D) -> Dictionary:
	var sub := EditorInterface.get_editor_viewport_3d(0)
	var camera := sub.get_camera_3d()
	var rect := (sub.get_parent() as Control).get_global_rect()
	var local := rect.size * 0.5
	var cell := view.cell_at_ray(camera.project_ray_origin(local), camera.project_ray_normal(local))
	if cell == CellGrid.NO_CELL:
		return _point(board, view, true)
	return {"at": rect.position + local, "cell": cell}


# Where a point of the view's local space is on the screen.
func _screen(view: GridView3D, local: Vector3) -> Vector2:
	var sub := EditorInterface.get_editor_viewport_3d(0)
	var rect := (sub.get_parent() as Control).get_global_rect()
	return rect.position + sub.get_camera_3d().unproject_position(view.to_global(local))


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
