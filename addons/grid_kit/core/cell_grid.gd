# gdlint: disable=max-public-methods
class_name CellGrid
extends RefCounted

## A board as plain data, whatever its shape: no nodes, no scene. Cells are addressed with a `Vector2i`
## (column, row) and hold values by key. The board answers neighbors, distance, range, paths and flood fills. This is
## the part every shape shares; `HexGrid` and `SquareGrid` say what a neighbor and a step are. A game keeps one in
## its rules; `GridBoard` wraps one for the editor and the views.

## It changed a value of a cell (`value` is null when the value was erased).
signal value_changed(cell: Vector2i, key: StringName, value: Variant)
## Cells were added to the board or taken out of it (one signal per call, however many cells).
signal cells_changed

## Returned when there is no cell (a pick outside the board).
const NO_CELL := Vector2i(-2147483648, -2147483648)

var _cells: Dictionary[Vector2i, Dictionary] = {}


## Rebuilds a board from `to_dict()`: a `HexGrid` or a `SquareGrid`, whichever the data says. It also reads the data of
## GridKit 0.2 (`"shape": 0` is a hex board). Returns null when the shape is not known.
static func from_dict(data: Dictionary) -> CellGrid:
	var shape: Variant = data.get("shape", "hex")
	var grid: CellGrid = null
	if typeof(shape) == TYPE_STRING or typeof(shape) == TYPE_STRING_NAME:
		match String(shape):
			"hex":
				grid = HexGrid.new()
			"square":
				var square := SquareGrid.new()
				square.diagonals = bool(data.get("diagonals", false))
				grid = square
	elif typeof(shape) == TYPE_INT or typeof(shape) == TYPE_FLOAT:
		if int(shape) == 0:
			grid = HexGrid.new()
	if grid == null:
		push_error("CellGrid: unknown shape %s" % [shape])
		return null
	for entry: Array in data.get("cells", []):
		var cell := Vector2i(int(entry[0]), int(entry[1]))
		var values: Dictionary = {}
		var source: Dictionary = entry[2]
		for key: Variant in source:
			values[StringName(key)] = source[key]
		grid._cells[cell] = values
	return grid


## Steps between two cells, ignoring what is on the board.
func distance(_a: Vector2i, _b: Vector2i) -> int:
	push_error("CellGrid: use a HexGrid or a SquareGrid")
	return 0


## How many cells are next to a cell: 6 on hexes; 4 on squares, or 8 with diagonals.
func direction_count() -> int:
	push_error("CellGrid: use a HexGrid or a SquareGrid")
	return 0


## The cell one step from `cell` toward `direction` (0 to `direction_count() - 1`, in the order each shape documents),
## on the board or not. NO_CELL for a direction out of range.
func neighbor(_cell: Vector2i, _direction: int) -> Vector2i:
	push_error("CellGrid: use a HexGrid or a SquareGrid")
	return NO_CELL


## The board cells next to `cell`, in direction order. With `on_board_only` off it also lists the cells off the board,
## so the list always has `direction_count()` cells and the index is the direction.
func neighbors(cell: Vector2i, on_board_only := true) -> Array[Vector2i]:
	var list: Array[Vector2i] = []
	for direction in direction_count():
		var next := neighbor(cell, direction)
		if not on_board_only or _cells.has(next):
			list.append(next)
	return list


## The direction from `a` to `b` when `b` is next to `a` (on the board or not), or -1.
func direction_to(a: Vector2i, b: Vector2i) -> int:
	for direction in direction_count():
		if neighbor(a, direction) == b:
			return direction
	return -1


## The cells around the board: every cell off the board that touches it (on squares a corner is enough), and with
## `rings` above 1 the cells around those too. Sorted by row and then column. For a frame, a fog border or a coast.
func outline(rings := 1) -> Array[Vector2i]:
	var seen: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in _cells:
		seen[cell] = true
	var frontier := cells()
	var list: Array[Vector2i] = []
	for _ring in maxi(rings, 0):
		var next_ring: Array[Vector2i] = []
		for cell in frontier:
			for next in _touching(cell):
				if not seen.has(next):
					seen[next] = true
					next_ring.append(next)
		list.append_array(next_ring)
		frontier = next_ring
	list.sort_custom(_before)
	return list


## The board cells whose `key` value is `value`, sorted by row and then column. A `String` and a `StringName` with the
## same text match, and so do an int and a float with the same number.
func cells_with(key: StringName, value: Variant) -> Array[Vector2i]:
	var list: Array[Vector2i] = []
	for cell: Vector2i in _cells:
		var cell_values: Dictionary = _cells[cell]
		if cell_values.has(key) and _same_value(cell_values[key], value):
			list.append(cell)
	list.sort_custom(_before)
	return list


## The board cell closest to the middle of the board (the average of the cell centers), or NO_CELL on an empty board.
## A tie goes to the first cell by row and then column.
func center_cell() -> Vector2i:
	if _cells.is_empty():
		return NO_CELL
	var all := cells()
	var middle := Vector2.ZERO
	for cell in all:
		middle += cell_to_local(cell, 1.0)
	middle /= all.size()
	var best := all[0]
	var best_distance := INF
	for cell in all:
		var gap := cell_to_local(cell, 1.0).distance_squared_to(middle)
		if gap < best_distance - 0.000001:
			best = cell
			best_distance = gap
	return best


## The board cells at `radius` steps or fewer from `cell`, `cell` included, sorted by row and then column.
func cells_in_range(_cell: Vector2i, _radius: int) -> Array[Vector2i]:
	push_error("CellGrid: use a HexGrid or a SquareGrid")
	return []


## The center of `cell` on the board plane. `cell_size` is the width of a hex (side to side) or the side of a square.
func cell_to_local(_cell: Vector2i, _cell_size: float) -> Vector2:
	push_error("CellGrid: use a HexGrid or a SquareGrid")
	return Vector2.ZERO


## The cell under `point` on the board plane (it may not be on the board: check `has_cell`).
func local_to_cell(_point: Vector2, _cell_size: float) -> Vector2i:
	push_error("CellGrid: use a HexGrid or a SquareGrid")
	return NO_CELL


## The corners of a cell around its center, in order, for markers and brushes.
func cell_outline(_cell_size: float) -> PackedVector2Array:
	push_error("CellGrid: use a HexGrid or a SquareGrid")
	return PackedVector2Array()


## `&"hex"` or `&"square"`: the shape written in `to_dict()`.
func shape_name() -> StringName:
	return &""


## Adds `cell` to the board (no values). Emits `cells_changed` when it was not there.
func add_cell(cell: Vector2i) -> void:
	if not _cells.has(cell):
		_cells[cell] = {}
		cells_changed.emit()


## Adds many cells and emits `cells_changed` once (and only when one was new).
func add_cells(list: Array[Vector2i]) -> void:
	var changed := false
	for cell in list:
		if not _cells.has(cell):
			_cells[cell] = {}
			changed = true
	if changed:
		cells_changed.emit()


## Takes `cell` and its values out of the board. Emits `cells_changed` when it was there.
func remove_cell(cell: Vector2i) -> void:
	if _cells.erase(cell):
		cells_changed.emit()


## Takes many cells out and emits `cells_changed` once (and only when one was there).
func remove_cells(list: Array[Vector2i]) -> void:
	var changed := false
	for cell in list:
		if _cells.erase(cell):
			changed = true
	if changed:
		cells_changed.emit()


func has_cell(cell: Vector2i) -> bool:
	return _cells.has(cell)


func size() -> int:
	return _cells.size()


## Every cell, sorted by row and then column.
func cells() -> Array[Vector2i]:
	var list: Array[Vector2i] = []
	list.assign(_cells.keys())
	list.sort_custom(_before)
	return list


func set_value(cell: Vector2i, key: StringName, value: Variant) -> void:
	if not _cells.has(cell):
		push_error("CellGrid: %s is not on the board" % cell)
		return
	var values: Dictionary = _cells[cell]
	if values.has(key) and _same_value(values[key], value):
		return
	values[key] = value
	value_changed.emit(cell, key, value)


## Takes the value of `key` out of `cell`. Emits `value_changed` (with null) when it was there.
func erase_value(cell: Vector2i, key: StringName) -> void:
	if not _cells.has(cell):
		return
	var values: Dictionary = _cells[cell]
	if values.erase(key):
		value_changed.emit(cell, key, null)


func get_value(cell: Vector2i, key: StringName, default: Variant = null) -> Variant:
	if not _cells.has(cell):
		return default
	return (_cells[cell] as Dictionary).get(key, default)


## A copy of every value of `cell`.
func values(cell: Vector2i) -> Dictionary:
	return (_cells.get(cell, {}) as Dictionary).duplicate()


## The cheapest path from `from` to `to`, both included; empty when there is none. `cost` is
## `func(from_cell: Vector2i, to_cell: Vector2i) -> float` for one step; INF or a negative value means the step is
## impossible. Without `cost`, every step costs 1. Ties break the same way on every run.
func find_path(from: Vector2i, to: Vector2i, cost: Callable = Callable()) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if not _cells.has(from) or not _cells.has(to):
		return path
	var unit_cost := not cost.is_valid()
	var best: Dictionary[Vector2i, float] = {from: 0.0}
	var came: Dictionary[Vector2i, Vector2i] = {}
	var closed: Dictionary[Vector2i, bool] = {}
	var open: Array[Vector2i] = [from]
	while not open.is_empty():
		var index := _cheapest(open, best, to, unit_cost)
		var current := open[index]
		open.remove_at(index)
		if current == to:
			break
		closed[current] = true
		for next in neighbors(current):
			if closed.has(next):
				continue
			var step := 1.0 if unit_cost else float(cost.call(current, next))
			if step < 0.0 or is_inf(step) or is_nan(step):
				continue
			var total := best[current] + step
			if not best.has(next) or total < best[next]:
				best[next] = total
				came[next] = current
				if not open.has(next):
					open.append(next)
	if not best.has(to):
		return path
	var at := to
	path.append(at)
	while at != from:
		at = came[at]
		path.append(at)
	path.reverse()
	return path


## The board cells connected to `cell` (itself included) for which `accepts(cell) -> bool` is true, sorted by row and
## then column. Empty when `cell` itself is not accepted.
func flood(cell: Vector2i, accepts: Callable) -> Array[Vector2i]:
	var list: Array[Vector2i] = []
	if not _cells.has(cell) or not bool(accepts.call(cell)):
		return list
	var seen: Dictionary[Vector2i, bool] = {cell: true}
	var queue: Array[Vector2i] = [cell]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		list.append(current)
		for next in neighbors(current):
			if not seen.has(next) and bool(accepts.call(next)):
				seen[next] = true
				queue.append(next)
	list.sort_custom(_before)
	return list


## Plain data for a save or a network snapshot:
## `{"shape": "hex" | "square", "diagonals": bool (squares only), "cells": [[column, row, {key: value}], ...]}`.
func to_dict() -> Dictionary:
	var list: Array = []
	for cell in cells():
		list.append([cell.x, cell.y, (_cells[cell] as Dictionary).duplicate()])
	var data: Dictionary = {"shape": String(shape_name())}
	data.merge(_shape_data())
	data["cells"] = list
	return data


## What a shape adds to `to_dict()` besides its name.
func _shape_data() -> Dictionary:
	return {}


# Every cell that shares a side or a corner with `cell`, on the board or not (for `outline`).
func _touching(cell: Vector2i) -> Array[Vector2i]:
	return neighbors(cell, false)


func _cheapest(open: Array[Vector2i], best: Dictionary[Vector2i, float], to: Vector2i, unit_cost: bool) -> int:
	var chosen := 0
	var chosen_score := INF
	for i in open.size():
		var cell := open[i]
		var score := best[cell] + (float(distance(cell, to)) if unit_cost else 0.0)
		if score < chosen_score or (score == chosen_score and _before(cell, open[chosen])):
			chosen = i
			chosen_score = score
	return chosen


static func _before(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)


# Equal values for `set_value` and `cells_with`: text with text and numbers with numbers, whatever their exact type.
# Values of two kinds (a text and a number) are just different: `==` between them is an error.
static func _same_value(a: Variant, b: Variant) -> bool:
	var type_a := typeof(a)
	var type_b := typeof(b)
	if type_a in [TYPE_STRING, TYPE_STRING_NAME] and type_b in [TYPE_STRING, TYPE_STRING_NAME]:
		return String(a) == String(b)
	if type_a in [TYPE_INT, TYPE_FLOAT] and type_b in [TYPE_INT, TYPE_FLOAT]:
		return float(a) == float(b)
	return type_a == type_b and a == b
