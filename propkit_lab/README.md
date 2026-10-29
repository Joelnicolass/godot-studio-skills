# propkit_lab

- **What**: a small Godot project that runs PropKit's examples and tests without any game.
- **Not**: a game. `addons/prop_kit` is a symlink to the kit's own copy.
- **Talks to**: nothing else. The tests build their own scenes; `test_examples` plays both examples through their own methods (chop, new forest).
- **Check**: `godot --headless --path propkit_lab --script res://addons/prop_kit/tests/prop_test_runner.gd` gives `PROPKIT TESTS PASS (n)`.
  - One file: `-- --only=test_nav_zones_3d`.
  - After adding a script with a new `class_name`, import once first: `godot --headless --path propkit_lab --import`.
- **Play**: open the project. F5 runs `forest_3d`; `grove_2d` is the 2D version.
