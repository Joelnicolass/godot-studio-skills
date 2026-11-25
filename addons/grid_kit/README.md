# GridKit

Hex boards for strategy, tactics, board games or puzzles, at two levels:

- **`HexGrid`**: the board as plain data (`RefCounted`, no nodes, no scene). It holds values per cell and answers neighbors, distance, range, paths and flood fills. Your game's rules use it directly, and it tests headless.
- **Nodes to show it:**
  - `GridBoard` builds or shows a `HexGrid`.
  - `GridView3D` draws it with one scene per cell and reports clicks and hover.
  - `GridCursor` marks cells.

GridKit has **no** game rules, no units, no fog, no network and no autoload.

## Install

```bash
./install.sh --addon /path/to/godot-project grid_kit
```

Enable the **GridKit** plugin (types `GridBoard`, `GridView3D` and `GridCursor` in Create Node).

## In 3 steps

1. Add a `GridBoard` and pick its shape in the inspector: `columns` × `rows`, or `radius` for a hexagon. Pick `cell_size` too: the width of one hex, side to side.
2. Give it a `GridView3D` child. In `tiles`, put one scene per value (for example `plain`, `forest`, `water`); in `value_key`, the key that picks the scene (`terrain` by default).
3. Connect `cell_clicked` and query the board:

```gdscript
@onready var board: GridBoard = $Board
@onready var moves: GridCursor = $Board/View/Moves


func _ready() -> void:
	board.set_value(Vector2i(2, 3), &"terrain", &"forest")
	$Board/View.cell_clicked.connect(_on_cell_clicked)


func _on_cell_clicked(cell: Vector2i) -> void:
	moves.highlight(board.neighbors(cell))
```

## Minimal example

`examples/minimal_3d/minimal_3d.tscn` (F6): a hexagon of radius 4 with water on the rim, plains, forest and mountains. A click marks the cell and its 6 neighbors; the pointer marks the cell under it.

```
Minimal3D                 # minimal_3d.gd: paints the terrain, connects the signals
├── Camera, Sun
└── Board                 # GridBoard: radius = 4
    └── View              # GridView3D: tiles = {plain, forest, mountain, water}
        ├── Selection     # yellow GridCursor
        └── Hover         # white GridCursor
```

## Coordinates

- **Pointy-top** hexes in **odd-r offset** coordinates: `Vector2i(column, row)`, with odd rows shifted half a cell to the right.
- The math runs in cube coordinates (`HexGrid.to_cube` / `from_cube`).
- In 3D the board lies on the XZ plane: columns go along X and rows along Z.
- `HexGrid.NO_CELL` means "no cell", for example a click off the board.
- Lists always come back in the same order: by row, then by column. Neighbors come in the fixed `CUBE_DIRECTIONS` order. Results never depend on dictionary order, so a seeded match plays the same every time.

## API

### `HexGrid` (RefCounted)

| Member | What it does |
| --- | --- |
| `HexGrid.rect(columns, rows)` / `HexGrid.hexagon(radius)` | A rectangular board, or a hexagonal one centered on (0, 0) |
| `add_cell`, `remove_cell`, `has_cell`, `size()`, `cells()` | The board's cells. Adding or removing one emits `cells_changed` |
| `set_value(cell, key, value)`, `get_value(cell, key, default)`, `values(cell)` | Values per cell and key (`StringName`) |
| `neighbors(cell)` | The neighbors that are on the board |
| `HexGrid.distance(a, b)` | Steps between two cells |
| `cells_in_range(cell, radius)` | The cells `radius` steps away or fewer, `cell` included |
| `find_path(from, to, cost)` | The cheapest path (A*). `cost` is `func(from, to) -> float`; `INF` or a negative value is impassable. Without `cost`, every step costs 1 |
| `flood(cell, accepts)` | The cells connected to `cell` that pass `accepts(cell) -> bool` |
| `HexGrid.cell_to_local(cell, cell_size)` / `local_to_cell(point, cell_size)` | From a cell center to the plane, and from the plane to a cell |
| `to_dict()` / `HexGrid.from_dict(data)` | Plain data to save or send over the network |
| signal `value_changed(cell, key, value)` | A value changed |
| signal `cells_changed` | A cell was added or removed |

### `GridBoard` (Node)

- **Inspector:** `columns`, `rows`, `radius` (above 0, the board is a hexagon) and `cell_size`.
- **Grid:** `grid` is the `HexGrid` it shows. `use_grid(grid)` shows your rules' grid instead of its own; `use_own_grid()` goes back to the inspector one.
- **Queries:** `has_cell`, `cells`, `set_value`, `get_value`, `neighbors`, `distance`, `cells_in_range`, `find_path` and `flood`, plus `cell_to_position(cell) -> Vector3` and `position_to_cell(point) -> Vector2i`. The rest (`values`, `size`, `add_cell`, `remove_cell`, `to_dict`) goes through `board.grid`.
- **Signals:** `cell_changed(cell, key, value)` and `rebuilt` (another grid, another shape or `cell_size`, or a cell added or removed). Views and cursors follow it on their own.

### `GridView3D` (Node3D, child of a `GridBoard`)

- **Inspector:**
  - `tiles`: `Dictionary[StringName, PackedScene]`.
  - `default_tile` and `value_key`.
  - `input_enabled`.
  - `click_max_drag_px`: if the pointer moves more than this between press and release, it is a drag, not a click.
  - `camera`: empty uses the current camera.
- **Methods:** `redraw()`, `tile_at(cell)`, `cell_at_screen(point)` and `board()`.
- **Signals:** `cell_clicked(cell)` (mouse or touch) and `cell_hovered(cell)` (`NO_CELL` when leaving the board).
- **Picking without colliders:** the camera ray meets the board plane.

### `GridCursor` (Node3D, child of a `GridView3D`)

- **Inspector:**
  - `marker`: the marker scene. Empty draws a flat hexagon in `color`.
  - `color`, `lift` and `fill`.
- **Methods:** `highlight(cells)` (replaces the previous marks), `clear()` and `highlighted()`.
- When the board changes (`rebuilt`), marks on cells that are gone are cleared and the rest move to their place.
- Use one cursor per meaning: valid moves, selection, hover.

## Tips

- **Rules use `HexGrid`, not the nodes.** Keep the grid in your match state and show it with `board.use_grid(state.grid)`. The rules run headless, and the view follows `value_changed` on its own.
- **A camera drag is not a click.** Tune `click_max_drag_px`. If your camera keeps its own drag state, turn `input_enabled` off while it drags.
- **Tiles from other packs.** If they come flat-top, rotate them 90° in their scene. `cell_size` is the side-to-side width.

## Tests

```bash
godot --headless --path gridkit_lab --script res://addons/grid_kit/tests/grid_test_runner.gd
```

It prints `GRIDKIT TESTS PASS (n)`. The tests cover:

- Shapes and coordinates, neighbors, distance, range, paths with costs and flood.
- `to_dict` and `cells_changed`.
- The nodes: a tile per cell, redraws, `use_grid`, cells added and removed in play (tiles and marks), click, drag and editor warnings.
- The example, played with mouse events.
- That the addon names no other kit.
