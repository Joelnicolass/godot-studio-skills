# GridKit changes

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
