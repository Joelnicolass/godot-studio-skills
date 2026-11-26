# gridkit_lab

- **What it is:** a tiny Godot project that runs GridKit's examples and tests without any game.
- **What it is not:** a game. `addons/grid_kit` is a symlink to the kit's canonical copy.
- **Who talks to whom:** no one else. The tests build their own trees, and `test_examples` plays `minimal_3d` (hexagons, map from `map.tres`) and `squares_3d` (squares) and `fog_3d` (two players' fog) with mouse events.
- **Verify:** `godot --headless --path gridkit_lab --script res://addons/grid_kit/tests/grid_test_runner.gd` → `GRIDKIT TESTS PASS (n)`. The first time, import once before (`godot --headless --path gridkit_lab --import`).
- **Play:** open the project. F5 runs `minimal_3d`; F6 on `squares_3d.tscn` runs the squares one and on `fog_3d.tscn` the fog one.
- **Editor check:** `godot --headless --editor --path gridkit_lab -- --gridkit-editor-check` → `GRIDKIT EDITOR CHECK PASS (n)`. The `editor_check` plugin only acts with that argument (without it, opening the lab is normal). It opens temporary copies of a scene with a `.tres` layout and one with no layout, selects the board and the view, presses the bar's buttons (tiles, cells and heights), sends mouse events to the 3D view (also over a tall cell) looks at the undo history and the files on disk, and tries the fog (it does not cover the map in the editor; **Preview** shows it and gives the tiles back); it deletes the copies at the end. It is the only check that goes through the real editor and it does **not replace** looking at the bar with your own eyes.
- **Paint:** open `minimal_3d.tscn`, select `Board` and use the **GridKit** bar of the 3D view (the plugin is already enabled in this project). It is the one thing the tests do not cover: it needs the editor open.
