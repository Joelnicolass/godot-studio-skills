# platkit_lab

What: a small Godot project that runs PlatKit's example and tests without any game.
Not: a game. `addons/plat_kit` is a symlink to the kit's canonical copy.
Talks to: nothing else; the tests build their own physics worlds, and `test_examples` plays `minimal_2d` with input.
Check: `godot --headless --path platkit_lab --script res://addons/plat_kit/tests/plat_test_runner.gd` → `PLATKIT TESTS PASS (n)`. The first time, import once first (`godot --headless --path platkit_lab --import`).
Play: open the project; F5 runs `minimal_2d`.
