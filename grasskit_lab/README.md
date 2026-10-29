# grasskit_lab

- **What**: a small Godot project that runs GrassKit's example and tests without any game.
- **Not**: a game. `addons/grass_kit` is a symlink to the kit's own copy.
- **Talks to**: nothing else. The tests build their own scenes; `test_examples` plays the example through its own keys and methods.
- **Check**: `godot --headless --path grasskit_lab --script res://addons/grass_kit/tests/grass_test_runner.gd` gives `GRASSKIT TESTS PASS (n)`.
  - One file: `-- --only=test_field`.
  - After adding a script with a new `class_name`, import once first: `godot --headless --path grasskit_lab --import`.
- **Editor check**: `GRASSKIT_EDITOR_CHECK=1 godot --headless --editor --path grasskit_lab` drives a real editor the way a person does and prints `EDITOR CHECK PASS`:
  - the grass around the 3D view, the flat-ground warning, Bake ground and its undo;
  - selecting the field, painting with the mouse (Ctrl erases), undo and redo, the keys, saving the scene;
  - the Kind brush, the menu's Fill and Clear;
  - the area's and a clearing's handles;
  - a new field setting itself up, a quality preset button.

  It works on a copy of the example in `scratch/editor_check/` (the addon's files stay as they are). The lab's own plugin `addons/grasskit_editor_check` does it; it does nothing without that variable.
  - `GRASSKIT_EDITOR_SHOTS=<folder> godot --editor --path grasskit_lab` (with a window) saves what the 3D view shows, and the whole editor while a brush is up.
- **Shader globals**: `project.godot` declares GrassKit's (as the plugin does), so the example's ground shader compiles from the start.
- **Play**: open the project. F5 runs `grass_3d`; `godot --rendering-method gl_compatibility --path grasskit_lab` runs it in Compatibility.
