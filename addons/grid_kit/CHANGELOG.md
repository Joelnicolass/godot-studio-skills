# GridKit changes

## 0.1.0

First version:

- `HexGrid`: the hex board as plain data (pointy-top, odd-r offset). Values per cell, neighbors, distance, range, paths with costs, flood and `to_dict` / `from_dict`. Results in a fixed order.
- `GridBoard`: builds the grid from the inspector (rectangle or hexagon) or shows your rules' grid (`use_grid`).
- `GridView3D`: one scene per cell from a value. Click or tap without drag (`cell_clicked`) and hover (`cell_hovered`), with no colliders.
- `GridCursor`: marks cells with a hexagon or your own scene.
- Example `examples/minimal_3d`, the kit's own tests and `gridkit_lab/`.
