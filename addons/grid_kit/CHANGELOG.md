# GridKit changes

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
