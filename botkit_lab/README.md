# botkit_lab

- **What**: a small Godot project that runs BotKit's examples and tests without any game.
- **Not**: a game. `addons/bot_kit` is a symlink to the kit's own copy.
- **Talks to**: nothing else. The tests build their own floors, walls and navmesh, with characters that read their bot's keys the way a game reads `Input`; `test_examples` plays both examples (`minimal_3d`, `arena_3d`).
- **Check**: `godot --headless --path botkit_lab --script res://addons/bot_kit/tests/bot_test_runner.gd` gives `BOTKIT TESTS PASS (n)`.
  - One file: `-- --only=test_fight`.
  - After adding a script with a new `class_name`, import once first: `godot --headless --path botkit_lab --import`.
- **Editor check**: `BOTKIT_EDITOR_CHECK=1 godot --headless --editor --path botkit_lab` drives a real editor the way a person does and prints `EDITOR CHECK PASS`:
  - the robot's bot has the kit's gizmo; its eye and aim handles dragged from the 3D view's camera, each one undone and redone; a cancelled drag; the warnings; in the editor it presses nothing; the saved scene keeps the values, with no `body` and no drawing;
  - the goal of one of the arena's pickups: its reach handle, undone and redone; the warning without reach.

  It works on copies of the examples in `scratch/editor_check/` (the addon's files stay as they are). The lab's own plugin, `addons/botkit_editor_check`, does it; without that variable it does nothing.
- **Layers**: `project.godot` names layer 1 "world" (the walls, what blocks sight) and layer 2 "characters".
- **How to play**: open the project. F5 runs `arena_3d`; F6 on `minimal_3d`.
