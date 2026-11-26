# GestureKit changes

## 0.1.0

First version:

- `GestureReader`: the fingers read as gestures, as plain data and with the time it is given (`now`):
  - `tapped` with 1, 2 or 3 fingers;
  - `double_tapped` (it ignores a bounce under 40 ms), and `tap_confirmed` for a tap that was not a double;
  - `long_pressed` and `long_press_ended`, with `hold_progress()`;
  - `swiped` in 4, 8 or any direction (the clock runs from when the fingers start to move; never after a pinch or a twist);
  - `drag_started`, `dragged` and `drag_ended(velocity)`, with `center()`;
  - `pinched` and `twisted` around the fingers.

  Details:
  - One drag per gesture, even when fingers land or lift. `fingers` is the most fingers of the gesture and `fingers_down()` the ones down now.
  - The velocity counts only what came after a pause, and never divides by less than a frame at 120 fps.
  - The two fingers that pinch are read together (also a frame apart), so moving both together is not a pinch.
  - The thresholds stay within their range.
  - `clear()` forgets everything without leaving a finger down.
- `GestureArea` (Control):
  - reads the fingers that land on it, with positions in the viewport's pixels (also with `canvas_items` and in a `SubViewport`);
  - a `Control` on top keeps its own fingers;
  - the thresholds are in the inspector, in viewport pixels or in dp (`units`);
  - each gesture can press and release an Input Map action (the swipe, per direction);
  - the mouse is a finger, and Alt + drag is two (pinch and twist around the center; with Shift, they move together);
  - a trackpad pinch arrives as `pinched`;
  - `show_fingers` draws the fingers;
  - it ignores the mouse Godot emulates from a finger;
  - it forgets the fingers when it hides, leaves the tree, is paused, is disabled or loses focus, or on a canceled touch.

  Editor warnings: `mouse_filter` on `Ignore` and an action that does not exist.
- Example `examples/minimal` (2D): a card that is dragged, thrown, pinched, twisted, marked and changes color.
- The kit's own tests and `gesturekit_lab/`, with strict GDScript warnings and a check in the real editor (`-- --gesturekit-editor-check`).
- Fable's audit applied in full.
