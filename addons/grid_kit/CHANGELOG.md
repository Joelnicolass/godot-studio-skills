# GridKit changes

## 0.6.0

Heights per cell: plateaus, pits, a taller frame of stones.

- **`GridBoard.height_key` and `height_scale`:** `height_key` says which value of a cell is its height (for example `height`; a number, int or float) and `height_scale` how many world units a height of 1 is worth. `cell_to_position(cell)` returns the height in Y, so tiles, `GridCursor` marks and whatever the game places with `cell_to_position` go up together. `cell_height(cell)` gives the height in world units. A value that is not a number counts as 0, with a warning.
- **Clicks pick what you see.** With heights, `GridView3D.cell_at_ray` and `cell_at_screen` (and with them `cell_clicked`, `cell_hovered` and the editor brush) treat each cell as a column that goes up to its height and pick the first one the ray meets, by its top or by its side. A cell off the board counts as height 0.
- **`position_to_cell` and `position_to_any_cell`** only look at X and Z: height does not change the answer.
- **What changes moves, it is not made again.** When the height of a cell changes (`set_value`, `paint`, undo), its tile and its mark move. Changing `height_key` or `height_scale` emits `rebuilt` and places everything again, as `cell_size` does.
- **Height brush** in the GridKit bar: **Raise** and **Lower** move each cell of the stroke one step up or down (Shift does the opposite) and **Set height** writes a number. A stroke is one undo step and is stored in the `GridLayout`; if the board had no `height_key`, the first stroke sets it to `height`. The editor's 3D view shows the map with its heights.
- **Fix:** `set_value` (on `CellGrid` and on `GridLayout`) failed when replacing a value with one of another type (a text with a number). It now replaces it.

Nothing to update in your project: without a `height_key` the board is flat, and clicks and their cost are the same as before.

## 0.5.0

Four queries every game used to write on its own, in `CellGrid` (hexes and squares) and as shortcuts on `GridBoard`:

- **Directions:** `direction_to(a, b)` says which side of `a` holds `b` (0 to 5 on hexes, in `CUBE_DIRECTIONS` order; 0 to 3, or 0 to 7 with diagonals), or -1 when it is not a neighbor. `neighbor(cell, direction)` goes the other way, and `direction_count()` says how many there are.
- **Neighbors off the board:** `neighbors(cell, false)` also returns the ones outside, always in direction order. `outline(rings := 1)` gives the cells around the board: a frame, a fog, a coast.
- **`cells_with(key, value)`:** the cells with that value (a player's start cells). Also on `GridLayout`.
- **`center_cell()`:** the cell closest to the middle of the shape.

Nothing to update in your project: `neighbors(cell)` works as before.

## 0.4.0

- **`GridView3D.tile_created(cell, tile)`:** fires for every tile it makes, already on its cell's center and before it enters the tree, so what you set on it there (its cell, its data) is already there in its `_ready`. Before, the game had to work out the cell from the position.
- **`GridView3D.drawn`:** every tile is in place (after a `rebuilt`, after `tiles`, `default_tile` or `value_key` change, or after `redraw()`). Before, there was no way to know the board had finished drawing.
- **README:** how to see the board in the editor when the grid arrives at runtime (a `layout` or the inspector shape as a preview; `use_grid` replaces it).

Nothing to update in your project.

## 0.3.0

- **Squares as well as hexagons, with the same API.** A new base `CellGrid` (cells, values, `find_path`, `flood`, `to_dict`, signals) with `HexGrid` and `SquareGrid` on top. `SquareGrid` has `diagonals`: off, 4 neighbors and Manhattan distance; on, 8 neighbors and Chebyshev distance. Factories: `HexGrid.rect/hexagon`, `SquareGrid.rect/disc`.
- **`CellGrid.add_cells` / `remove_cells`** emit `cells_changed` once; `erase_value(cell, key)` emits `value_changed` with `null`.
- **`GridLayout`** (`Resource`): the map (shape, diagonals and values per cell) is saved in a `.tres` and assigned to `GridBoard.layout`. `make_grid()` hands out a copy; `read_grid` / `from_grid` copy a grid into the resource.
- **`GridBoard`**: `shape` (Hexagons or Squares), `diagonals`, `radius` works for both shapes, `layout`, `save_shape_as_layout()` (and a **Save shape as layout** button in the GridKit bar, with undo), `grid` is a `CellGrid`, `paint(key, values)`, `set_cells(add, remove, values)` and `position_to_any_cell`. With a layout, the inspector shape is read-only; in the editor, a layout that changes rebuilds the grid once per frame.
- **Brush in the editor's 3D view:** selecting a `GridBoard` or a `GridView3D`, the **GridKit** bar has a button per tile, **Erase**, **Add cells** and **Remove cells**. A stroke is one step of the editor's undo, and what is painted is stored in the `GridLayout` (made on the fly if missing).
- The brush saves a layout that is its own `.tres` when the scene is saved, with Save All or when the game runs, and warns on close if something is unsaved; it only writes the one that really changed.
- **`GridView3D`**: `cell_at_ray(origin, direction, on_board_only)`; erasing a value redraws the cell with `default_tile`; when the board gains or loses cells only those tiles are drawn or freed.
- **`GridCursor`: performance fix.** It no longer recreates all its markers on every `rebuilt`: it handles it once per frame, frees only the marks of cells that are gone and moves the rest. The default marker shares one mesh and one material, and is a hexagon or a square by the board's shape.
- **Breaking (see "Migrating from 0.2" in the README):** `distance`, `cell_to_local` and `local_to_cell` are no longer static (they belong to the grid); `GridBoard.grid` is a `CellGrid`; `to_dict` writes `"shape": "hex"` or `"square"` (`from_dict` also reads the old format, `"shape": 0`); `HexGrid.Shape` is gone (`shape_name()`).
- Examples: `minimal_3d` reads its map from `map.tres`; new `squares_3d`.
- `godot-grid-kit` skill and `/add-grid` command.

## 0.2.0

- `HexGrid.add_cell` and `remove_cell` emit the new `cells_changed` signal, and `GridBoard` relays it as `rebuilt`: `GridView3D` draws or drops the tile of a cell added or removed in play.
- `GridCursor` listens to `rebuilt`: it clears marks on cells that are gone and moves the rest (with a new `cell_size` too).
- README: which queries `GridBoard` has and which go through `board.grid`.
- `gridkit_lab/project.godot`: the same header comment in Spanish and English.

## 0.1.0

First version:

- `HexGrid`: the hex board as plain data (pointy-top, odd-r offset). Values per cell, neighbors, distance, range, paths with costs, flood and `to_dict` / `from_dict`. Results in a fixed order.
- `GridBoard`: builds the grid from the inspector (rectangle or hexagon) or shows your rules' grid (`use_grid`).
- `GridView3D`: one scene per cell from a value. Click or tap without drag (`cell_clicked`) and hover (`cell_hovered`), with no colliders.
- `GridCursor`: marks cells with a hexagon or your own scene.
- Example `examples/minimal_3d`, the kit's own tests and `gridkit_lab/`.
