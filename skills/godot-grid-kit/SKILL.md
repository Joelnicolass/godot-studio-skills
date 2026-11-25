---
name: godot-grid-kit
description: >-
  Boards of hexagons or squares in a Godot 4 3D game, with the GridKit addon:
  the grid as plain data (CellGrid: HexGrid and SquareGrid, with values per
  cell, neighbors, distance, range, paths with cost and flood fills), the map as
  a resource you save (GridLayout), a GridBoard that shows it, a GridView3D that
  draws one scene per cell and reports clicks and hover with no colliders,
  GridCursor to mark cells, and a brush in the editor's 3D view to paint the
  terrain, raise and lower the height of each cell and add or remove cells
  with undo. Use when the user wants a board, a
  hex or square grid, a turn-based strategy, tactics or board game or a puzzle
  on a grid, to paint a map in the editor, paths or movement ranges on a grid,
  or /add-grid. Not the game's rules, units, fog, turns or the network.
---

# Godot — boards of hexagons or squares (GridKit)

`addons/grid_kit/` addon in the **game** project. Reference: `addons/grid_kit/README.md`.

If the addon is missing:

```bash
./install.sh --addon /path/to/godot-project grid_kit
```

Enable the **GridKit** plugin (the brush bar in the 3D view; the nodes work without it). Scoped request: `/add-grid`. Composition: [godot-composition-first](../godot-composition-first/SKILL.md).

## Rules

- **Two shapes, one API.** `HexGrid` (pointy-top, odd-r) and `SquareGrid` (`diagonals` off: 4 neighbors and Manhattan; on: 8 and Chebyshev). Pick it with `shape` on the `GridBoard`. Game code does not ask the shape: it uses `grid.neighbors`, `grid.distance`, `grid.cells_in_range`.
- **Rules use the grid, not the nodes.** Match state keeps a `CellGrid` and the board shows it with `board.use_grid(state.grid)`. Rules run headless and the view updates itself from `value_changed`.
- **The map is a `GridLayout`.** A shape and terrain made by hand go in a layout (`GridBoard.layout`), not in a `_ready` that paints cell by cell nor in a dictionary of the game's. The game plays a copy: the `.tres` is not touched in play.
- **Paint in the editor.** Selecting the `GridBoard` shows the **GridKit** bar in the 3D view: a button per key of `tiles`, **Erase**, **Add cells**, **Remove cells**, and for heights **Raise**, **Lower** and **Set height**. A stroke is one undo step. If there is no layout, the first stroke makes one.
- **Heights are a value of the cell.** `height_key` on the `GridBoard` (for example `height`; empty: flat) and `height_scale`. `cell_to_position` already carries the height in Y: tiles, cursors and the game's pieces are placed with it and compute no heights. Clicks pick the cell you see (a tall one hides the low one behind it). They are painted with the bar, not in a `_ready`.
- **Values per cell are keys.** `board.set_value(cell, &"terrain", &"forest")`; which tile is drawn is chosen by the view's `value_key`. Other keys (owner, cost) are read by the game.
- **Paths and ranges.** `find_path(from, to, cost)` with `cost` as `func(from, to) -> float` (`INF` is impassable); `cells_in_range`, `flood`. All in a fixed order (row, then column): the same result every run.
- **Clicks without colliders.** `GridView3D.cell_clicked` / `cell_right_clicked` / `cell_hovered` (pick with the left button, order with the right); a camera drag is not a click (`click_max_drag_px`).
- **One cursor per meaning.** One `GridCursor` for valid moves, another for the selection, another for hover.
- **No kit depends on another.** GridKit has no rules, units, turns or network: the game connects.

## Tree

```
Level
├── Camera, Sun
└── Board (GridBoard)              # layout = res://maps/level_1.tres, or shape + columns × rows
    └── View (GridView3D)          # tiles = {plain, forest, water}; value_key = terrain
        ├── Moves (GridCursor)     # the valid moves
        └── Hover (GridCursor)     # the cell under the pointer
```

Start from `addons/grid_kit/examples/minimal_3d/minimal_3d.tscn` (hexagons, map in a `GridLayout`) or `squares_3d` (8 × 8 squares, range and path).

## What goes where

| Kit | Game |
|---|---|
| The grid: cells, values, neighbors, distance, range, paths, flood | What each value means (terrain, owner, cost) and the rules that use them |
| `GridLayout`: the saved map, and the brush that paints it | Which maps exist and which one loads; the match state |
| One scene per cell and the click and hover signals | The tile scenes, the units on the board, what a click does |
| Marking cells (`GridCursor`) | Which ones to mark and when |

## Essential API

Clicking a cell marks the ones within 2 steps, and cell (2, 3) becomes forest. The three `@export`s are assigned in the inspector:

```gdscript
@export var board: GridBoard
@export var view: GridView3D
@export var moves: GridCursor

func _ready() -> void:
	board.set_value(Vector2i(2, 3), &"terrain", &"forest")
	view.cell_clicked.connect(_on_cell_clicked)

func _on_cell_clicked(cell: Vector2i) -> void:
	moves.highlight(board.cells_in_range(cell, 2))
```

| Piece | What you use |
|---|---|
| `CellGrid` (`HexGrid.rect/hexagon`, `SquareGrid.rect/disc`) | `set_value`, `get_value`, `erase_value`, `neighbors(cell, on_board_only)`, `neighbor`, `direction_to`, `distance(a, b)`, `cells_in_range`, `find_path`, `flood`, `outline(rings)`, `cells_with(key, value)`, `center_cell`, `add_cells`, `remove_cells`, `to_dict` / `CellGrid.from_dict`, `value_changed`, `cells_changed` |
| `GridLayout` | `make_grid()` (a copy), `GridLayout.from_grid(grid)`, `set_value`, `erase_value`, `add_cell`, `remove_cell` |
| `GridBoard` | `layout`, `shape`, `diagonals`, `columns`, `rows`, `radius`, `cell_size`, `height_key`, `height_scale`; `use_grid(grid)`, `paint(key, {cell: value})`, `set_cells(add, remove)`, `cell_to_position` (with the height in Y), `cell_height`, `position_to_cell` (X and Z only); `cell_changed`, `rebuilt` |
| `GridView3D` | `tiles`, `default_tile`, `value_key`; `cell_clicked`, `cell_right_clicked`, `cell_hovered`, `tile_created`, `drawn`, `tile_at`, `cell_at_screen`, `cell_at_ray` |
| `GridCursor` | `highlight(cells)`, `clear()`, `highlighted()`; `marker`, `color`, `lift`, `fill` |

## Done when

- The `GridBoard` shows no warnings and the person saw the **GridKit** bar (or knows it shows up when the board is selected).
- F6: the board is drawn with its tiles, a click marks what the game wants and hover follows the pointer.
- The game's rules run with no node at all (`HexGrid.rect(…)` or `layout.make_grid()`).
- `godot --headless --path gridkit_lab --script res://addons/grid_kit/tests/grid_test_runner.gd` prints `GRIDKIT TESTS PASS` (in the kit's repo).

## Anti-patterns

- Asking the shape in game code (`if grid is HexGrid`): use the grid's `neighbors`, `distance` and `cells_in_range`.
- Computing distance by hand (`abs(a.x - b.x) + …`): on hexagons it is not that. `grid.distance(a, b)`.
- A map painted in a `_ready` cell by cell: it goes in a `GridLayout` painted in the editor.
- Changing the `GridLayout` in play expecting the board to follow: the board plays a copy. Match state goes in its grid.
- Game rules (movement, weapon range, who owns what) inside the kit's nodes: they go in the game.
- One cursor per cell instead of one cursor per meaning.
- Adding the height by hand (`position.y = height * …`) or moving the tiles from the game: set `height_key` on the `GridBoard` and use `cell_to_position`.
