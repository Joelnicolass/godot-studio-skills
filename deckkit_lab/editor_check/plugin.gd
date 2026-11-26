@tool
extends EditorPlugin

## Checks DeckKit in the real editor: it opens a copy of the minimal example, looks at what the HandViews show there,
## edits `start_cards` and `card_scene` through the editor's undo history (as the inspector does), undoes and redoes
## with the Ctrl/Cmd+Z shortcut, saves and reads the file back. It does nothing at all unless the editor was started
## with the user argument `--deckkit-editor-check`:
##   godot --headless --editor --path deckkit_lab -- --deckkit-editor-check
## It prints one PASS or FAIL line per check, then DECKKIT EDITOR CHECK PASS (n) or FAIL: k of n, and exits with 0 or 1.
## It works on a copy in res://editor_check/tmp, which it deletes at the end: the example itself is never written.

const ARG := "--deckkit-editor-check"
const TMP := "res://editor_check/tmp"
const EXAMPLE := "res://addons/deck_kit/examples/minimal/minimal.tscn"
const CARD_FACE := "res://addons/deck_kit/examples/minimal/card_face.tscn"
const TIMEOUT_SECONDS := 120.0

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
	var example_before := FileAccess.get_file_as_string(EXAMPLE)
	var example_time := FileAccess.get_modified_time(EXAMPLE)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP))
	DirAccess.copy_absolute(ProjectSettings.globalize_path(EXAMPLE), ProjectSettings.globalize_path(TMP + "/copy.tscn"))
	await _scan()
	_check_classes()
	await _check_example()
	_check("the example on disk was not written", FileAccess.get_file_as_string(EXAMPLE) == example_before)
	_check("nor its modified time", FileAccess.get_modified_time(EXAMPLE) == example_time)
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
		print("DECKKIT EDITOR CHECK PASS (%d)" % total)
	else:
		print("DECKKIT EDITOR CHECK FAIL: %d of %d" % [_fails, total])
	get_tree().quit(0 if _fails == 0 else 1)


# --- the checks -------------------------------------------------------------------------------


func _check_classes() -> void:
	var names: Array[String] = []
	for entry in ProjectSettings.get_global_class_list():
		var known: StringName = entry["class"]
		names.append(String(known))
	for wanted: String in ["CardData", "CardStack", "CardPile", "Deck", "HandView"]:
		_check("the editor knows %s" % wanted, names.has(wanted))


func _check_example() -> void:
	var root := await _open(TMP + "/copy.tscn")
	if root == null:
		_check("the copy of the example opens", false)
		return
	var deck := root.get_node(^"%Deck") as Deck
	var deck_view := root.get_node(^"Box/Table/DeckView") as HandView
	var hand_view := root.get_node(^"%HandView") as HandView
	var start := deck.start_cards.duplicate()
	_check("the copy opens with its Deck and HandViews", deck != null and deck_view != null and hand_view != null)
	_check("the Deck keeps the inspector order in the editor", deck.size() == 12 and deck.cards() == deck.start_cards)
	_check("no warnings on the Deck and the views", _warnings([deck, deck_view, hand_view]).is_empty())
	var draws: Array[int] = [0]
	deck_view.draw.connect(func() -> void: draws[0] += 1)
	deck_view.queue_redraw()
	await _frames(3)
	_check("the deck's view draws in the editor", draws[0] > 0)
	_check("it shows the 12 start cards", deck_view.card_rect(11).has_area() and not deck_view.card_rect(12).has_area())
	_check("faces, though the deck is face down (faces_in_editor)", not deck.face_up and deck_view._shows_faces())
	var top := deck_view.card_rect(0)
	_check("the top card is the first start card", deck_view.card_at(top.get_center()) == deck.start_cards[0])
	# Edit start_cards the way the inspector does: one action in the editor's history.
	var fewer: Array[CardData] = deck.start_cards.slice(0, 8)
	var before := draws[0]
	_set_in_history(deck, &"start_cards", fewer, "Set start_cards")
	await _frames(3)
	_check("an edit of start_cards rebuilds the deck", deck.size() == 8)
	_check("the view follows it", deck_view.card_rect(7).has_area() and not deck_view.card_rect(8).has_area())
	_check("and draws again", draws[0] > before)
	await _press_z(false)
	await _frames(3)
	_check("Ctrl/Cmd+Z gives the 12 cards back", deck.size() == 12 and deck_view.card_rect(11).has_area())
	await _press_z(true)
	await _frames(3)
	_check("Ctrl/Cmd+Shift+Z edits them again", deck.size() == 8 and not deck_view.card_rect(8).has_area())
	_save_edited_scene()
	await _frames(10)
	var saved := ResourceLoader.load(TMP + "/copy.tscn", "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var again := saved.instantiate() if saved != null else null
	var saved_deck := again.get_node(^"%Deck") as Deck if again != null else null
	_check("the saved file has the edit", saved_deck != null and saved_deck.start_cards.size() == 8)
	_check(
		"and keeps face_up off and rng_seed", saved_deck != null and not saved_deck.face_up and saved_deck.rng_seed == 1
	)
	if again != null:
		again.free()
	# A card scene on the deck's view: one instance per card, in the editor too.
	_set_in_history(deck_view, &"card_scene", load(CARD_FACE) as PackedScene, "Set card_scene")
	await _frames(3)
	var made := _card_nodes(deck_view)
	_check("card_scene makes one scene per card in the editor", made.size() == 8)
	var right_card: CardData = made[7].get(&"card") if made.size() == 8 else null
	_check("each with its card", right_card == deck.start_cards[0])
	await _press_z(false)
	await _frames(3)
	_check("Ctrl/Cmd+Z takes the scenes away", _card_nodes(deck_view).is_empty())
	_check("the hand starts empty", not hand_view.card_rect(0).has_area())
	_set_in_history(deck, &"start_cards", start, "Set start_cards")
	await _frames(2)


# --- driving the editor -----------------------------------------------------------------------


func _set_in_history(target: Object, property: StringName, value: Variant, action: String) -> void:
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action(action, UndoRedo.MERGE_DISABLE, target)
	undo_redo.add_do_property(target, property, value)
	undo_redo.add_undo_property(target, property, target.get(property))
	undo_redo.commit_action()


func _warnings(nodes: Array[Node]) -> PackedStringArray:
	var found := PackedStringArray()
	for node in nodes:
		found.append_array(node._get_configuration_warnings())
	return found


func _card_nodes(view: HandView) -> Array[Node]:
	if view.get_child_count(true) == 0:
		var none: Array[Node] = []
		return none
	return view.get_child(0, true).get_children()


func _open(path: String) -> Node:
	EditorInterface.open_scene_from_path(path)
	await _frames(20)
	EditorInterface.set_main_screen_editor("2D")
	await _frames(10)
	return EditorInterface.get_edited_scene_root()


# The editor's own save, without the thumbnail: headless has no viewport texture to make one from (the engine
# reports "Parameter t is null" in texture_2d_get when it tries).
func _save_edited_scene() -> void:
	EditorInterface.save_scene_as(EditorInterface.get_edited_scene_root().scene_file_path, false)


func _scan() -> void:
	var files := EditorInterface.get_resource_filesystem()
	files.scan()
	await _frames(5)
	while files.is_scanning():
		await _frames(2)


# Undo and redo as a person does, with the editor's shortcut: the editor keeps its own list of every history's
# steps, and calling `UndoRedo.undo()` on a history directly leaves that list behind ("Inconsistent redo history").
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
