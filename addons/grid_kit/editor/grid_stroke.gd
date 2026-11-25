extends RefCounted

## One brush stroke on a `GridBoard`, apart from the mouse and the undo history: `begin`, then `touch(cell)` for each
## cell the pointer goes over, then `finish()`. Every touch is applied to the board at once; `finish()` says what
## changed (`before` and `after`, cells added and removed) so the editor can undo it. A stroke uses one tool.
## RAISE, LOWER and SET_HEIGHT write the board's `height_key` instead of the view's `value_key`.

enum Tool { PAINT, ERASE, ADD, REMOVE, RAISE, LOWER, SET_HEIGHT }

## The key a height stroke gives a board that has no `height_key` yet.
const DEFAULT_HEIGHT_KEY := &"height"
const HEIGHT_TOOLS: Array[Tool] = [Tool.RAISE, Tool.LOWER, Tool.SET_HEIGHT]
# Heights are kept to the thousandth, so steps of 0.1 add up to round numbers.
const HEIGHT_SNAP := 0.001

var _board: GridBoard
var _tool := Tool.PAINT
var _key: StringName
var _value: Variant
var _active := false
var _before: Dictionary = {}
var _after: Dictionary = {}
var _added: Array[Vector2i] = []
var _removed: Array[Vector2i] = []
var _removed_values: Dictionary = {}
var _layout: GridLayout
var _height_key_set := false


## Starts a stroke on `board`. `view.value_key` is the value the stroke writes; `value` is what PAINT writes (a key of
## `view.tiles`). A board without a `layout` gets one made from its current shape, so what is painted is saved.
## A height stroke writes `board.height_key` (a board without one gets `DEFAULT_HEIGHT_KEY`); its `value` is the step
## of RAISE and LOWER or the height SET_HEIGHT writes, in the units of the data (before `height_scale`).
func begin(board: GridBoard, view: GridView3D, tool: Tool, value: Variant = null) -> void:
	_board = board
	_tool = tool
	_key = view.value_key
	_value = value
	_active = true
	_before = {}
	_after = {}
	_added = []
	_removed = []
	_removed_values = {}
	_layout = null
	_height_key_set = false
	if board.layout == null:
		_layout = GridLayout.from_grid(board.grid)
		board.layout = _layout
	if tool in HEIGHT_TOOLS:
		if board.height_key == &"":
			board.height_key = DEFAULT_HEIGHT_KEY
			_height_key_set = true
		_key = board.height_key


func is_active() -> bool:
	return _active


## The pointer went over `cell`. Returns true when that changed the board (a cell already painted with the same value,
## already there or already gone changes nothing, so it is not counted twice).
func touch(cell: Vector2i) -> bool:
	if not _active or cell == CellGrid.NO_CELL:
		return false
	if _tool in HEIGHT_TOOLS:
		return _level(cell)
	match _tool:
		Tool.PAINT:
			return _paint(cell, _value)
		Tool.ERASE:
			return _paint(cell, null)
		Tool.ADD:
			return _add(cell)
	return _remove(cell)


## Ends the stroke. The result has `changed`, `tool`, `key`, `before` and `after` (`{cell: value}`, null = no value),
## `added`, `removed`, `removed_values` (`{cell: {key: value}}`: all that the removed cells held), `layout` (the
## layout this stroke made, or null) and `height_key` (the key this stroke gave the board, or empty). A stroke that
## changed nothing takes its layout and its height key back out.
func finish() -> Dictionary:
	_active = false
	var changed := not (_before.is_empty() and _added.is_empty() and _removed.is_empty())
	var made := _layout
	var height_key: StringName = _key if _height_key_set else &""
	if not changed and made != null:
		_board.layout = null
		made = null
	if not changed and _height_key_set:
		_board.height_key = &""
		height_key = &""
	return {
		"changed": changed,
		"tool": _tool,
		"key": _key,
		"before": _before,
		"after": _after,
		"added": _added,
		"removed": _removed,
		"removed_values": _removed_values,
		"layout": made,
		"height_key": height_key,
	}


func _paint(cell: Vector2i, value: Variant) -> bool:
	if not _board.has_cell(cell):
		return false
	var current: Variant = _board.get_value(cell, _key)
	if _same(current, value):
		return false
	if not _before.has(cell):
		_before[cell] = current
	_after[cell] = value
	_board.paint(_key, {cell: value})
	return true


# RAISE and LOWER move a cell one step, once per stroke; SET_HEIGHT writes the same height on every cell it touches.
# A height that is a whole number is written as an int.
func _level(cell: Vector2i) -> bool:
	if not _board.has_cell(cell):
		return false
	var current: Variant = _board.get_value(cell, _key)
	var is_number := typeof(current) == TYPE_INT or typeof(current) == TYPE_FLOAT
	var height := float(current) if is_number else 0.0
	var target := float(_value)
	if _tool != Tool.SET_HEIGHT:
		if _before.has(cell):
			return false
		target = height + (target if _tool == Tool.RAISE else -target)
	target = snappedf(target, HEIGHT_SNAP)
	# A cell with no height is already at 0.
	if target == height and (is_number or current == null):
		return false
	var value: Variant = int(target) if target == roundf(target) else target
	return _paint(cell, value)


# A text and a number are just different (`==` between them is an error); `&"water"` and `"water"` are the same tile.
static func _same(a: Variant, b: Variant) -> bool:
	var a_is_text := typeof(a) == TYPE_STRING or typeof(a) == TYPE_STRING_NAME
	var b_is_text := typeof(b) == TYPE_STRING or typeof(b) == TYPE_STRING_NAME
	if a_is_text and b_is_text:
		return String(a) == String(b)
	return typeof(a) == typeof(b) and a == b


func _add(cell: Vector2i) -> bool:
	if _board.has_cell(cell):
		return false
	_added.append(cell)
	_board.set_cells([cell], [])
	return true


func _remove(cell: Vector2i) -> bool:
	if not _board.has_cell(cell):
		return false
	_removed.append(cell)
	_removed_values[cell] = _board.grid.values(cell)
	_board.set_cells([], [cell])
	return true
