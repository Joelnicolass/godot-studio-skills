# turnkit_lab

- **What it is:** a tiny Godot project that runs TurnKit's example and tests without any game.
- **What it is not:** a game. `addons/turn_kit` is a symlink to the kit's canonical copy.
- **Who talks to whom:** no one else. The tests build their own trees, and `test_examples` plays `minimal` with its buttons.
- **Verify:** `godot --headless --path turnkit_lab --script res://addons/turn_kit/tests/turn_test_runner.gd` → `TURNKIT TESTS PASS (n)`. The first time, import once before (`godot --headless --path turnkit_lab --import`).
- **Play:** open the project. F5 runs `minimal`: three seats, phases (`draw`, `play`), 10 seconds per turn and a rotating first player.
