# commandkit_lab

- **What it is:** a tiny Godot project that runs CommandKit's example and tests without any game.
- **What it is not:** a game. `addons/command_kit` is a symlink to the kit's canonical copy.
- **Who talks to whom:** no one else. The tests build their own trees, and `test_examples` plays `minimal` with its buttons.
- **Verify:** `godot --headless --path commandkit_lab --script res://addons/command_kit/tests/command_test_runner.gd` → `COMMANDKIT TESTS PASS (n)`. The first time, import once before (`godot --headless --path commandkit_lab --import`).
- **Play:** open the project. F5 runs `minimal`.
