---
name: godot-gesture-kit
description: >-
  Touch gestures Godot 4 does not have, with the GestureKit addon: tapping with
  one, two or three fingers, double tap (and a confirmed tap that was not a
  double), long press with a ring that fills up, swipe in 4, 8 or any
  direction, dragging with any number of fingers and the velocity on release
  to throw something, pinching to zoom and twisting with two fingers, on
  Android, iOS, the web and desktop touch screens. A GestureArea (Control)
  that reports with signals and can press Input Map actions without code, a
  plain-data GestureReader that tests with exact times, and the mouse as a
  finger (Alt + drag is two) to test without a phone. Use when the user wants
  swipe, swiping, sliding, gestures, pinch to zoom, pinch, rotate with two
  fingers, double tap, tap and hold, long press, two-finger tap, flicking or
  throwing with a finger, gesture touch controls or /add-gestures. Not a stick
  or touch buttons (Godot has VirtualJoystick and TouchScreenButton), nor the
  camera, nor what each gesture does in the game.
---

# Godot — touch gestures (GestureKit)

Addon `addons/gesture_kit/` in the **game's** project. Reference: `addons/gesture_kit/README.md`.

If the addon is missing:

```bash
./install.sh --addon /path/to/godot-project gesture_kit
```

Enable the **GestureKit** plugin (type `GestureArea` in Create Node). Scoped request: `/add-gestures`. Stick, buttons and looking by dragging, with Godot's nodes: [touch.md](../godot-composition-first/touch.md). Composition: [godot-composition-first](../godot-composition-first/SKILL.md).

## Rules

- **Only what Godot does not have.** For a stick or buttons, `VirtualJoystick` and `TouchScreenButton`, without the kit. GestureKit is for taps with several fingers, double tap, long press, swipe, drag with the velocity, pinch and twist.
- **One area per zone.** A `GestureArea` (Control) where the gestures count, in **Full Rect** for the whole screen. A `Control` on top (HUD, stick) keeps its own fingers. A finger that landed on the area stays the area's until it lifts.
- **Signals or actions.** The rules connect `tapped`, `swiped`, `dragged`, `pinched`, etc. A gesture that stands for pressing a key once goes in the inspector (`swipe_up_action = jump`): the action is pressed and released in one go, so `is_action_just_pressed` and `_unhandled_input` see it, never `is_action_pressed` or `get_axis`.
- **The data each signal gives.** `fingers` is the most fingers down at once in the gesture. Positions are in the viewport's pixels. `pinched` and `twisted` give what changed since the previous signal: a zoom multiplies by `ratio` and a rotation adds `radians`, around `center`.
- **A swipe is also a drag.** `drag_ended` arrives and then `swiped`. If both mean something, decide with the `at` of `drag_started`.
- **A tap and a double tap that do different things:** `tap_confirmed` instead of `tapped`.
- **Hold to charge, let go to fire:** `long_pressed` and `long_press_ended`. An aiming line: from `drag_started(at)` to `area.reader.center()`.
- **Thresholds on a screen with no *Stretch Mode*:** `units = DENSITY_PIXELS` measures them in dp; otherwise 12 screen pixels are very little on a phone.
- **Testing without a phone.** The mouse is a finger; Alt + drag puts down two, mirrored around the area's center (pinch and twist), and Alt + Shift moves them together. `show_fingers` draws the fingers, on the phone too.
- **`mouse_filter`:** `Stop` (Godot's default) keeps the fingers for the area only, and the mouse wheel too; `Pass` also gives them to `_unhandled_input` (a 3D world that picks with clicks, a zoom with the wheel).
- **No kit depends on another.** The area does not move the camera or know about the game: the game connects its signals to whatever fits. A camera that already reads the fingers on its own gets no area with `Stop` on top of it.

## Tree

```
Level
├── World / Camera2D
└── Ui (CanvasLayer)
    ├── Gestures (GestureArea)        # Full Rect; thresholds and actions in the inspector
    ├── Stick (VirtualJoystick)       # on top: keeps its own fingers
    └── Pause (Button)                # on top: keeps its own fingers
```

`level.gd` connects `Gestures.dragged`, `.pinched` and `.twisted` to the camera, and `.double_tapped` to centering it. Start from `addons/gesture_kit/examples/minimal/minimal.tscn`.

## What goes where

| Kit | Game |
|---|---|
| Which gesture the fingers made, where and with how many | What each gesture does |
| The thresholds in the inspector | Values that feel right in the game |
| `dragged`, `pinched`, `twisted` around `center` | The camera or the object that moves, its limits |
| `drag_ended(velocity)` | The throw, the friction |
| `hold_progress()` | The ring or the bar that is drawn |
| Pressing an action | What the action does |

## Done when

- The `GestureArea` shows no warnings and covers the zone where the gestures count.
- With the mouse (click, Alt + drag) each gesture does what it should, and a HUD button keeps working.
- On a phone (or with `show_fingers`), real fingers do the same and nothing arrives twice.
- `godot --headless --path gesturekit_lab --script res://addons/gesture_kit/tests/gesture_test_runner.gd` gives `GESTUREKIT TESTS PASS` (in the kit's repo).

## Anti-patterns

- Reading `InputEventScreenTouch` and `InputEventScreenDrag` by hand for a swipe or a pinch: that is the kit.
- The `relative` of an `InputEventScreenDrag` with two fingers: the kit measures from each finger's position.
- A `Timer` to tell a tap from a double tap: `tap_confirmed`.
- Counting the emulated mouse as a second finger: the area already ignores it.
- An area with `Stop` on top of HUD buttons: the buttons go on top of the area.
- A stick or touch buttons written by hand: `VirtualJoystick` and `TouchScreenButton`.
- An inspector action to move while something lasts (`get_axis`): it is pressed and released in one go; connect the signal.
- Feeding `area.reader` from the game: the area does not notice. For another source of fingers, a `GestureReader.new()` of your own.
- Moving the camera or game rules inside the kit: the kit says which gesture it was, the game decides.
