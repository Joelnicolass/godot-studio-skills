# spillkit_lab

- **What**: a small Godot project that runs SpillKit's examples and tests without any game.
- **Not**: a game. `addons/spill_kit` is a symlink to the kit's own copy.
- **Renderer**: Compatibility, the web's, because the kit has to work there. The examples look the same with Forward+.
- **Talks to**: nothing else. The tests build their own scenes; `test_examples` plays both examples (`minimal_3d`, `substances_3d`) through their own methods.
- **Check**: `godot --headless --path spillkit_lab --script res://addons/spill_kit/tests/spill_test_runner.gd` gives `SPILLKIT TESTS PASS (n)`.
  - One file: `-- --only=test_source`.
  - After adding a script with a new `class_name`, import once first: `godot --headless --path spillkit_lab --import`.
- **Editor check**: `SPILLKIT_EDITOR_CHECK=1 godot --headless --editor --path spillkit_lab` uses a real editor the way a person does and prints `EDITOR CHECK PASS`:
  - in `minimal_3d`, it presses the Spray, Heavy spray, Die (puddle) and Clear the floor buttons in the inspector; the drops, marks and puddle show on the floor, which the editor's physics finds, and clean up;
  - the component's and the pool's cost lines, and the warning for a component with no type;
  - the saved scene keeps its values and nothing drawn;
  - in a body's scene alone, Spray makes a pool that is not saved.

  It works on copies in `scratch/editor_check/` (the addon's files stay as they are). The lab's own plugin, `addons/spillkit_editor_check`, does it; without that variable it does nothing.
- **Layers**: `project.godot` names layer 1 "floor" and layer 2 "bodies". The examples' floors are on 1 (the pool's `floor_mask`) and the dummies on 2.
- **The paint's textures**: `examples/substances_3d/textures/make_paint_textures.gd` draws them again, with a fixed seed: `godot --headless --path spillkit_lab --script res://addons/spill_kit/examples/substances_3d/textures/make_paint_textures.gd`.
- **How to play**: open the project. F5 runs `substances_3d`; F6 on `minimal_3d`.
