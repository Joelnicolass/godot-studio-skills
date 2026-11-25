# GridKit

Boards of hexagons **or squares** for strategy, tactics, board games or puzzles, with the same API for both shapes. Three levels:

- **`CellGrid`** (`HexGrid` and `SquareGrid`): the board as plain data (`RefCounted`, no nodes, no scene). It holds values per cell and answers neighbors, distance, range, paths and flood fills. Your game's rules use it directly, and it tests headless.
- **`GridLayout`**: the map (the shape and the values of every cell) as a `Resource` you save to a `.tres`.
- **Nodes to show it and paint it:**
  - `GridBoard` builds or shows a grid, from the inspector or from a `GridLayout`.
  - `GridView3D` draws it with one scene per cell and reports clicks and hover.
  - `GridCursor` marks cells.
  - A **brush in the editor's 3D view** paints the values of the cells and adds or removes cells.

GridKit has **no** game rules, no units, no fog, no network and no autoload.

## Install

```bash
./install.sh --addon /path/to/godot-project grid_kit
```

Enable the **GridKit** plugin (types `GridBoard`, `GridView3D` and `GridCursor` in Create Node, and the brush bar in the 3D view).

## In 3 steps

**In the editor**

1. Add a `GridBoard` and pick its shape in the inspector: `shape` (Hexagons or Squares), `columns` × `rows`, or `radius`. Pick `cell_size` too.
2. Give it a `GridView3D` child. In `tiles`, put one scene per value (for example `plain`, `forest`, `water`); in `value_key`, the key that picks the scene (`terrain` by default).
3. Select the `GridBoard` and paint with the **GridKit** bar of the 3D view. Save the scene: the map is stored in it. To keep it in its own file, save it as a `.tres` from the inspector.

**In code**

Clicking a cell marks its neighbors, and cell (2, 3) becomes forest. The three `@export`s are assigned in the inspector:

```gdscript
@export var board: GridBoard
@export var view: GridView3D
@export var moves: GridCursor


func _ready() -> void:
	board.set_value(Vector2i(2, 3), &"terrain", &"forest")
	view.cell_clicked.connect(_on_cell_clicked)


func _on_cell_clicked(cell: Vector2i) -> void:
	moves.highlight(board.neighbors(cell))
```

## Painting the map in the editor

Select a `GridBoard` (or its `GridView3D`) and the **GridKit** bar shows up on top of the 3D view:

| Button | What it does |
| --- | --- |
| One button per key of `tiles` (for example `plain`, `water`) | Paints that tile: writes that key into the `value_key` value of the cell |
| **Erase** | Deletes the value: the cell goes back to `default_tile` |
| **Add cells** | Adds cells, also next to the edge of the board |
| **Remove cells** | Removes cells and all their values |
| **Save shape as layout** | (A button, not a tool.) Makes a `GridLayout` from the current shape and assigns it to `layout`, without painting. Only enabled when the board has no `layout`. It is one undo step |

- **One tool at a time.** With none on, the editor behaves as usual: selection and gizmos do not change. Escape lets go of the tool.
- **A stroke** is pressing the left button, dragging and releasing. You see it live while you drag, and it is **one step** of the editor's undo and redo (Ctrl+Z). Going over a cell twice in the same stroke counts once. The editor camera (middle or right button) keeps working.
- **Where it is stored.** What you paint is written into a `GridLayout`. If the `GridBoard` had no `layout`, the first stroke makes one from its current shape and assigns it (undo takes it out again). It stays as a sub-resource inside the scene. To keep it in its own file: in the inspector, right-click `layout` → *Save*.
- **Saving the map.** A layout that is a `.tres` file is saved to its own file when you save the scene (Ctrl+S), with Save All, or when you run the game (F5, F6). A layout inside the scene is saved with it. If you close with a painted map unsaved, the editor asks. A `.tres` is only written if the brush really changed it: painting and undoing back to the original state leaves it alone.
- **With a `layout`, the layout rules.** `shape`, `diagonals`, `columns`, `rows` and `radius` become read-only. To turn the current shape into a layout without painting, use the **Save shape as layout** button of the bar.
- **The bar rebuilds itself** when the tiles in `tiles` change.
- **In play, the layout is not touched.** The `GridBoard` plays a copy: what the game changes with `set_value` never goes back to the `.tres`.

## Examples

- `examples/minimal_3d/minimal_3d.tscn` (F6): a hexagon of radius 4 with water on the rim, plain, forest and mountain, read from `map.tres` (a `GridLayout`). A click marks the cell and its 6 neighbors, and the pointer marks the cell under it.

```
Minimal3D                 # minimal_3d.gd: only connects the signals; its @export (board, view, selection, hover) point at the nodes below
├── Camera, Sun
└── Board                 # GridBoard: layout = map.tres
    └── View              # GridView3D: tiles = {plain, forest, mountain, water}
        ├── Selection     # yellow GridCursor
        └── Hover         # white GridCursor
```

- `examples/squares_3d/squares_3d.tscn` (F6): an 8 × 8 board of squares with two tiles. A click marks the cells within 2 steps (`cells_in_range`) and the path from the previous click (`find_path`).

## Coordinates

**Hexagons**

- **Pointy-top** in **offset odd-r** coordinates: `Vector2i(column, row)`, with odd rows shifted half a cell to the right.
- Inside, the math uses cube coordinates (`HexGrid.to_cube` / `from_cube`).
- Neighbors, in a fixed order: east, north-east, north-west, west, south-west, south-east (`HexGrid.CUBE_DIRECTIONS`).
- Distance: steps between cells (cube). `cell_size` is the width, side to side.

**Squares**

- `Vector2i(column, row)`; north is the previous row (`row - 1`).
- Neighbors, in a fixed order: east, north, west, south and, with `diagonals`, then north-east, north-west, south-west, south-east.
- Distance: without diagonals, **Manhattan** (4 neighbors); with diagonals, **Chebyshev** (8 neighbors, a diagonal step counts as 1). `cells_in_range` uses the same distance. `cell_size` is the side.

**Both**

- In 3D the board lies on the XZ plane: the column grows along X and the row along Z. The center of cell (0, 0) is the origin.
- `CellGrid.NO_CELL` means "no cell", for example a click outside the board.
- Lists always come back in the same order: by row, then by column. So results never depend on dictionary order, and a seeded match replays the same.

## API

### `CellGrid` (RefCounted): what both shapes share

| Member | What it does |
| --- | --- |
| `add_cell`, `remove_cell`, `has_cell`, `size()`, `cells()` | The cells of the board. Adding or removing one emits `cells_changed` |
| `add_cells(list)` / `remove_cells(list)` | The same for many cells, with **one** `cells_changed` |
| `set_value(cell, key, value)`, `get_value(cell, key, default)`, `values(cell)` | Values per cell and key (`StringName`) |
| `erase_value(cell, key)` | Takes a value out. Emits `value_changed` with `null` |
| `neighbors(cell, on_board_only := true)` | The neighbors, in direction order. With `on_board_only` off also the ones off the board: always `direction_count()` cells, and the index is the direction |
| `direction_count()`, `neighbor(cell, direction)` | How many neighbors a cell has (6 on hexes; 4, or 8 with diagonals) and the cell one step that way, on the board or not |
| `direction_to(a, b)` | Which side of `a` holds `b` (the direction), or -1 when it is not a neighbor |
| `outline(rings := 1)` | The cells around the board, `rings` deep (on squares touching a corner is enough). For a frame, a fog or a coast |
| `cells_with(key, value)` | The cells with that value (the start cells: `cells_with(&"start", seat)`). A `String` and a `StringName` with the same text match, and so do an int and a float with the same number |
| `center_cell()` | The cell closest to the middle of the shape (the average of the centers), or `NO_CELL` on an empty board |
| `distance(a, b)` | Steps between two cells (a method of the grid: it depends on the shape) |
| `cells_in_range(cell, radius)` | The cells at `radius` steps or fewer, `cell` included |
| `find_path(from, to, cost)` | The cheapest path (A*). `cost` is `func(from, to) -> float`; `INF` or a negative value is impassable. Without `cost`, every step costs 1 |
| `flood(cell, accepts)` | The cells connected to `cell` that satisfy `accepts(cell) -> bool` |
| `cell_to_local(cell, cell_size)` / `local_to_cell(point, cell_size)` | From the center of a cell to the plane, and from the plane to a cell |
| `cell_outline(cell_size)` | The corners of a cell around its center |
| `shape_name()` | `&"hex"` or `&"square"` |
| `to_dict()` / `CellGrid.from_dict(data)` | Plain data to save or send over the network. `from_dict` returns a `HexGrid` or a `SquareGrid` according to `"shape"` and also reads the 0.2 format |
| `CellGrid.NO_CELL` | "No cell" |
| signal `value_changed(cell, key, value)` | A value changed or was erased (`null`) |
| signal `cells_changed` | Cells were added or removed |

`to_dict()` returns `{"shape": "hex" | "square", "diagonals": bool (squares only), "cells": [[column, row, {key: value}], …]}`.

### `HexGrid` (extends `CellGrid`)

| Member | What it does |
| --- | --- |
| `HexGrid.rect(columns, rows)` / `HexGrid.hexagon(radius)` | A rectangular board, or a hexagonal one centered on (0, 0) |
| `HexGrid.to_cube(cell)` / `from_cube(cube)` | Cube coordinates (static) |
| `HexGrid.CUBE_DIRECTIONS` | The six directions, in neighbor order |

### `SquareGrid` (extends `CellGrid`)

| Member | What it does |
| --- | --- |
| `SquareGrid.rect(columns, rows, diagonals := false)` | A rectangular board, from (0, 0) to (columns - 1, rows - 1) |
| `SquareGrid.disc(radius, diagonals := false)` | Every cell within `radius` steps of (0, 0): a diamond, or a square with diagonals |
| `diagonals` | Off: 4 neighbors and Manhattan distance. On: 8 neighbors and Chebyshev distance |

### `GridLayout` (Resource)

| Member | What it does |
| --- | --- |
| `shape` (`HEX` or `SQUARE`), `diagonals` | The shape (diagonals for squares only) |
| `cells` | `Dictionary[Vector2i, Dictionary]`: every cell and its values. The shape of the map is its keys |
| `make_grid()` | A **new** grid with these cells and values. It is a copy: the game changes it without touching the resource. It returns a `CellGrid`; if your state types the shape, `layout.make_grid() as HexGrid` (or `as SquareGrid`) |
| `read_grid(grid)` / `GridLayout.from_grid(grid)` | Copies the shape and the values of a grid into the resource |
| `has_cell`, `add_cell`, `remove_cell` | Edit the cells |
| `set_value(cell, key, value)`, `erase_value(cell, key)`, `get_value(cell, key, default)` | Edit the values (`set_value` adds the cell if it is not there) |
| signal `changed` | Every edit emits it (the `Resource` one) |

### `GridBoard` (Node)

- **Inspector:** `layout`, `shape` (Hexagons or Squares), `diagonals` (squares only), `columns`, `rows`, `radius` (above 0: every cell within `radius` steps of (0, 0), in both shapes) and `cell_size`. With a `layout`, the grid comes from the layout and the inspector shape does not apply. `save_shape_as_layout()` makes a layout from the current shape (in the editor, the button of the GridKit bar does the same, with undo).
- **Grid:** `grid` is the `CellGrid` it shows. `use_grid(grid)` shows your rules' grid instead of its own, and `use_own_grid()` goes back to the one from the layout or the inspector.
- **Queries:** `has_cell`, `cells`, `set_value`, `get_value`, `neighbors`, `neighbor`, `direction_to`, `distance`, `cells_in_range`, `find_path`, `flood`, `outline`, `cells_with` and `center_cell`, plus `cell_to_position(cell) -> Vector3`, `position_to_cell(point) -> Vector2i` (`NO_CELL` off the board) and `position_to_any_cell(point)` (the cell under the point even if it is not on the board). The rest (`values`, `size`, `add_cell`, `erase_value`, `to_dict`) goes through `board.grid`.
- **Editing many at once:** `paint(key, {cell: value})` (a `null` value deletes the key) and `set_cells(add, remove, values)` (`values` is `{cell: {key: value}}` for the new cells). In the editor, with a `layout`, they write the layout too; in play, only the grid.
- **Signals:** `cell_changed(cell, key, value)` and `rebuilt` (another grid, another shape or `cell_size`, or cells added or removed). Views and cursors update themselves with it.

### `GridView3D` (Node3D, child of a `GridBoard`)

- **Inspector:**
  - `tiles`: `Dictionary[StringName, PackedScene]`.
  - `default_tile` and `value_key`.
  - `input_enabled`.
  - `click_max_drag_px`: if the pointer moves more than this between press and release, it is a drag, not a click.
  - `camera`: if empty, it uses the current camera.
- **Methods:** `redraw()`, `tile_at(cell)`, `cell_at_screen(point)`, `cell_at_ray(origin, direction, on_board_only := true)` and `board()`.
- **Signals:** `cell_clicked(cell)` (mouse or touch) and `cell_hovered(cell)` (`NO_CELL` when it leaves the board); `tile_created(cell, tile)` when it makes a tile, and `drawn` when every tile is in place.
- **Each tile knows its cell.** The tile already sits on its cell's center when `tile_created` fires, and it is not in the tree yet: what you set on it there (its cell, its data) is already there in its `_ready`. `drawn` fires after a `rebuilt`, after `tiles`, `default_tile` or `value_key` change, or after `redraw()`; a cell whose value changes emits only `tile_created`.
- **Clicks without colliders:** the camera ray meets the board plane.
- When the board gains or loses cells, only those tiles are drawn or freed. Erasing a value (`erase_value`) sends the cell back to `default_tile`.

### `GridCursor` (Node3D, child of a `GridView3D`)

- **Inspector:**
  - `marker`: the marker scene. If empty, it draws a flat hexagon or square (by the board's shape) in the chosen `color`.
  - `color`, `lift` and `fill`.
- **Methods:** `highlight(cells)` (replaces the previous marks), `clear()` and `highlighted()`.
- When the board changes (`rebuilt`), the cursor handles it **once per frame**: marks on cells that are gone are freed and the rest move into place (none is made again). The default marker shares one mesh and one material among all marks.
- Use one cursor per meaning: valid moves, selection, hover.

## Tips

- **Rules use `CellGrid`, not the nodes.** Keep the grid in your match state and show it with `board.use_grid(state.grid)`. Rules then run headless, and the view updates itself from `value_changed`. With no node at all: `layout.make_grid()` or `HexGrid.rect(…)` / `SquareGrid.rect(…)`.
- **See the board in the editor even when the grid arrives at runtime.** Leave a `layout` (or the columns and rows) on the `GridBoard`: that is what the editor shows, and `use_grid` replaces it at runtime.
- **A camera drag is not a click.** Tune `click_max_drag_px`. If your camera has its own drag state, turn `input_enabled` off while it drags.
- **Tiles from other packs.** If they come flat-top, rotate them 90° in their scene. For hexagons `cell_size` is the width, side to side; for squares, the side.
- **Many cells at once.** `add_cells` and `remove_cells` emit one signal; `add_cell` in a loop emits one per cell (views and cursors still group what they draw into one frame).
- **A map of your own.** Load the layout with `ResourceLoader.load` or assign it in the inspector; to build one in code: `layout.set_value(cell, &"terrain", &"forest")`, or `GridLayout.from_grid(grid)` and `ResourceSaver.save(layout, "res://map.tres")`.

## Migrating from 0.2

| Before (0.2) | Now (0.3) |
| --- | --- |
| `HexGrid.distance(a, b)` (static) | `grid.distance(a, b)` (on the grid; the board too: `board.distance(a, b)`) |
| `HexGrid.cell_to_local(cell, size)` / `local_to_cell(point, size)` (static) | `grid.cell_to_local(cell, size)` / `grid.local_to_cell(point, size)` |
| `GridBoard.grid` is a `HexGrid` | It is a `CellGrid` (a `HexGrid` or a `SquareGrid`) |
| `to_dict()` with `"shape": 0` | `"shape": "hex"` (or `"square"`). `CellGrid.from_dict` reads the old format |
| `HexGrid.from_dict(data)` | `CellGrid.from_dict(data)` (returns whatever the data says; `HexGrid.from_dict` still works) |
| `HexGrid.NO_CELL`, `HexGrid.Shape` | `CellGrid.NO_CELL` (`HexGrid.NO_CELL` works too); `shape_name()` replaces `Shape` |
| A map of your own (rows of letters, a dictionary) painted in `_ready` | A `GridLayout`: `layout.set_value(cell, &"terrain", …)` once, or `GridLayout.from_grid(grid)` and `ResourceSaver.save`; assign it to `GridBoard.layout` |
| `GridBoard.radius` hexagons only | Works for both shapes |
| `GridView3D.cell_at_screen` | Unchanged; `cell_at_ray(origin, direction)` is what it uses inside |

## Tests

```bash
godot --headless --path gridkit_lab --script res://addons/grid_kit/tests/grid_test_runner.gd
```

It prints `GRIDKIT TESTS PASS (n)`. The tests cover:

- Hexagons and squares: shapes and coordinates, neighbors (4 and 8, in order), distance, range, paths with cost, with and without diagonals, flood, cell ↔ point round trips, directions (`direction_to`, `neighbor`), neighbors off the board, `outline` (corners included on squares), `cells_with` (text and numbers of different types) and `center_cell`.
- `CellGrid`: `from_dict` picks the class and reads the 0.2 format, `add_cells` emits once, `erase_value`.
- `GridLayout`: `make_grid`, `read_grid`, `from_grid`, `changed` and saving and loading a `.tres`.
- The nodes: shape from the inspector, `radius` on squares, the layout rules, grouped rebuild, `paint` and `set_cells` (with and without a layout), `position_to_any_cell`, tiles per cell, `tile_created` and `drawn`, redraw, `use_grid`, `cell_at_ray`, click, drag and editor warnings.
- `GridCursor`: the same nodes after 1000 `add_cell`, only the mark of a removed cell is freed, `cell_size` moves without recreating, square marker.
- The brush stroke (no editor): paint, repeat, erase, add and remove cells with their values, making the layout, and that its result undoes everything.
- Both examples played with mouse events.
- That the addon names no other kit.

What the tests do **not** cover (it needs an open editor with a mouse): the GridKit bar, the real drag and the editor's real undo.
