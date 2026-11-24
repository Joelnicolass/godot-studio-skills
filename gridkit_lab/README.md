# gridkit_lab

- **What it is:** a tiny Godot project that runs GridKit's example and tests without any game.
- **What it is not:** a game. `addons/grid_kit` is a symlink to the kit's canonical copy.
- **Who talks to whom:** no one else. The tests build their own trees, and `test_examples` plays `minimal_3d` with mouse events.
- **Verify:** `godot --headless --path gridkit_lab --script res://addons/grid_kit/tests/grid_test_runner.gd` → `GRIDKIT TESTS PASS (n)`. The first time, import once before (`godot --headless --path gridkit_lab --import`).
- **Play:** open the project. F5 runs `minimal_3d`.
