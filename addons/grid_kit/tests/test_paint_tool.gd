extends "res://addons/grid_kit/tests/grid_test.gd"

## The editor's paint tool with no editor open: the bar it builds, how mouse events become strokes and what it records
## in the undo history (a stand-in records it). What needs a real editor is the 3D view feeding it events, the bar on
## screen and the undo history itself.

const PaintTool := preload("res://addons/grid_kit/editor/grid_paint_tool.gd")
const Stroke := preload("res://addons/grid_kit/editor/grid_stroke.gd")
const FakeHistory := preload("res://addons/grid_kit/tests/fake_history.gd")
const STOP := EditorPlugin.AFTER_GUI_INPUT_STOP
const PASS := EditorPlugin.AFTER_GUI_INPUT_PASS
const FILE := "user://grid_kit_test_external.tres"


class Rig:
	extends RefCounted
	var board: GridBoard
	var view: GridView3D
	var eye: Camera3D
	var tool: Node
	var history: RefCounted


func _rig() -> Rig:
	var rig := Rig.new()
	rig.board = build_board(2)
	rig.board._in_editor = true
	rig.view = rig.board.get_node(^"View") as GridView3D
	rig.view.tiles = {&"water": null, &"forest": null}
	rig.eye = Camera3D.new()
	tree.root.add_child(rig.eye)
	rig.eye.position = Vector3(0, 10, 0.01)
	rig.eye.look_at(Vector3.ZERO)
	rig.eye.current = true
	rig.tool = PaintTool.new()
	tree.root.add_child(rig.tool)
	rig.history = FakeHistory.new()
	rig.tool._history = rig.history
	rig.tool.edit(rig.board)
	rig.tool.set_visible(true)
	return rig


func _end(rig: Rig) -> void:
	# The plugin owns the bar once it puts it in the editor; here nobody does.
	rig.tool.bar().free()
	rig.tool.free()
	rig.eye.free()
	rig.board.free()


func _at(rig: Rig, cell: Vector2i) -> Vector2:
	return rig.eye.unproject_position(rig.board.cell_to_position(cell))


func _motion(at: Vector2, left := false) -> InputEventMouseMotion:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if left else 0
	return motion


func _button(at: Vector2, pressed: bool, index := MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var button := InputEventMouseButton.new()
	button.button_index = index
	button.pressed = pressed
	button.position = at
	return button


func _tool_buttons(rig: Rig) -> Array[Button]:
	var found: Array[Button] = []
	for node in rig.tool.bar().find_children("*", "Button", true, false):
		found.append(node as Button)
	return found


func _button_named(rig: Rig, text: String) -> Button:
	for button in _tool_buttons(rig):
		if button.text == text:
			return button
	return null


func test_bar_has_a_button_per_tile() -> void:
	var rig := _rig()
	var texts: Array[String] = []
	for button in _tool_buttons(rig):
		texts.append(button.text)
	var expected: Array[String] = ["water", "forest", "Erase", "Add cells", "Remove cells", "Save shape as layout"]
	check(texts == expected, "buttons: %s" % [texts])
	check(rig.tool.bar().visible, "the bar shows when the tool is visible")
	rig.view.tiles = {&"mountain": null}
	rig.tool._process(1.0)
	var after: Array[String] = []
	for button in _tool_buttons(rig):
		after.append(button.text)
	var expected_after: Array[String] = ["mountain", "Erase", "Add cells", "Remove cells", "Save shape as layout"]
	check(after == expected_after, "rebuilt: %s" % [after])
	rig.tool.set_visible(false)
	check(not rig.tool.bar().visible, "and it hides")
	_end(rig)


func test_nothing_on_means_the_editor_behaves() -> void:
	var rig := _rig()
	var at := _at(rig, Vector2i(1, 0))
	check(rig.tool.input(rig.eye, _button(at, true)) == PASS, "no tool: a press passes")
	check(rig.tool.input(rig.eye, _motion(at, true)) == PASS, "no tool: a drag passes")
	check(rig.tool.input(rig.eye, _button(at, false)) == PASS, "no tool: a release passes")
	check(rig.board.get_value(Vector2i(1, 0), &"terrain") == null, "and the board is untouched")
	check(rig.history.calls.is_empty(), "nothing in the history")
	_end(rig)


func test_a_stroke_paints_and_records_one_action() -> void:
	var rig := _rig()
	(_button_named(rig, "water")).button_pressed = true
	var first := _at(rig, Vector2i(0, 0))
	check(rig.tool.input(rig.eye, _motion(first)) == PASS, "moving over the board does not take the event")
	check(rig.tool.input(rig.eye, _button(first, true)) == STOP, "a press takes it")
	check(rig.board.get_value(Vector2i(0, 0), &"terrain") == &"water", "and paints at once")
	check(rig.tool.input(rig.eye, _motion(_at(rig, Vector2i(1, 0)), true)) == STOP, "a drag takes it")
	check(rig.tool.input(rig.eye, _motion(_at(rig, Vector2i(1, 0)), true)) == STOP, "over the same cell too")
	check(rig.board.get_value(Vector2i(1, 0), &"terrain") == &"water", "and paints on")
	check(rig.history.calls.is_empty(), "nothing is recorded while dragging")
	check(rig.tool.input(rig.eye, _button(_at(rig, Vector2i(1, 0)), false)) == STOP, "the release takes it")
	var names: Array[String] = rig.history.names()
	var expected: Array[String] = [
		"create_action",
		"add_do_property",
		"add_do_reference",
		"add_do_method",
		"add_undo_method",
		"add_undo_property",
		"commit_action",
	]
	check(names == expected, "one action, the layout first in do and last in undo: %s" % [names])
	check(rig.history.calls[-1][1] == false, "committed without running do again")
	var do_call: Array = rig.history.calls[3]
	check(do_call[2] == &"paint" and do_call[3][0] == &"terrain", "do paints the view's key")
	check((do_call[3][1] as Dictionary).size() == 2, "two cells")
	check(rig.board.layout != null, "the board got a layout")
	_end(rig)


func test_a_new_stroke_after_the_layout_exists_has_no_layout_calls() -> void:
	var rig := _rig()
	(_button_named(rig, "water")).button_pressed = true
	rig.tool.input(rig.eye, _button(_at(rig, Vector2i(0, 0)), true))
	rig.tool.input(rig.eye, _button(_at(rig, Vector2i(0, 0)), false))
	rig.history.calls.clear()
	rig.tool.input(rig.eye, _button(_at(rig, Vector2i(1, 0)), true))
	rig.tool.input(rig.eye, _button(_at(rig, Vector2i(1, 0)), false))
	var expected: Array[String] = ["create_action", "add_do_method", "add_undo_method", "commit_action"]
	check(rig.history.names() == expected, "just paint, no layout calls: %s" % [rig.history.names()])
	_end(rig)


func test_events_the_brush_leaves_alone() -> void:
	var rig := _rig()
	(_button_named(rig, "water")).button_pressed = true
	var at := _at(rig, Vector2i(0, 0))
	check(rig.tool.input(rig.eye, _button(at, true, MOUSE_BUTTON_RIGHT)) == PASS, "the right button is the editor's")
	check(rig.tool.input(rig.eye, _button(at, true, MOUSE_BUTTON_MIDDLE)) == PASS, "and the middle one")
	var alt := _button(at, true)
	alt.alt_pressed = true
	check(rig.tool.input(rig.eye, alt) == PASS, "Alt + left is the editor's camera")
	check(rig.tool.input(rig.eye, _button(_at(rig, Vector2i(30, 30)), true)) == PASS, "a press off the board passes")
	check(rig.board.get_value(Vector2i(0, 0), &"terrain") == null, "nothing was painted")
	check(rig.tool.input(rig.eye, _button(at, false)) == PASS, "a release with no stroke passes")
	_end(rig)


func test_a_lost_release_ends_the_stroke() -> void:
	var rig := _rig()
	(_button_named(rig, "water")).button_pressed = true
	rig.tool.input(rig.eye, _button(_at(rig, Vector2i(0, 0)), true))
	check(rig.tool.input(rig.eye, _motion(_at(rig, Vector2i(1, 0)), false)) == PASS, "a move with no button held")
	check(rig.board.get_value(Vector2i(1, 0), &"terrain") == null, "does not paint")
	check(rig.history.names().has("commit_action"), "and the stroke was closed")
	_end(rig)


func test_one_tool_at_a_time_and_escape() -> void:
	var rig := _rig()
	var water := _button_named(rig, "water")
	var erase := _button_named(rig, "Erase")
	water.button_pressed = true
	erase.button_pressed = true
	check(erase.button_pressed and not water.button_pressed, "pressing another tool lets go of the first")
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	check(rig.tool.input(rig.eye, key) == STOP, "Escape is taken while a tool is on")
	check(not erase.button_pressed, "and the tool is off")
	check(rig.tool.input(rig.eye, key) == PASS, "with none on, Escape is the editor's")
	_end(rig)


func test_erase_add_and_remove_tools() -> void:
	var rig := _rig()
	rig.board.set_value(Vector2i(0, 0), &"terrain", &"water")
	_button_named(rig, "Erase").button_pressed = true
	rig.tool.input(rig.eye, _button(_at(rig, Vector2i(0, 0)), true))
	rig.tool.input(rig.eye, _button(_at(rig, Vector2i(0, 0)), false))
	check(rig.board.get_value(Vector2i(0, 0), &"terrain") == null, "Erase takes the value out")
	_button_named(rig, "Add cells").button_pressed = true
	var beside := _at(rig, Vector2i(3, 0))
	check(rig.tool.input(rig.eye, _button(beside, true)) == STOP, "Add cells works next to the board")
	rig.tool.input(rig.eye, _button(beside, false))
	check(rig.board.has_cell(Vector2i(3, 0)), "the cell is there")
	_button_named(rig, "Remove cells").button_pressed = true
	rig.tool.input(rig.eye, _button(_at(rig, Vector2i(1, 0)), true))
	rig.tool.input(rig.eye, _button(_at(rig, Vector2i(1, 0)), false))
	check(not rig.board.has_cell(Vector2i(1, 0)), "Remove cells takes the cell out")
	var recorded := 0
	for entry: Array in rig.history.calls:
		if entry[0] == "commit_action":
			recorded += 1
	check(recorded == 3, "three strokes, three actions: %d" % recorded)
	_end(rig)


func test_selecting_a_view_or_something_else() -> void:
	var rig := _rig()
	rig.tool.edit(rig.view)
	check(_tool_buttons(rig).size() == 6, "a selected GridView3D has the same bar")
	rig.tool.edit(null)
	(_button_named(rig, "Erase")).button_pressed = true
	check(
		rig.tool.input(rig.eye, _button(_at(rig, Vector2i(0, 0)), true)) == PASS,
		"with nothing selected, nothing happens"
	)
	var stray := Node3D.new()
	rig.tool.edit(stray)
	check(_tool_buttons(rig).size() == 4, "another node has no tile buttons")
	stray.free()
	_end(rig)


func test_record_orders_the_undo_of_a_removal() -> void:
	var rig := _rig()
	var stroke := Stroke.new()
	rig.board.set_value(Vector2i(1, 0), &"terrain", &"water")
	stroke.begin(rig.board, rig.view, Stroke.Tool.REMOVE)
	stroke.touch(Vector2i(1, 0))
	var result := stroke.finish()
	var history := FakeHistory.new()
	PaintTool.record(history, rig.board, result)
	var undo: Array = history.calls[-2]
	check(undo[0] == "add_undo_method" and undo[2] == &"set_cells", "undo puts the cells back")
	check((undo[3][2] as Dictionary)[Vector2i(1, 0)] == {&"terrain": &"water"}, "with the values they had")
	_end(rig)


func test_save_shape_as_layout_button() -> void:
	var rig := _rig()
	var save := _button_named(rig, "Save shape as layout")
	check(save != null and not save.disabled, "a board with no layout can save its shape")
	check(rig.board.layout == null, "it has none yet")
	save.pressed.emit()
	var expected: Array[String] = [
		"create_action", "add_do_property", "add_do_reference", "add_undo_property", "commit_action"
	]
	check(rig.history.names() == expected, "one action: %s" % [rig.history.names()])
	check(rig.history.calls[-1][1] == true, "committed running the do")
	check(rig.board.layout != null and rig.board.layout.make_grid().to_dict() == rig.board.grid.to_dict(), "its shape")
	check(save.disabled, "the button is off once there is a layout")
	rig.history.undo()
	check(rig.board.layout == null, "undo takes the layout out")
	rig.tool._process(1.0)
	check(not save.disabled, "and the button is back")
	save.pressed.emit()
	save.pressed.emit()
	var commits: int = rig.history.names().count("commit_action")
	check(commits == 2, "pressing with a layout already there does nothing: %d" % commits)
	_end(rig)


# A board whose layout is a .tres of its own (saved in user://), and the tool watching it.
func _external_rig() -> Rig:
	var rig := _rig()
	var layout := GridLayout.from_grid(rig.board.grid)
	ResourceSaver.save(layout, FILE)
	rig.board.layout = ResourceLoader.load(FILE, "", ResourceLoader.CACHE_MODE_IGNORE) as GridLayout
	return rig


func _stroke_on(rig: Rig, tile: String, cell: Vector2i) -> void:
	(_button_named(rig, tile)).button_pressed = true
	rig.tool.input(rig.eye, _button(_at(rig, cell), true))
	rig.tool.input(rig.eye, _button(_at(rig, cell), false))


func _on_disk() -> GridLayout:
	return ResourceLoader.load(FILE, "", ResourceLoader.CACHE_MODE_IGNORE) as GridLayout


func _remove_file() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE))


func test_a_painted_external_layout_is_listed_and_saved() -> void:
	var rig := _external_rig()
	check(rig.tool.unsaved_layouts().is_empty(), "nothing is unsaved before a stroke")
	_stroke_on(rig, "water", Vector2i(0, 0))
	var unsaved: Array[GridLayout] = rig.tool.unsaved_layouts()
	check(unsaved == ([rig.board.layout] as Array[GridLayout]), "the painted layout is listed")
	check(_on_disk().get_value(Vector2i(0, 0), &"terrain") == null, "and the file has not changed yet")
	check(not rig.tool.unsaved_status("").is_empty(), "the editor is told when closing")
	check(rig.tool.unsaved_status("").contains("grid_kit_test_external.tres"), "with the file's name")
	var written: Array[String] = rig.tool.save_unsaved_layouts()
	var expected_files: Array[String] = [FILE]
	check(written == expected_files, "saving writes that file: %s" % [written])
	check(_on_disk().get_value(Vector2i(0, 0), &"terrain") == &"water", "the file on disk has the new value")
	check(rig.tool.unsaved_layouts().is_empty() and rig.tool.unsaved_status("").is_empty(), "nothing is left to save")
	check(rig.tool.save_unsaved_layouts().is_empty(), "and saving again writes nothing")
	_remove_file()
	_end(rig)


func test_undoing_back_to_the_saved_state_is_not_a_change() -> void:
	var rig := _external_rig()
	var before_text := FileAccess.get_file_as_string(FILE)
	var before_time := FileAccess.get_modified_time(FILE)
	_stroke_on(rig, "water", Vector2i(0, 0))
	check(not rig.tool.unsaved_layouts().is_empty(), "painted: unsaved")
	rig.board.paint(&"terrain", {Vector2i(0, 0): null})
	check(rig.tool.unsaved_layouts().is_empty(), "painted and undone: nothing to save")
	check(rig.tool.save_unsaved_layouts().is_empty(), "so nothing is written")
	check(FileAccess.get_file_as_string(FILE) == before_text, "the file has the same content")
	check(FileAccess.get_modified_time(FILE) == before_time, "and the same modified time")
	_remove_file()
	_end(rig)


func test_only_the_status_of_the_scene_that_uses_it() -> void:
	var rig := _external_rig()
	rig.board.scene_file_path = "res://some_level.tscn"
	_stroke_on(rig, "water", Vector2i(0, 0))
	check(not rig.tool.unsaved_status("res://some_level.tscn").is_empty(), "the scene that uses it is told")
	check(rig.tool.unsaved_status("res://another_level.tscn").is_empty(), "another scene is not")
	check(not rig.tool.unsaved_status("").is_empty(), "closing the editor asks about all of them")
	_remove_file()
	_end(rig)


func test_a_layout_inside_the_scene_is_never_watched() -> void:
	var rig := _rig()
	_stroke_on(rig, "water", Vector2i(0, 0))
	check(rig.board.layout != null and rig.board.layout.resource_path.is_empty(), "the stroke made a layout of its own")
	check(rig.tool.unsaved_layouts().is_empty(), "a layout with no file is the scene's to save")
	var inner := GridLayout.from_grid(rig.board.grid)
	inner.resource_path = "res://some_scene.tscn::GridLayout_1"
	rig.board.layout = inner
	_stroke_on(rig, "forest", Vector2i(1, 0))
	check(rig.tool.unsaved_layouts().is_empty(), "nor one that is a sub-resource of a scene (:: in its path)")
	check(rig.tool.save_unsaved_layouts().is_empty(), "so nothing is written")
	inner.resource_path = ""
	_end(rig)


func test_an_external_layout_nobody_painted_is_not_written() -> void:
	var rig := _external_rig()
	var time := FileAccess.get_modified_time(FILE)
	check(rig.tool.save_unsaved_layouts().is_empty(), "no stroke, nothing written")
	_stroke_on(rig, "water", Vector2i(0, 0))
	rig.tool.save_unsaved_layouts()
	var other := GridLayout.from_grid(HexGrid.rect(2, 2))
	ResourceSaver.save(other, "user://grid_kit_test_other.tres")
	var other_time := FileAccess.get_modified_time("user://grid_kit_test_other.tres")
	rig.tool.save_unsaved_layouts()
	check(FileAccess.get_modified_time("user://grid_kit_test_other.tres") == other_time, "a file nobody touched stays")
	check(time <= FileAccess.get_modified_time(FILE), "the painted one was written")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://grid_kit_test_other.tres"))
	_remove_file()
	_end(rig)


func test_the_fingerprint_does_not_depend_on_dictionary_order() -> void:
	var one := GridLayout.new()
	one.set_value(Vector2i(1, 0), &"b", 2)
	one.set_value(Vector2i(0, 0), &"a", 1)
	one.set_value(Vector2i(1, 0), &"a", 1)
	var two := GridLayout.new()
	two.set_value(Vector2i(1, 0), &"a", 1)
	two.set_value(Vector2i(0, 0), &"a", 1)
	two.set_value(Vector2i(1, 0), &"b", 2)
	check(PaintTool.fingerprint(one) == PaintTool.fingerprint(two), "the same map, the same text")
	two.set_value(Vector2i(1, 0), &"b", 3)
	check(PaintTool.fingerprint(one) != PaintTool.fingerprint(two), "another value, another text")
	check(PaintTool.is_external(one) == false, "a layout with no path is not external")
