# rtskit_lab

What: a small Godot project that runs RtsKit's examples and tests without any game.
Not: a game. `addons/rts_kit` is a symlink to the kit's canonical copy.
Talks to: nothing else; the tests build their own scenes, and `test_examples` plays the three examples (`minimal_2d`, `skirmish_3d`, `skirmish_2d`) through mouse and key events.
Check: `godot --headless --path rtskit_lab --script res://addons/rts_kit/tests/rts_test_runner.gd` → `RTSKIT TESTS PASS (n)`. One file: `-- --only=test_orders`. After adding a script with a new `class_name`, import once first (`godot --headless --path rtskit_lab --import`).
Play: open the project (F5 runs `skirmish_3d`; `skirmish_2d` is the version with no radial menu).
