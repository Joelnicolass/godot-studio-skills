extends RefCounted

## Picking on a `GridBoard` whose cells have heights (`height_key`), for `GridView3D`. Each cell is a column that goes
## up to its height, and a cell that is not on the board is a column of height 0. `pick` walks the cells a ray goes
## over, from its origin on, and answers the first one whose column the ray meets: its top, or its side when it stands
## taller than the cell before. It only walks where the ray is over the board and between the lowest and the highest
## cell, so a pick costs the few cells under that stretch, not the whole board.

const STEP := 0.0001
const MAX_CELLS := 8192

var _dirty := true
# The rectangle on the board plane that holds every cell, and the lowest and highest column (0 included).
var _low := Vector2.ZERO
var _high := Vector2.ZERO
var _floor := 0.0
var _top := 0.0
# Room past the lowest and the highest top, for a ray that ends right on one.
var _slack := 0.0
# The sides of one cell around its center: an outward normal each, and how far along it the side is.
var _normals := PackedVector2Array()
var _offsets := PackedFloat64Array()


## The board has other cells, another size or other heights: measure it again on the next pick.
func invalidate() -> void:
	_dirty = true


## One cell now stands at `height` (world units): the stretch walked covers it. Cheaper than measuring again.
func widen(height: float) -> void:
	_floor = minf(_floor, height - _slack)
	_top = maxf(_top, height + _slack)


## The cell a ray meets first, on the board or not; `CellGrid.NO_CELL` when it meets none. `origin` and `direction`
## are in the board's local space.
func pick(board: GridBoard, origin: Vector3, direction: Vector3) -> Vector2i:
	if direction == Vector3.ZERO:
		return CellGrid.NO_CELL
	if _dirty:
		_measure(board)
	var grid := board.grid
	var size := board.cell_size
	var from := Vector2(origin.x, origin.z)
	var along := Vector2(direction.x, direction.z)
	# Where the ray meets Y = 0: the answer wherever no cell of the board is near.
	var ground := -origin.y / direction.y if direction.y != 0.0 else -1.0
	# The ray starts over the surface or under it; the first cell where it gets to the other side is the answer.
	var over := origin.y >= board.cell_height(grid.local_to_cell(from, size))
	var span := _span(origin, direction)
	if span.x <= span.y:
		if ground >= 0.0 and ground < span.x:
			return grid.local_to_cell(from + along * ground, size)
		var nudge := size * STEP / along.length() if along != Vector2.ZERO else 1.0
		var at := span.x
		for _i in MAX_CELLS:
			if at > span.y:
				break
			var cell := grid.local_to_cell(from + along * at, size)
			var leave := _leave(from - grid.cell_to_local(cell, size), along)
			leave = clampf(leave, at, span.y)
			var height := board.cell_height(cell)
			var y_in := origin.y + direction.y * at
			var y_out := origin.y + direction.y * leave
			if (minf(y_in, y_out) <= height) if over else (maxf(y_in, y_out) >= height):
				return cell
			at = leave + nudge
		if ground <= span.y:
			return CellGrid.NO_CELL
	return grid.local_to_cell(from + along * ground, size) if ground >= 0.0 else CellGrid.NO_CELL


# The stretch of the ray (from, to) that is over the board's rectangle and between its lowest and highest column.
# Empty when from > to.
func _span(origin: Vector3, direction: Vector3) -> Vector2:
	var low := Vector3(_low.x, _floor, _low.y)
	var high := Vector3(_high.x, _top, _high.y)
	var from := 0.0
	var to := INF
	for axis in 3:
		if direction[axis] == 0.0:
			if origin[axis] < low[axis] or origin[axis] > high[axis]:
				return Vector2(1.0, 0.0)
			continue
		var a := (low[axis] - origin[axis]) / direction[axis]
		var b := (high[axis] - origin[axis]) / direction[axis]
		from = maxf(from, minf(a, b))
		to = minf(to, maxf(a, b))
	return Vector2(from, to)


# How far along the ray it leaves a cell; `from` is relative to the cell's center. INF for a ray that goes straight up
# or down.
func _leave(from: Vector2, along: Vector2) -> float:
	var leave := INF
	for i in _normals.size():
		var speed := _normals[i].dot(along)
		if speed > 0.0:
			leave = minf(leave, (_offsets[i] - _normals[i].dot(from)) / speed)
	return leave


func _measure(board: GridBoard) -> void:
	_dirty = false
	var grid := board.grid
	var size := board.cell_size
	_low = Vector2.ZERO
	_high = Vector2.ZERO
	_slack = size * 0.01
	_floor = -_slack
	_top = _slack
	var first := true
	for cell in grid.cells():
		var center := grid.cell_to_local(cell, size)
		_low = center if first else _low.min(center)
		_high = center if first else _high.max(center)
		first = false
		widen(board.cell_height(cell))
	# Room for the cells on the edge and for one more around them.
	var margin := Vector2(size, size)
	_low -= margin
	_high += margin
	_normals = PackedVector2Array()
	_offsets = PackedFloat64Array()
	var corners := grid.cell_outline(size)
	for i in corners.size():
		var a := corners[i]
		var b := corners[(i + 1) % corners.size()]
		var normal := (b - a).orthogonal().normalized()
		if normal.dot(a + b) < 0.0:
			normal = -normal
		_normals.append(normal)
		_offsets.append(normal.dot(a))
