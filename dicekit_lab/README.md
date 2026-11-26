# dicekit_lab

- **What it is:** a tiny Godot project that runs DiceKit's example and tests without any game.
- **What it is not:** a game. `addons/dice_kit` is a symlink to the kit's canonical copy.
- **Who talks to whom:** no one else. The tests build their own trees, and `test_examples` plays `minimal` with its buttons (the same seed twice too).
- **Verify:** `godot --headless --path dicekit_lab --script res://addons/dice_kit/tests/dice_test_runner.gd` → `DICEKIT TESTS PASS (n)`. The first time, import once before (`godot --headless --path dicekit_lab --import`). The project has the strict GDScript warnings on (`untyped_declaration` and `unsafe_*`).
- **Play:** open the project. F5 runs `minimal`.
- **Editor check:** `godot --headless --editor --path dicekit_lab -- --dicekit-editor-check` → `DICEKIT EDITOR CHECK PASS (n)`. The `editor_check` plugin only acts with that argument (without it, opening the lab is normal). It opens `minimal.tscn` in the editor, looks at the tray's dice in the 3D view, changes `rng_seed` and `count` from the inspector (and undoes with the shortcut), presses **Roll** and reads `last_result`. It never saves the example: it saves a copy in `editor_check/tmp`, checks it and deletes it, and at the end checks that the example on disk did not change. It is the only check that goes through the real editor and it **does not replace** looking at the inspector and the 3D view yourself.
