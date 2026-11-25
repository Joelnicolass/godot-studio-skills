---
description: "Boards of hexagons or squares (GridKit addon): the grid as data, the saved map as a GridLayout painted in the editor's 3D view, one scene per cell with click and hover, and cursors that mark cells."
---

Add a **board of hexagons or squares** to the **game's Godot project** with the GridKit addon:
- a `GridBoard` with the board's shape (hexagons or squares, size or radius) or with a saved `GridLayout`;
- a `GridView3D` child with one scene per cell (`tiles`);
- a `GridCursor` for each thing that gets marked (valid moves, selection, hover);
- the game's grid (`CellGrid`) for the rules, if the game has rules about cells.

Then the person paints the map with the **GridKit** bar in the 3D view; the agent builds the board and wires what a click does.

This is **not** the game's rules, units, fog or turns: the kit knows cells, neighbors, distance, range and paths, and the game decides what they mean. **Not** the network.

Load: `godot-grid-kit`, `godot-composition-first`.

If `addons/grid_kit/` is missing:

```bash
./install.sh --addon /ABS/GODOT_ROOT grid_kit
```

Enable **GridKit**. If `godot-studio-workflow` is loaded: orchestrator → tree (this chat for 1–3 files; otherwise `studio-tech-lead`) → OK → `studio-developer`. No extra subagent.

## 1. Scope

If missing, ask in one batch:

1. The shape: hexagons or squares (with or without diagonals), what size or radius, and the width of a cell.
2. The values per cell: terrain, and what else (owner, cost to enter, height); which tile is drawn for each value.
3. Whether the map is painted by hand in the editor (a `GridLayout`) or built by the game (generated, loaded from a file, over the network).
4. What a click does and what hover marks; which cursors are needed (moves, selection, path).
5. Whether there are rules about cells (range, cost to move, paths): who owns them and where in the game they live.
6. Whether the game is networked or turn-based (the kit brings neither: the game connects).

## 2. Plan

Show the file tree before touching the game (`[+]` new, `[~]` changed, `[-]` deleted), for example:

```
[~] project.godot                        # GridKit plugin
[+] maps/level_1.tres                    # GridLayout: the shape and the terrain (painted with the GridKit bar)
[+] tiles/plain.tscn, forest.tscn, water.tscn   # one scene per value of terrain
[+] board/board.tscn                    # GridBoard (layout) → GridView3D (tiles) → Moves, Hover (GridCursor)
[+] board/board.gd                      # click → Moves.highlight(cells_in_range); hover → Hover
[~] levels/level/level.tscn                    # instances the board and the camera
[~] game/rules.gd                        # uses a CellGrid: find_path with the terrain's cost
```

Start from `addons/grid_kit/examples/minimal_3d` (hexagons, map in a `GridLayout`) or `squares_3d` (squares, range and path).

## 3. Implement

Follow [godot-grid-kit](../skills/godot-grid-kit/SKILL.md) and `addons/grid_kit/README.md`.

- The `GridBoard` with its shape or with `layout`; the `GridView3D` with `tiles`, `default_tile` and `value_key`.
- Tiles are scenes with a `Node3D` root; `cell_size` is the width, side to side (hexagons), or the side (squares).
- Rules use a `CellGrid` (`board.grid`, or the match state's with `board.use_grid`), not the nodes: `neighbors`, `distance`, `cells_in_range`, `find_path(from, to, cost)`, `flood`.
- One `GridCursor` per meaning, with `highlight(cells)` and `clear()`.
- If the cells have heights: `height_key` (for example `height`) and `height_scale` on the `GridBoard`; everything that stands on the board is placed with `board.cell_to_position(cell)`, which already carries the height. Tiles are solid downward.
- Tell the person how to paint: selecting the `GridBoard` shows the **GridKit** bar (a tile, **Erase**, **Add cells**, **Remove cells**, and **Raise**, **Lower** and **Set height** for heights); a stroke undoes with Ctrl+Z; what is painted is stored in the `layout`.
- Run `godot --headless --path gridkit_lab --script res://addons/grid_kit/tests/grid_test_runner.gd` if you touch the kit.

## 4. Done when

- The `GridBoard` shows no warnings and the person painted (or knows how to paint) the map with the **GridKit** bar.
- F6: the board is drawn with one tile per cell; a click and hover mark what the scope asked for.
- Rules run with no nodes on a `CellGrid`.
- No game rules, units, turns or network inside `addons/grid_kit`.
