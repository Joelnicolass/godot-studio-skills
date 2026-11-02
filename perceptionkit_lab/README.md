# perceptionkit_lab

- **What**: a small Godot project that runs PerceptionKit's examples and tests without any game.
- **Not**: a game. `addons/perception_kit` is a symlink to the kit's own copy.
- **Talks to**: nothing else. The tests build their own scenes; `test_examples` plays the three examples (`minimal_3d`, `minimal_2d`, `guards_3d`) through their own keys and methods.
- **Check**: `godot --headless --path perceptionkit_lab --script res://addons/perception_kit/tests/perception_test_runner.gd` gives `PERCEPTIONKIT TESTS PASS (n)`.
  - One file: `-- --only=test_sensor_3d`.
  - After adding a script with a new `class_name`, import once first: `godot --headless --path perceptionkit_lab --import`.
- **Editor check**: `PERCEPTIONKIT_EDITOR_CHECK=1 godot --headless --editor --path perceptionkit_lab` drives a real editor the way a person does and prints `EDITOR CHECK PASS`:
  - the guard's sensor has the kit's gizmo; its sight, angle and eye handles dragged from the 3D view's camera, each undone and redone; a cancelled drag; the lose-under-sight warning; the saved scene keeps the values and no internal shape;
  - the 2D sensor's handles: a press on one grabs it, the drag and release change it as one step that undoes, a press away is left to the editor.

  It works on copies of the examples in `scratch/editor_check/` (the addon's files stay as they are). The lab's own plugin, `addons/perceptionkit_editor_check`, does it; without that variable it does nothing.
- **Layers**: `project.godot` names layer 1 «world», in 2D and 3D. The examples' sensors and targets stay on it, as they come out of the box.
- **How to play**: open the project. F5 runs `guards_3d`; F6 on `minimal_3d` or `minimal_2d`.
