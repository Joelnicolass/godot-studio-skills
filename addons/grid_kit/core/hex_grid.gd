class_name HexGrid
extends CellGrid

## A hexagonal board as plain data. Pointy-top hexes addressed in odd-r offset coordinates, `Vector2i(column, row)`,
## where odd rows sit half a cell to the right. Everything else (values, paths, flood, to_dict) comes from `CellGrid`.
## `cell_size` is the width of a hex, side to side.

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


## A board of `columns` × `rows` cells, from (0, 0) to (columns - 1, rows - 1).
static func rect(columns: int, rows: int) -> HexGrid:
	var grid := HexGrid.new()
	var list: Array[Vector2i] = []
	for row in rows:
		for column in columns:
			list.append(Vector2i(column, row))
	grid.add_cells(list)
	return grid


## A hexagon-shaped board: every cell within `radius` of (0, 0). Coordinates can be negative.
static func hexagon(radius: int) -> HexGrid:
	var grid := HexGrid.new()
	var list: Array[Vector2i] = []
	for q in range(-radius, radius + 1):
		for r in range(maxi(-radius, -q - radius), mini(radius, -q + radius) + 1):
			list.append(from_cube(Vector3i(q, r, -q - r)))
	grid.add_cells(list)
	return grid


static func to_cube(cell: Vector2i) -> Vector3i:
	var q := cell.x - (cell.y - (cell.y & 1)) / 2
	return Vector3i(q, cell.y, -q - cell.y)


static func from_cube(cube: Vector3i) -> Vector2i:
	return Vector2i(cube.x + (cube.y - (cube.y & 1)) / 2, cube.y)


func shape_name() -> StringName:
	return &"hex"


## Steps between two cells, ignoring what is on the board.
func distance(a: Vector2i, b: Vector2i) -> int:
	var d := to_cube(a) - to_cube(b)
	return maxi(absi(d.x), maxi(absi(d.y), absi(d.z)))


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


## The center of `cell` on the board plane, with `cell_size` the width of a hex (side to side).
func cell_to_local(cell: Vector2i, cell_size: float) -> Vector2:
	return Vector2(cell_size * (cell.x + 0.5 * (cell.y & 1)), cell_size * SQRT3 * 0.5 * cell.y)


## The cell under `point` on the board plane (it may not be on the board: check `has_cell`).
func local_to_cell(point: Vector2, cell_size: float) -> Vector2i:
	var radius := cell_size / SQRT3
	var q := (SQRT3 / 3.0 * point.x - point.y / 3.0) / radius
	var r := (2.0 / 3.0 * point.y) / radius
	return from_cube(_cube_round(q, r, -q - r))


## The six corners of a hex around its center (pointy-top).
func cell_outline(cell_size: float) -> PackedVector2Array:
	var corners := PackedVector2Array()
	var radius := cell_size / SQRT3
	for i in 6:
		var angle := deg_to_rad(60.0 * i + 30.0)
		corners.append(Vector2(cos(angle), sin(angle)) * radius)
	return corners


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
