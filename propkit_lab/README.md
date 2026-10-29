# propkit_lab

- **What**: a small Godot project that runs PropKit's examples and tests without any game.
- **Not**: a game. `addons/prop_kit` is a symlink to the kit's own copy.
- **Talks to**: nothing else. The tests build their own scenes; `test_examples` plays both examples through their own methods (chop, new forest).
- **Check**: `godot --headless --path propkit_lab --script res://addons/prop_kit/tests/prop_test_runner.gd` gives `PROPKIT TESTS PASS (n)`.
  - One file: `-- --only=test_nav_zones_3d`.
  - After adding a script with a new `class_name`, import once first: `godot --headless --path propkit_lab --import`.
- **Editor check**: `PROPKIT_EDITOR_CHECK=1 godot --headless --editor --path propkit_lab` drives a real editor (Scatter, Clear, undo and redo, Bake, the stale warning) and prints `EDITOR CHECK PASS`. The lab's own plugin `addons/propkit_editor_check` does it; it does nothing without that variable.
  - `PROPKIT_EDITOR_SHOTS=<folder> godot --editor --path propkit_lab` (with a window, after the check) saves what the 3D and 2D views draw.
- **Tool check**: `tool_check/` is a map whose script uses the lab's autoload (`PropLabGlobals`); `test_tools` bakes it with `tools/bake_scene.tscn`.
- **Play**: open the project. F5 runs `forest_3d`; `grove_2d` is the 2D version.
