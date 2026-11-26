# statkit_lab

- **What it is:** a tiny Godot project that runs StatKit's example and tests without any game.
- **What it is not:** a game. `addons/stat_kit` is a symlink to the kit's canonical copy.
- **Who talks to whom:** no one else. The tests build their own trees, and `test_examples` plays `minimal` with its buttons (sword, shield, swamp, the two rings and the blessing).
- **Verify:** `godot --headless --path statkit_lab --script res://addons/stat_kit/tests/stat_test_runner.gd` → `STATKIT TESTS PASS (n)`. The first time, import once before (`godot --headless --path statkit_lab --import`).
- **Play:** open the project. F5 runs `minimal`.
- **Editor check:** `godot --headless --editor --path statkit_lab -- --statkit-editor-check` → `STATKIT EDITOR CHECK PASS (n)`. The `editor_check` plugin only acts with that argument (without it, opening the lab is normal). It opens the example, picks `Hero` and reads the values the inspector's **Values** group shows; then it opens a copy in `editor_check/tmp`, changes a modifier's `amount`, `max_values`, `base_values` and `start_modifiers` the way the inspector does, undoes with Cmd/Ctrl+Z, saves the scene and checks that **Values** was not saved. It never writes the example's files (it checks that) and deletes the copy at the end. It is the only check that goes through the real editor and it **does not replace** looking at the inspector with your own eyes.
- **Look at the inspector:** open `minimal.tscn` and pick `Hero`. The **Values** group has the final value of every stat; change `amount` in `modifiers/sword.tres` and the attack changes without running anything.
