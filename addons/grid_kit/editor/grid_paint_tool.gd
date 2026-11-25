@tool
extends Node

## The brush bar of GridKit and what it does in the 3D view: turns the mouse into cells for a GridStroke and puts each
## stroke in the editor's undo history as one step. The bar has a toggle per tile of the selected view (it paints
## `view.value_key` with that tile), Erase, Add cells and Remove cells, and three for the heights of the cells
## (`board.height_key`): Raise and Lower move each cell of a stroke one step (Shift swaps them) and Set height writes
## the number next to it. None on: the editor behaves as usual.

const GridStroke := preload("res://addons/grid_kit/editor/grid_stroke.gd")
const NO_TOOL := -1
const MARKER_LIFT := 0.04
const POLL_SECONDS := 0.25

var _bar: HBoxContainer
var _tile_buttons := HBoxContainer.new()
var _group := ButtonGroup.new()
var _board: GridBoard
var _view: GridView3D
var _tool := NO_TOOL
var _tile: StringName
var _current_button: Button
var _tiles_seen: Array = []
var _poll := 0.0
var _stroke := GridStroke.new()
var _marker := RID()
var _marker_mesh := ArrayMesh.new()
var _marker_material := StandardMaterial3D.new()
var _marker_key := ""
var _marker_scenario := RID()
# Tests put a stand-in for the editor's undo history here.
var _history: Object
var _save_button: Button
var _step_box: SpinBox
var _height_box: SpinBox
# The layouts that live in their own file and that a stroke touched: `{layout: {"saved": text, "scene": path}}`.
var _watched: Dictionary = {}


func _init() -> void:
	_group.allow_unpress = true
	_marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_material.no_depth_test = true
	_marker_material.render_priority = 1
	set_process(false)


func _exit_tree() -> void:
	_free_marker()


## The bar for the plugin to place on top of the 3D view (built on the first call).
func bar() -> HBoxContainer:
	if _bar == null:
		_build_bar()
	return _bar


## Starts editing `object`: a GridBoard (its first GridView3D child draws it) or a GridView3D. Anything else: nothing.
func edit(object: Object) -> void:
	if _stroke.is_active():
		_end_stroke()
	_select_tool(NO_TOOL, &"")
	_board = null
	_view = null
	if object is GridBoard:
		_board = object as GridBoard
		for child in _board.get_children():
			if child is GridView3D:
				_view = child as GridView3D
				break
	elif object is GridView3D:
		_view = object as GridView3D
		_board = _view.board()
	if _board == null or _view == null:
		_board = null
		_view = null
	_rebuild_tile_buttons()
	_hide_marker()
	_refresh_save_button()


func set_visible(visible: bool) -> void:
	bar().visible = visible
	set_process(visible)
	if not visible:
		_select_tool(NO_TOOL, &"")
		_hide_marker()


## The 3D view's input while a board is selected: AFTER_GUI_INPUT_STOP when the brush took it.
func input(camera: Camera3D, event: InputEvent) -> int:
	if not _ready_to_paint():
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if _tool == NO_TOOL:
		_hide_marker()
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if event is InputEventKey:
		return _on_key(event as InputEventKey)
	var motion := event as InputEventMouseMotion
	if motion != null:
		return _on_motion(camera, motion)
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT and not button.alt_pressed:
		return _on_button(camera, button)
	return EditorPlugin.AFTER_GUI_INPUT_PASS


func _process(delta: float) -> void:
	_poll += delta
	if _poll < POLL_SECONDS:
		return
	_poll = 0.0
	if _view != null and is_instance_valid(_view) and _view.tiles.keys() != _tiles_seen:
		_rebuild_tile_buttons()
	_refresh_save_button()


func _ready_to_paint() -> bool:
	if _bar == null or not _bar.visible:
		return false
	if _board == null or _view == null or not is_instance_valid(_board) or not is_instance_valid(_view):
		return false
	return true


func _on_key(key: InputEventKey) -> int:
	if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		_select_tool(NO_TOOL, &"")
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	return EditorPlugin.AFTER_GUI_INPUT_PASS


func _on_motion(camera: Camera3D, motion: InputEventMouseMotion) -> int:
	var cell := _cell_at(camera, motion.position)
	_show_marker(cell)
	if not _stroke.is_active():
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	# A release the editor never told us about: the button is up, the stroke is over.
	if not (motion.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_end_stroke()
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	_stroke.touch(cell)
	return EditorPlugin.AFTER_GUI_INPUT_STOP


func _on_button(camera: Camera3D, button: InputEventMouseButton) -> int:
	if button.pressed:
		var cell := _cell_at(camera, button.position)
		if cell == CellGrid.NO_CELL:
			return EditorPlugin.AFTER_GUI_INPUT_PASS
		_watch_layout(_board)
		var tool := _tool as GridStroke.Tool
		# Shift turns Raise into Lower and back, as in terrain editors.
		if button.shift_pressed and tool == GridStroke.Tool.RAISE:
			tool = GridStroke.Tool.LOWER
		elif button.shift_pressed and tool == GridStroke.Tool.LOWER:
			tool = GridStroke.Tool.RAISE
		_stroke.begin(_board, _view, tool, _stroke_value(tool))
		_stroke.touch(cell)
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	if _stroke.is_active():
		_end_stroke()
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	return EditorPlugin.AFTER_GUI_INPUT_PASS


# What a stroke of `tool` writes: the tile, the step of Raise and Lower or the height of Set height.
func _stroke_value(tool: GridStroke.Tool) -> Variant:
	if tool == GridStroke.Tool.SET_HEIGHT:
		return _height_box.value
	if tool in GridStroke.HEIGHT_TOOLS:
		return _step_box.value
	return _tile


func _cell_at(camera: Camera3D, at: Vector2) -> Vector2i:
	var on_board_only := _tool != GridStroke.Tool.ADD
	return _view.cell_at_ray(camera.project_ray_origin(at), camera.project_ray_normal(at), on_board_only)


# --- undo -------------------------------------------------------------------------------------


func _end_stroke() -> void:
	var result := _stroke.finish()
	if not bool(result["changed"]):
		return
	var history: Object = _history if _history != null else EditorInterface.get_editor_undo_redo()
	history.call(&"create_action", "Paint grid cells", UndoRedo.MERGE_DISABLE, _board)
	record(history, _board, result)
	# The stroke was already applied while dragging.
	history.call(&"commit_action", false)
	_refresh_save_button()


## Adds to `history` (an EditorUndoRedoManager's open action) what a finished stroke did and how to take it back.
static func record(history: Object, board: GridBoard, result: Dictionary) -> void:
	var key: StringName = result["key"]
	var layout: GridLayout = result["layout"]
	if layout != null:
		history.call(&"add_do_property", board, &"layout", layout)
		history.call(&"add_do_reference", layout)
	# A height stroke on a board that had no height key gave it one.
	var height_key: StringName = result["height_key"]
	if height_key != &"":
		history.call(&"add_do_property", board, &"height_key", height_key)
	match result["tool"] as GridStroke.Tool:
		GridStroke.Tool.ADD:
			var added: Array[Vector2i] = result["added"]
			var none: Array[Vector2i] = []
			history.call(&"add_do_method", board, &"set_cells", added, none)
			history.call(&"add_undo_method", board, &"set_cells", none, added)
		GridStroke.Tool.REMOVE:
			var removed: Array[Vector2i] = result["removed"]
			var nothing: Array[Vector2i] = []
			history.call(&"add_do_method", board, &"set_cells", nothing, removed)
			history.call(&"add_undo_method", board, &"set_cells", removed, nothing, result["removed_values"])
		_:
			history.call(&"add_do_method", board, &"paint", key, result["after"])
			history.call(&"add_undo_method", board, &"paint", key, result["before"])
	# The height key and the layout go away last: the undo methods run in the order they were added.
	if height_key != &"":
		history.call(&"add_undo_property", board, &"height_key", &"")
	if layout != null:
		history.call(&"add_undo_property", board, &"layout", null)


# Makes a GridLayout from the board's current shape and assigns it, as one step of the undo history.
func _on_save_pressed() -> void:
	if not _ready_to_paint() or _board.layout != null:
		return
	var layout := GridLayout.from_grid(_board.grid)
	var history: Object = _history if _history != null else EditorInterface.get_editor_undo_redo()
	history.call(&"create_action", "Save grid shape as layout", UndoRedo.MERGE_DISABLE, _board)
	history.call(&"add_do_property", _board, &"layout", layout)
	history.call(&"add_do_reference", layout)
	history.call(&"add_undo_property", _board, &"layout", null)
	history.call(&"commit_action")
	_refresh_save_button()


# Only a board with no layout can save its shape as one.
func _refresh_save_button() -> void:
	if _save_button == null:
		return
	var board_ok := _board != null and is_instance_valid(_board)
	_save_button.disabled = not board_ok or _board.layout != null


# --- layouts in their own file ---------------------------------------------------------------
# The editor only saves an external resource that is marked as edited, and a stroke writes the layout through the
# board. So the tool remembers what each external layout looked like when it first touched it, and the plugin writes
# the ones that differ now when the editor saves (`_save_external_data`).


## True for a layout that is a file of its own (a scene's own sub-resource has "::" in its path and is saved with it).
static func is_external(layout: GridLayout) -> bool:
	return layout != null and not layout.resource_path.is_empty() and not layout.resource_path.contains("::")


## The layout's content as text, with cells and keys in a fixed order.
static func fingerprint(layout: GridLayout) -> String:
	var cells: Array[Vector2i] = []
	cells.assign(layout.cells.keys())
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var parts: Array = []
	for cell in cells:
		var values: Dictionary = layout.cells[cell]
		var keys := values.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		var pairs: Array = []
		for key: Variant in keys:
			pairs.append([str(key), values[key]])
		parts.append([cell, pairs])
	return var_to_str([layout.shape, layout.diagonals, parts])


## Remembers `board`'s layout as it is now, if it is a file of its own and was not remembered yet.
func _watch_layout(board: GridBoard) -> void:
	var layout := board.layout
	if not is_external(layout) or _watched.has(layout):
		return
	var root: Node = board.owner if board.owner != null else board
	_watched[layout] = {"saved": fingerprint(layout), "scene": root.scene_file_path}


## The watched layouts whose content is not what is in their file, sorted by path.
func unsaved_layouts() -> Array[GridLayout]:
	var list: Array[GridLayout] = []
	for layout: GridLayout in _watched.keys():
		if not is_instance_valid(layout) or not is_external(layout):
			_watched.erase(layout)
		elif fingerprint(layout) != (_watched[layout] as Dictionary)["saved"]:
			list.append(layout)
	list.sort_custom(func(a: GridLayout, b: GridLayout) -> bool: return a.resource_path < b.resource_path)
	return list


## Writes every unsaved layout to its file. Returns the paths it wrote.
func save_unsaved_layouts() -> Array[String]:
	var written: Array[String] = []
	for layout in unsaved_layouts():
		if ResourceSaver.save(layout, layout.resource_path) == OK:
			(_watched[layout] as Dictionary)["saved"] = fingerprint(layout)
			written.append(layout.resource_path)
		else:
			push_error("GridKit: could not save %s" % layout.resource_path)
	return written


## A short question for the editor when closing: empty when nothing is unsaved. `for_scene` limits it to the layouts
## that a board of that scene used (empty: all of them).
func unsaved_status(for_scene: String) -> String:
	var files: Array[String] = []
	for layout in unsaved_layouts():
		if for_scene.is_empty() or (_watched[layout] as Dictionary)["scene"] == for_scene:
			files.append(layout.resource_path.get_file())
	if files.is_empty():
		return ""
	return "GridKit: save the painted map (%s) before closing?" % ", ".join(files)


# --- the bar ----------------------------------------------------------------------------------


func _build_bar() -> void:
	_bar = HBoxContainer.new()
	var title := Label.new()
	title.text = "GridKit"
	_bar.add_child(title)
	_bar.add_child(_tile_buttons)
	_bar.add_child(VSeparator.new())
	_add_button("Erase", GridStroke.Tool.ERASE, &"")
	_add_button("Add cells", GridStroke.Tool.ADD, &"")
	_add_button("Remove cells", GridStroke.Tool.REMOVE, &"")
	_bar.add_child(VSeparator.new())
	var raise := _add_button("Raise", GridStroke.Tool.RAISE, &"")
	raise.tooltip_text = "Raises each cell of the stroke by the step. Shift lowers."
	var lower := _add_button("Lower", GridStroke.Tool.LOWER, &"")
	lower.tooltip_text = "Lowers each cell of the stroke by the step. Shift raises."
	_step_box = _add_number_box(0.01, 100.0, 1.0, "The step of Raise and Lower.")
	_step_box.prefix = "±"
	var level := _add_button("Set height", GridStroke.Tool.SET_HEIGHT, &"")
	level.tooltip_text = "Writes the height next to it on each cell of the stroke."
	_height_box = _add_number_box(-100.0, 100.0, 1.0, "The height Set height writes.")
	_height_box.allow_lesser = true
	_bar.add_child(VSeparator.new())
	_save_button = Button.new()
	_save_button.text = "Save shape as layout"
	_save_button.disabled = true
	_save_button.pressed.connect(_on_save_pressed)
	_bar.add_child(_save_button)
	_bar.visible = false
	_refresh_save_button()


func _rebuild_tile_buttons() -> void:
	# A tile brush that was on may be gone now.
	if _tool == GridStroke.Tool.PAINT:
		_select_tool(NO_TOOL, &"")
	for child in _tile_buttons.get_children():
		_tile_buttons.remove_child(child)
		child.queue_free()
	_tiles_seen = []
	if _view == null or not is_instance_valid(_view):
		return
	_tiles_seen = _view.tiles.keys()
	for tile: StringName in _tiles_seen:
		_add_button(String(tile), GridStroke.Tool.PAINT, tile, _tile_buttons)


# A box for a height or a step: hundredths by hand, and the arrows move it by 1.
func _add_number_box(low: float, high: float, value: float, tooltip: String) -> SpinBox:
	var box := SpinBox.new()
	box.min_value = low
	box.max_value = high
	box.step = 0.01
	box.custom_arrow_step = 1.0
	box.allow_greater = true
	box.value = value
	box.tooltip_text = tooltip
	_bar.add_child(box)
	return box


func _add_button(text: String, tool: int, tile: StringName, into: Node = null) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_group = _group
	button.toggled.connect(_on_toggled.bind(button, tool, tile))
	(into if into != null else _bar).add_child(button)
	return button


func _on_toggled(on: bool, button: Button, tool: int, tile: StringName) -> void:
	if on:
		_current_button = button
		_select_tool(tool, tile, false)
	elif _current_button == button:
		_current_button = null
		_select_tool(NO_TOOL, &"", false)


# Chooses the tool; `release_buttons` also lets go of the toggle that was on.
func _select_tool(tool: int, tile: StringName, release_buttons := true) -> void:
	if _stroke.is_active() and (tool != _tool or tile != _tile):
		_end_stroke()
	_tool = tool
	_tile = tile
	if tool == NO_TOOL:
		_hide_marker()
		if release_buttons and _current_button != null and is_instance_valid(_current_button):
			_current_button.button_pressed = false
			_current_button = null


# --- the marker -------------------------------------------------------------------------------


func _show_marker(cell: Vector2i) -> void:
	if cell == CellGrid.NO_CELL:
		_hide_marker()
		return
	var scenario := _view.get_world_3d().scenario
	if not _marker.is_valid() or _marker_scenario != scenario:
		_free_marker()
		_marker_scenario = scenario
		_marker = RenderingServer.instance_create2(_marker_mesh.get_rid(), scenario)
		RenderingServer.instance_geometry_set_material_override(_marker, _marker_material.get_rid())
	_fit_marker_mesh()
	_marker_material.albedo_color = _marker_color()
	var local := Transform3D(Basis(), _board.cell_to_position(cell) + Vector3.UP * MARKER_LIFT)
	RenderingServer.instance_set_transform(_marker, _view.global_transform * local)
	RenderingServer.instance_set_visible(_marker, true)


func _hide_marker() -> void:
	if _marker.is_valid():
		RenderingServer.instance_set_visible(_marker, false)


func _free_marker() -> void:
	if _marker.is_valid():
		RenderingServer.free_rid(_marker)
	_marker = RID()


func _marker_color() -> Color:
	match _tool:
		GridStroke.Tool.ERASE:
			return Color(1.0, 0.7, 0.2)
		GridStroke.Tool.ADD:
			return Color(0.3, 1.0, 0.4)
		GridStroke.Tool.REMOVE:
			return Color(1.0, 0.3, 0.3)
		GridStroke.Tool.RAISE, GridStroke.Tool.LOWER, GridStroke.Tool.SET_HEIGHT:
			return Color(0.4, 0.8, 1.0)
	return Color(1.0, 1.0, 1.0)


# The outline of one cell, made again only when the shape or the size change.
func _fit_marker_mesh() -> void:
	var key := "%s|%s" % [_board.grid.shape_name(), _board.cell_size]
	if key == _marker_key:
		return
	_marker_key = key
	var vertices := PackedVector3Array()
	var outline := _board.grid.cell_outline(_board.cell_size)
	for corner in outline:
		vertices.append(Vector3(corner.x, 0.0, corner.y))
	if not outline.is_empty():
		vertices.append(Vector3(outline[0].x, 0.0, outline[0].y))
	_marker_mesh.clear_surfaces()
	if vertices.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	_marker_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arrays)
