---
description: "Touch gestures (GestureKit addon): taps with several fingers, double tap, long press, swipe, drag and throw, pinch and twist, with a GestureArea that reports with signals or presses actions, and the mouse as a finger (Alt + drag is two) to test without a phone."
---

Add **touch gestures** to the **game's Godot project** with the GestureKit addon:
- a `GestureArea` where the gestures count (Full Rect for the whole screen), with the HUD controls on top;
- each gesture connected to what it does: a signal (`swiped`, `pinched`, `dragged`, `double_tapped`, …) or an Input Map action from the inspector (`swipe_up_action`, `tap_action`, …);
- the thresholds that are needed in the inspector (`slop_px`, `long_press_s`, `swipe_min_px`, `twist_start_deg`, …).

Then the person tests with the mouse (a click is a finger, Alt + drag is two) and on the phone; the agent builds and explains.

This is **not** a stick or touch buttons: Godot's `VirtualJoystick` and `TouchScreenButton` are for that (see `godot-composition-first/touch.md`). **Not** the camera: the game connects the gestures to its camera. It does **not** decide what each gesture does.

Load: `godot-gesture-kit`, `godot-composition-first`.

If `addons/gesture_kit/` is missing:

```bash
./install.sh --addon /ABS/GODOT_ROOT gesture_kit
```

Enable **GestureKit**. If `godot-studio-workflow` is loaded: orchestrator → tree (this chat if it is 1–3 files; otherwise `studio-tech-lead`) → OK → `studio-developer`. No extra subagent.

## 1. Scope

If missing, ask in one batch:

1. Which gestures the game uses and what each one does (a swipe jumps, a pinch zooms the camera in, a long press opens a menu, two fingers undo).
2. Where they count: the whole screen, one half, or over something (a card, the map); which HUD controls sit on top.
3. Whether a tap and a double tap do different things, and whether a swipe and a drag live together (how they are told apart).
4. Whether the game already has Input Map actions that a gesture can press (`jump`, `ui_left`).
5. Whether the world must also get the touches or the mouse wheel (clicks in a 3D world, a zoom with the wheel): `mouse_filter = Pass`.
6. Whether the project uses a *Stretch Mode* (`canvas_items`) or not: without one, the thresholds go in dp (`units = DENSITY_PIXELS`).

## 2. Plan

Show the file tree before touching the game (`[+]` new, `[~]` changed, `[-]` deleted), for example:

```
[~] project.godot                        # GestureKit plugin
[~] levels/level/level.tscn       # Ui/Gestures (GestureArea, Full Rect, swipe_up_action = jump), HUD on top
[~] levels/level/level.gd         # pinched → camera zoom; dragged → moves it; double_tapped → centers it
```

Start from `addons/gesture_kit/examples/minimal/minimal.tscn` (drag, throw, pinch, twist, long press, swipe, two fingers).

## 3. Implement

Follow [godot-gesture-kit](../skills/godot-gesture-kit/SKILL.md) and `addons/gesture_kit/README.md`.

- One `GestureArea` per zone; the HUD controls lower in the tree (on top of the area).
- A gesture that is pressing a key once: the action in the inspector (`is_action_just_pressed` and `_unhandled_input` see it, `get_axis` does not). One that moves something: the signal, with `relative`, `ratio`, `radians` and `center`.
- Hold to charge and let go to fire: `long_pressed` and `long_press_ended`.
- No *Stretch Mode* in the project: `units = DENSITY_PIXELS`, so the thresholds measure the same on a phone.
- Swipe and drag together: decide in `drag_started(at)` whether the gesture started on what is dragged.
- A tap that must not fire on a double tap: `tap_confirmed`.
- Throwing: `drag_ended(velocity)`.
- Tell the person how to test it: a click is a finger, Alt + drag is two (pinch and twist), Alt + Shift + drag moves them together; `show_fingers` on the phone.

## 4. Done when

- The `GestureArea` shows no warnings and the HUD buttons keep working.
- Each gesture does what it should with the mouse and with fingers, and nothing arrives twice.
- No camera, rules or network inside `addons/gesture_kit`.
