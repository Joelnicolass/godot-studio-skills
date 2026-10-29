# fsmkit_lab

What: a small Godot project that runs FsmKit's example and tests without any game.
Not: a game. `addons/fsm_kit` is a symlink to the kit's canonical copy.
Talks to: nothing else; the tests build their own trees, and `test_examples` plays `minimal_2d` with input.
Check: `godot --headless --path fsmkit_lab --script res://addons/fsm_kit/tests/fsm_test_runner.gd` → `FSMKIT TESTS PASS (n)`. The first time, import once first (`godot --headless --path fsmkit_lab --import`).
Play: open the project; F5 runs `minimal_2d`.
