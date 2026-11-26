# unlockkit_lab

- **What it is:** a tiny Godot project that runs UnlockKit's example and tests without any game.
- **What it is not:** a game. `addons/unlock_kit` is a symlink to the kit's canonical copy.
- **Who talks to whom:** no one else. The tests build their own trees, and `test_examples` plays `minimal` with clicks on the view's boxes and with its buttons.
- **Verify:** `godot --headless --path unlockkit_lab --script res://addons/unlock_kit/tests/unlock_test_runner.gd` → `UNLOCKKIT TESTS PASS (n)`. The first time, import once before (`godot --headless --path unlockkit_lab --import`). The project has the strict typing warnings on (`[debug]` in `project.godot`).
- **Editor check:** `godot --headless --editor --path unlockkit_lab -- --unlockkit-editor-check` → `UNLOCKKIT EDITOR CHECK PASS (n)`. The `editor_check` plugin only acts with that argument (without it, opening the lab is normal). It opens a temporary copy of `minimal.tscn` in the editor, checks that the view draws one box per entry, changes the entries' values the way the inspector does (`view_position`, `cost`, `start_unlocked`, a `requires` that closes a circle) and renames one the way the Scene dock does, undoes with Ctrl+Z, saves with the editor's own save and deletes the copy at the end. It is the only check that goes through the real editor and it does **not replace** looking at the view with your own eyes.
- **Play:** open the project. F5 runs `minimal`; open `minimal.tscn` to see the tree drawn in the editor.
