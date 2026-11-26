# gesturekit_lab

- **What it is:** a tiny Godot project that runs GestureKit's example and tests without any game.
- **What it is not:** a game. `addons/gesture_kit` is a symlink to the kit's canonical copy.
- **Who talks to whom:** no one else. The tests build their own trees and send the fingers through Godot's own input (`Input.parse_input_event`). `test_examples` plays `minimal` with fingers at a touch screen's pace.
- **Verify:** `godot --headless --path gesturekit_lab --script res://addons/gesture_kit/tests/gesture_test_runner.gd` → `GESTUREKIT TESTS PASS (n)`. The first time, import once before (`godot --headless --path gesturekit_lab --import`). The project has the strict GDScript warnings on (`untyped_declaration` and `unsafe_*`).
- **Install into an empty project:** make a folder with a minimal `project.godot`, run `./install.sh --addon-only <folder> gesture_kit` from the repo root, import it (`godot --headless --path <folder> --import`) and run the kit's tests there (`--script res://addons/gesture_kit/tests/gesture_test_runner.gd`). It must print the same `PASS`.
- **Play:** open the project and press F5 to run `minimal`. With the mouse, a click is a finger, Alt + drag is two and Alt + Shift + drag moves them together. On a phone, export it or use Godot's remote deploy.
- **Editor check:** `godot --headless --editor --path gesturekit_lab -- --gesturekit-editor-check` → `GESTUREKIT EDITOR CHECK PASS (n)`.
  - The `editor_check` plugin only acts with that argument; without it, the lab opens normally.
  - It checks that `GestureArea` is registered with its icon and opens `minimal.tscn` in the 2D view.
  - It checks that the inspector shows `units` and the thresholds.
  - It edits the area from the inspector: a threshold that reaches the reader and is undone with the shortcut, an action that does not exist (a warning), one that does, and `mouse_filter` on `Ignore` (a warning, and it is undone).
  - It never saves the example: it saves a copy in `editor_check/tmp`, checks it and deletes it. At the end it checks that the example on disk did not change.
  - It is the only check that goes through the real editor and it **does not replace** trying the gestures with your fingers.
