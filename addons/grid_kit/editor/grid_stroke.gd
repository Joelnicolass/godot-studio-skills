extends RefCounted

## One brush stroke on a `GridBoard`, apart from the mouse and the undo history: `begin`, then `touch(cell)` for each
## cell the pointer goes over, then `finish()`. Every touch is applied to the board at once; `finish()` says what
## changed (`before` and `after`, cells added and removed) so the editor can undo it. A stroke uses one tool.

enum Tool { PAINT, ERASE, ADD, REMOVE }

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


## Starts a stroke on `board`. `view.value_key` is the value the stroke writes; `value` is what PAINT writes (a key of
## `view.tiles`). A board without a `layout` gets one made from its current shape, so what is painted is saved.
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
	if board.layout == null:
		_layout = GridLayout.from_grid(board.grid)
		board.layout = _layout


func is_active() -> bool:
	return _active


## The pointer went over `cell`. Returns true when that changed the board (a cell already painted with the same value,
## already there or already gone changes nothing, so it is not counted twice).
func touch(cell: Vector2i) -> bool:
	if not _active or cell == CellGrid.NO_CELL:
		return false
	match _tool:
		Tool.PAINT:
			return _paint(cell, _value)
		Tool.ERASE:
			return _paint(cell, null)
		Tool.ADD:
			return _add(cell)
	return _remove(cell)


## Ends the stroke. The result has `changed`, `tool`, `key`, `before` and `after` (`{cell: value}`, null = no value),
## `added`, `removed`, `removed_values` (`{cell: {key: value}}`: all that the removed cells held) and `layout` (the
## layout this stroke made, or null). A stroke that changed nothing takes its layout back out.
func finish() -> Dictionary:
	_active = false
	var changed := not (_before.is_empty() and _added.is_empty() and _removed.is_empty())
	var made := _layout
	if not changed and made != null:
		_board.layout = null
		made = null
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
	}


func _paint(cell: Vector2i, value: Variant) -> bool:
	if not _board.has_cell(cell):
		return false
	var current: Variant = _board.get_value(cell, _key)
	if current == value:
		return false
	if not _before.has(cell):
		_before[cell] = current
	_after[cell] = value
	_board.paint(_key, {cell: value})
	return true


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
