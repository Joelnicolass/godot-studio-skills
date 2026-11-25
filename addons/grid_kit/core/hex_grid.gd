class_name HexGrid
extends RefCounted

## A hexagonal board as plain data: no nodes, no scene. Pointy-top hexes addressed in odd-r offset coordinates,
## `Vector2i(column, row)`, where odd rows sit half a cell to the right. Cells hold values by key, and the board answers
## neighbors, distance, range, paths and flood fills. A game keeps one in its rules; `GridBoard` wraps one for the
## editor and the views.

## It changed a value of a cell.
signal value_changed(cell: Vector2i, key: StringName, value: Variant)
## A cell was added to the board or taken out of it.
signal cells_changed

enum Shape { HEX_POINTY }

## Returned when there is no cell (a pick outside the board).
const NO_CELL := Vector2i(-2147483648, -2147483648)
const SQRT3 := 1.7320508075688772
## Cube directions in a fixed order (east, north-east, north-west, west, south-west, south-east): every list this class
## returns follows it, so results never depend on dictionary order.
const CUBE_DIRECTIONS: Array[Vector3i] = [
	Vector3i(1, 0, -1),
	Vector3i(1, -1, 0),
	Vector3i(0, -1, 1),
	Vector3i(-1, 0, 1),
	Vector3i(-1, 1, 0),
	Vector3i(0, 1, -1),
]

var shape := Shape.HEX_POINTY

var _cells: Dictionary[Vector2i, Dictionary] = {}


## A board of `columns` × `rows` cells, from (0, 0) to (columns - 1, rows - 1).
static func rect(columns: int, rows: int) -> HexGrid:
	var grid := HexGrid.new()
	for row in rows:
		for column in columns:
			grid.add_cell(Vector2i(column, row))
	return grid


## A hexagon-shaped board: every cell within `radius` of (0, 0). Coordinates can be negative.
static func hexagon(radius: int) -> HexGrid:
	var grid := HexGrid.new()
	for q in range(-radius, radius + 1):
		for r in range(maxi(-radius, -q - radius), mini(radius, -q + radius) + 1):
			grid.add_cell(from_cube(Vector3i(q, r, -q - r)))
	return grid


## Rebuilds a board from `to_dict()`.
static func from_dict(data: Dictionary) -> HexGrid:
	var grid := HexGrid.new()
	grid.shape = int(data.get("shape", Shape.HEX_POINTY)) as Shape
	for entry: Array in data.get("cells", []):
		var cell := Vector2i(int(entry[0]), int(entry[1]))
		grid.add_cell(cell)
		var values: Dictionary = entry[2]
		for key: Variant in values:
			grid._cells[cell][StringName(key)] = values[key]
	return grid


static func to_cube(cell: Vector2i) -> Vector3i:
	var q := cell.x - (cell.y - (cell.y & 1)) / 2
	return Vector3i(q, cell.y, -q - cell.y)


static func from_cube(cube: Vector3i) -> Vector2i:
	return Vector2i(cube.x + (cube.y - (cube.y & 1)) / 2, cube.y)


## Steps between two cells, ignoring what is on the board.
static func distance(a: Vector2i, b: Vector2i) -> int:
	var d := to_cube(a) - to_cube(b)
	return maxi(absi(d.x), maxi(absi(d.y), absi(d.z)))


## The center of `cell` on the board plane, with `cell_size` the width of a hex (side to side).
static func cell_to_local(cell: Vector2i, cell_size: float) -> Vector2:
	return Vector2(cell_size * (cell.x + 0.5 * (cell.y & 1)), cell_size * SQRT3 * 0.5 * cell.y)


## The cell under `point` on the board plane (it may not be on the board: check `has_cell`).
static func local_to_cell(point: Vector2, cell_size: float) -> Vector2i:
	var radius := cell_size / SQRT3
	var q := (SQRT3 / 3.0 * point.x - point.y / 3.0) / radius
	var r := (2.0 / 3.0 * point.y) / radius
	return from_cube(_cube_round(q, r, -q - r))


static func _cube_round(q: float, r: float, s: float) -> Vector3i:
	var rq := roundi(q)
	var rr := roundi(r)
	var rs := roundi(s)
	var dq := absf(rq - q)
	var dr := absf(rr - r)
	var ds := absf(rs - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	else:
		rs = -rq - rr
	return Vector3i(rq, rr, rs)


## Adds `cell` to the board (no values). Emits `cells_changed` when it was not there.
func add_cell(cell: Vector2i) -> void:
	if not _cells.has(cell):
		_cells[cell] = {}
		cells_changed.emit()


## Takes `cell` and its values out of the board. Emits `cells_changed` when it was there.
func remove_cell(cell: Vector2i) -> void:
	if _cells.erase(cell):
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
		push_error("HexGrid: %s is not on the board" % cell)
		return
	var values: Dictionary = _cells[cell]
	if values.has(key) and values[key] == value:
		return
	values[key] = value
	value_changed.emit(cell, key, value)


func get_value(cell: Vector2i, key: StringName, default: Variant = null) -> Variant:
	if not _cells.has(cell):
		return default
	return (_cells[cell] as Dictionary).get(key, default)


## A copy of every value of `cell`.
func values(cell: Vector2i) -> Dictionary:
	return (_cells.get(cell, {}) as Dictionary).duplicate()


## The board cells next to `cell`, in CUBE_DIRECTIONS order.
func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var list: Array[Vector2i] = []
	var cube := to_cube(cell)
	for direction in CUBE_DIRECTIONS:
		var next := from_cube(cube + direction)
		if _cells.has(next):
			list.append(next)
	return list


## The board cells at `radius` steps or fewer from `cell`, `cell` included, sorted by row and then column.
func cells_in_range(cell: Vector2i, radius: int) -> Array[Vector2i]:
	var list: Array[Vector2i] = []
	var center := to_cube(cell)
	for q in range(-radius, radius + 1):
		for r in range(maxi(-radius, -q - radius), mini(radius, -q + radius) + 1):
			var next := from_cube(center + Vector3i(q, r, -q - r))
			if _cells.has(next):
				list.append(next)
	list.sort_custom(_before)
	return list


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


## Plain data for a save or a network snapshot: `{"shape": int, "cells": [[column, row, {key: value}], ...]}`.
func to_dict() -> Dictionary:
	var list: Array = []
	for cell in cells():
		list.append([cell.x, cell.y, (_cells[cell] as Dictionary).duplicate()])
	return {"shape": shape, "cells": list}


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
