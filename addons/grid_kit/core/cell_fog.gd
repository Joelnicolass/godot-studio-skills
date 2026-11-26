class_name CellFog
extends RefCounted

## What each observer knows of a board, as plain data: no nodes, no scene. An observer is a whole number from 0 up (a
## player's seat, a team). Every cell is, for each observer, HIDDEN (never seen), EXPLORED (seen before, not now) or
## VISIBLE (seen now). Cells are `Vector2i` like those of `CellGrid`, so it works on hexes and squares alike; it does
## not need the board. A game keeps one in its rules and saves it with `to_dict`; `GridFog` wraps one and draws it.
## Every signal lists the cells that changed, sorted by row and then column.

## These cells of `observer` are VISIBLE now and were not before.
signal revealed(observer: int, cells: Array[Vector2i])
## These cells of `observer` were VISIBLE and are EXPLORED now: seen before, not now. `explored` follows with them.
signal faded(observer: int, cells: Array[Vector2i])
## These cells of `observer` are EXPLORED now and were not before: they faded from view, or `explore` made them known.
signal explored(observer: int, cells: Array[Vector2i])
## Every cell of `observer` is HIDDEN again (`clear`, `clear_observer`).
signal cleared(observer: int)

enum State { HIDDEN, EXPLORED, VISIBLE }

# Observer → {cell: State}. Only EXPLORED and VISIBLE cells are stored: a cell that is not here is HIDDEN.
var _known: Dictionary[int, Dictionary] = {}


## What `observer` knows of `cell`: `State.HIDDEN`, `State.EXPLORED` or `State.VISIBLE`.
func state(observer: int, cell: Vector2i) -> State:
	var cells: Dictionary = _known.get(observer, {})
	return cells.get(cell, State.HIDDEN)


## `observer` sees `cell` now: what is on it shows.
func sees(observer: int, cell: Vector2i) -> bool:
	return state(observer, cell) == State.VISIBLE


## `observer` has seen `cell` at some time, or sees it now: its terrain shows.
func knows(observer: int, cell: Vector2i) -> bool:
	return state(observer, cell) != State.HIDDEN


## `observer` sees `cells` now, as well as what it saw already. Emits `revealed` with the cells that were not visible.
func reveal(observer: int, cells: Array[Vector2i]) -> void:
	if not _valid(observer, "reveal"):
		return
	var known := _cells_of(observer)
	var shown: Array[Vector2i] = []
	for cell in _unique(cells):
		if known.get(cell, State.HIDDEN) != State.VISIBLE:
			known[cell] = State.VISIBLE
			shown.append(cell)
	if not shown.is_empty():
		shown.sort_custom(_before)
		revealed.emit(observer, shown)


## `observer` knows the terrain of `cells` without seeing them now (a region turned face up, a map). Visible cells stay
## visible. Emits `explored` with the cells that were hidden.
func explore(observer: int, cells: Array[Vector2i]) -> void:
	if not _valid(observer, "explore"):
		return
	var known := _cells_of(observer)
	var learned: Array[Vector2i] = []
	for cell in _unique(cells):
		if not known.has(cell):
			known[cell] = State.EXPLORED
			learned.append(cell)
	if not learned.is_empty():
		learned.sort_custom(_before)
		explored.emit(observer, learned)


## `observer` sees exactly `cells` now: what it saw and no longer does is EXPLORED. The usual call once a turn or after
## every move, with what the observer's units see. Emits `faded` and `explored` (the same cells) and then `revealed`,
## each with the cells that changed only.
func see(observer: int, cells: Array[Vector2i]) -> void:
	if not _valid(observer, "see"):
		return
	var known := _cells_of(observer)
	var wanted: Dictionary[Vector2i, bool] = {}
	for cell in cells:
		wanted[cell] = true
	var gone: Array[Vector2i] = []
	for cell: Vector2i in known:
		if known[cell] == State.VISIBLE and not wanted.has(cell):
			gone.append(cell)
	gone.sort_custom(_before)
	for cell in gone:
		known[cell] = State.EXPLORED
	if not gone.is_empty():
		faded.emit(observer, gone)
		explored.emit(observer, gone)
	reveal(observer, cells)


## Nothing is VISIBLE to `observer` any more: what it saw is EXPLORED. Emits `faded` and `explored`.
func clear_visible(observer: int) -> void:
	see(observer, [] as Array[Vector2i])


## Every cell of every observer is HIDDEN again, as at the start. Emits `cleared` per observer that knew something.
func clear() -> void:
	for observer in observers():
		clear_observer(observer)


## Every cell of `observer` is HIDDEN again; the others keep what they know. Emits `cleared` if it knew something.
func clear_observer(observer: int) -> void:
	var had: Dictionary = _known.get(observer, {})
	_known.erase(observer)
	if not had.is_empty():
		cleared.emit(observer)


## The cells `observer` sees now, sorted by row and then column.
func visible_cells(observer: int) -> Array[Vector2i]:
	return _cells_in(observer, State.VISIBLE)


## The cells `observer` saw before and does not see now, sorted by row and then column. Hidden cells are not listed:
## the fog does not know the board (ask the board for the cells that are neither).
func explored_cells(observer: int) -> Array[Vector2i]:
	return _cells_in(observer, State.EXPLORED)


## Every observer that knows at least one cell, sorted.
func observers() -> Array[int]:
	var list: Array[int] = []
	for observer: int in _known:
		if not (_known[observer] as Dictionary).is_empty():
			list.append(observer)
	list.sort()
	return list


## What one observer knows, as plain data: `{"visible": [[column, row], ...], "explored": [[column, row], ...]}`. Send
## each player only theirs: `to_dict` holds every observer's, which a rival must not get in a game of hidden
## information.
func observer_to_dict(observer: int) -> Dictionary:
	return {"visible": _pairs(visible_cells(observer)), "explored": _pairs(explored_cells(observer))}


## Replaces what `observer` knows with `observer_to_dict()` data (also after a trip through JSON). Emits `cleared` and
## then `explored` and `revealed` with what it knows now, so a view redraws.
func set_observer_from_dict(observer: int, data: Dictionary) -> void:
	if not _valid(observer, "set_observer_from_dict"):
		return
	clear_observer(observer)
	var cells := _read_cells(data)
	if cells.is_empty():
		return
	_known[observer] = cells
	var learned := explored_cells(observer)
	if not learned.is_empty():
		explored.emit(observer, learned)
	var shown := visible_cells(observer)
	if not shown.is_empty():
		revealed.emit(observer, shown)


## Plain data for a save or a replay check, with every observer:
## `{"observers": [{"observer": 0, "visible": [[column, row], ...], "explored": [[column, row], ...]}, ...]}`, sorted.
## To send one player what they know, use `observer_to_dict`.
func to_dict() -> Dictionary:
	var list: Array = []
	for observer in observers():
		var entry := observer_to_dict(observer)
		entry["observer"] = observer
		list.append(entry)
	return {"observers": list}


## Rebuilds a fog from `to_dict()`, also after a trip through JSON (numbers as floats). No signal is emitted.
static func from_dict(data: Dictionary) -> CellFog:
	var fog := CellFog.new()
	for entry: Dictionary in data.get("observers", []):
		var cells := _read_cells(entry)
		var observer := int(entry.get("observer", 0))
		if not cells.is_empty() and observer >= 0:
			fog._known[observer] = cells
	return fog


func _valid(observer: int, what: String) -> bool:
	if observer < 0:
		push_error("CellFog.%s: an observer is a number from 0 up (%d)" % [what, observer])
		return false
	return true


func _cells_of(observer: int) -> Dictionary:
	if not _known.has(observer):
		_known[observer] = {}
	return _known[observer]


func _cells_in(observer: int, wanted: State) -> Array[Vector2i]:
	var list: Array[Vector2i] = []
	var cells: Dictionary = _known.get(observer, {})
	for cell: Vector2i in cells:
		if cells[cell] == wanted:
			list.append(cell)
	list.sort_custom(_before)
	return list


static func _read_cells(data: Dictionary) -> Dictionary:
	var cells: Dictionary = {}
	for pair: Array in data.get("explored", []):
		cells[Vector2i(int(pair[0]), int(pair[1]))] = State.EXPLORED
	for pair: Array in data.get("visible", []):
		cells[Vector2i(int(pair[0]), int(pair[1]))] = State.VISIBLE
	return cells


# The cells in their first order, each once.
static func _unique(cells: Array[Vector2i]) -> Array[Vector2i]:
	var seen: Dictionary[Vector2i, bool] = {}
	var list: Array[Vector2i] = []
	for cell in cells:
		if not seen.has(cell):
			seen[cell] = true
			list.append(cell)
	return list


static func _pairs(cells: Array[Vector2i]) -> Array:
	var list: Array = []
	for cell in cells:
		list.append([cell.x, cell.y])
	return list


static func _before(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)
