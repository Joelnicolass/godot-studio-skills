# grasskit_lab

- **What**: a small Godot project that runs GrassKit's example and tests without any game.
- **Not**: a game. `addons/grass_kit` is a symlink to the kit's own copy.
- **Talks to**: nothing else. The tests build their own scenes; `test_examples` plays the example through its own keys and methods.
- **Check**: `godot --headless --path grasskit_lab --script res://addons/grass_kit/tests/grass_test_runner.gd` gives `GRASSKIT TESTS PASS (n)`.
  - One file: `-- --only=test_field`.
  - After adding a script with a new `class_name`, import once first: `godot --headless --path grasskit_lab --import`.
- **Editor check**: `GRASSKIT_EDITOR_CHECK=1 godot --headless --editor --path grasskit_lab` drives a real editor (the grass around the 3D view, the flat-ground warning, Bake ground, the clearing's gizmo) and prints `EDITOR CHECK PASS`. The lab's own plugin `addons/grasskit_editor_check` does it; it does nothing without that variable.
  - `GRASSKIT_EDITOR_SHOTS=<folder> godot --editor --path grasskit_lab` (with a window) saves what the 3D view shows.
- **Shader globals**: `project.godot` declares GrassKit's (as the plugin does when enabled), so the example's ground shader compiles from the start.
- **Play**: open the project. F5 runs `grass_3d`; `godot --rendering-method gl_compatibility --path grasskit_lab` runs it in Compatibility.
