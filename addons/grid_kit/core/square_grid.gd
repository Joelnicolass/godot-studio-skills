class_name SquareGrid
extends CellGrid

## A board of squares as plain data, addressed with `Vector2i(column, row)`; north is the row before. Everything else
## (values, paths, flood, to_dict) comes from `CellGrid`. `cell_size` is the side of a square, and the center of
## cell (0, 0) is the origin.

## Steps to the four sides, in a fixed order: east, north, west, south.
const STRAIGHT_STEPS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1)]
## Steps to the four corners, in a fixed order: north-east, north-west, south-west, south-east.
const DIAGONAL_STEPS: Array[Vector2i] = [Vector2i(1, -1), Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, 1)]

## Off: a cell has 4 neighbors and distance counts sides (Manhattan). On: it has 8 and a diagonal step counts as 1
## (Chebyshev).
var diagonals := false


## A board of `columns` × `rows` cells, from (0, 0) to (columns - 1, rows - 1).
static func rect(columns: int, rows: int, with_diagonals := false) -> SquareGrid:
	var grid := SquareGrid.new()
	grid.diagonals = with_diagonals
	var list: Array[Vector2i] = []
	for row in rows:
		for column in columns:
			list.append(Vector2i(column, row))
	grid.add_cells(list)
	return grid


## A board of every cell within `radius` steps of (0, 0) (a diamond; a square when diagonals are on). Coordinates can be
## negative.
static func disc(radius: int, with_diagonals := false) -> SquareGrid:
	var grid := SquareGrid.new()
	grid.diagonals = with_diagonals
	var list: Array[Vector2i] = []
	for row in range(-radius, radius + 1):
		for column in range(-radius, radius + 1):
			var cell := Vector2i(column, row)
			if grid.distance(cell, Vector2i.ZERO) <= radius:
				list.append(cell)
	grid.add_cells(list)
	return grid


func shape_name() -> StringName:
	return &"square"


## Steps between two cells, ignoring what is on the board.
func distance(a: Vector2i, b: Vector2i) -> int:
	var d := (a - b).abs()
	return maxi(d.x, d.y) if diagonals else d.x + d.y


## The board cells next to `cell`: east, north, west, south and, with diagonals, north-east, north-west, south-west,
## south-east.
func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var list: Array[Vector2i] = []
	for step in STRAIGHT_STEPS:
		if _cells.has(cell + step):
			list.append(cell + step)
	if diagonals:
		for step in DIAGONAL_STEPS:
			if _cells.has(cell + step):
				list.append(cell + step)
	return list


## The board cells at `radius` steps or fewer from `cell`, `cell` included, sorted by row and then column.
func cells_in_range(cell: Vector2i, radius: int) -> Array[Vector2i]:
	var list: Array[Vector2i] = []
	for row in range(cell.y - radius, cell.y + radius + 1):
		for column in range(cell.x - radius, cell.x + radius + 1):
			var next := Vector2i(column, row)
			if _cells.has(next) and distance(cell, next) <= radius:
				list.append(next)
	return list


## The center of `cell` on the board plane, with `cell_size` the side of a square.
func cell_to_local(cell: Vector2i, cell_size: float) -> Vector2:
	return Vector2(cell) * cell_size


## The cell under `point` on the board plane (it may not be on the board: check `has_cell`).
func local_to_cell(point: Vector2, cell_size: float) -> Vector2i:
	return Vector2i(floori(point.x / cell_size + 0.5), floori(point.y / cell_size + 0.5))


## The four corners of a square around its center.
func cell_outline(cell_size: float) -> PackedVector2Array:
	var half := cell_size * 0.5
	return PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])


func _shape_data() -> Dictionary:
	return {"diagonals": diagonals}
