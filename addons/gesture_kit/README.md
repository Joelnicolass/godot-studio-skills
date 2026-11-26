# <img src="icons/gesture_kit.svg" width="32" height="32" alt=""> GestureKit

Touch gestures Godot does not have: tapping with one, two or three fingers, the double tap and the long press. Also the swipe, dragging with any number of fingers (with the velocity on release), and pinching and twisting with two fingers. They work the same on Android, iOS, the web and a desktop touch screen. The mouse is a finger too, so you can test without a phone. It has two levels:

- **`GestureArea`** (Control): an area of the screen that reads the fingers landing on it and reports each gesture with a signal. The thresholds are in the inspector, and each gesture can press an Input Map action without writing code.
- **`GestureReader`** (RefCounted): the fingers read as gestures, as plain data. It reads no clock: it gets the time with each finger, so it tests with exact times. The area has its own (`area.reader`) to query; to read fingers that come from somewhere else, create a `GestureReader.new()` and feed it yourself.

GestureKit has **no** stick or buttons: Godot already has `VirtualJoystick` and `TouchScreenButton`. It has no game rules, camera, network or autoload either: it says which gesture the fingers made, and the game decides what to do with it.

## What Godot has and what the kit adds

| Gesture | Godot 4.7 | GestureKit |
|---|---|---|
| Tap | `InputEventScreenTouch` (a finger goes down and up) | `tapped`, only if it did not move or stay held, with 1, 2 or 3 fingers |
| Double tap | `double_tap` on the touch | `double_tapped` with a distance and fingers, and `tap_confirmed` for a tap that was not a double |
| Long press | Only on Android, as a right click | `long_pressed` on every platform, how far along it is from 0 to 1 (`hold_progress()`) and `long_press_ended` on release |
| Swipe | No | `swiped` with a direction (4, 8 or exact) and fingers, and one action per direction |
| Drag | `InputEventScreenDrag` per finger | `dragged` of the middle of the fingers, after a margin, where it is (`center()`) and the velocity on release |
| Pinch | Only on a Mac trackpad and on Android (with a setting) | `pinched` on every platform, around the fingers |
| Two-finger twist | No | `twisted`, after a threshold so that a pinch does not turn |

## Install

```bash
./install.sh --addon /path/to/godot-project gesture_kit
```

Enable the **GestureKit** plugin: it adds the `GestureArea` type to Create Node.

## In 3 steps

1. Add a `GestureArea` and place it where the gestures count: **Layout → Full Rect** for the whole screen. A `Control` drawn on top of it, such as a HUD button or a `VirtualJoystick`, keeps its own fingers.
2. Choose what each gesture does. Without code, set an action in the inspector (`swipe_up_action = jump`): the swipe presses and releases it in one go, so `Input.is_action_just_pressed` and `_unhandled_input` see it. With code, connect the signals in the Node tab.
3. Use them from your code:

```gdscript
@onready var gestures: GestureArea = %Gestures
@onready var camera: Camera2D = %Camera


func _ready() -> void:
	gestures.dragged.connect(_on_dragged)
	gestures.pinched.connect(_on_pinched)
	gestures.double_tapped.connect(_on_double_tapped)


func _on_dragged(relative: Vector2, _fingers: int) -> void:
	camera.position -= relative / camera.zoom


func _on_pinched(ratio: float, _center: Vector2) -> void:
	camera.zoom *= ratio


func _on_double_tapped(_at: Vector2, _fingers: int) -> void:
	camera.zoom = Vector2.ONE
```

## Testing it without a phone

- **The mouse is a finger** (`use_mouse`, on): a click is a tap, a drag is a drag and holding the button is a long press.
- **Alt + drag** puts down two fingers, one on the mouse and another mirrored around the area's center. Moving away from the center pinches and going around it twists, like the iOS simulator with Option.
- **Alt + Shift + drag** moves both fingers together: a two-finger drag or swipe.
- **A pinch on a Mac's trackpad** arrives as `pinched`.
- **`show_fingers`** draws a circle on each finger, the long-press ring and the last gesture's name. It works on the phone too.

Real fingers always count: the mouse Godot emulates from a finger is ignored, so on a phone nothing arrives twice.

## Minimal example

`examples/minimal/minimal.tscn` (F6, 2D): a card on a screen-sized `GestureArea`.
- Drag it and throw it.
- Pinch it and twist it with two fingers (with the mouse, Alt + drag).
- A double tap brings it back to the middle.
- Holding it marks it (the yellow corner), with a ring that fills up meanwhile.
- A swipe that starts off the card changes its color.
- A two-finger tap shows or hides the help.

```
Minimal          # minimal.gd: connects the area's signals
├── Background
├── %Card        # Node2D: Face, Number, Mark
├── %Area        # GestureArea: Full Rect, its default values
├── %Ring        # Control: the long-press ring, with reader.hold_progress()
└── %Status, %Help
```

## How it reads the fingers

- **A gesture** starts when a finger lands on the empty area and ends when the last one lifts. In every signal, `fingers` is the most fingers that were down at once in that gesture.
- **Tap:** every finger lifts without moving more than `slop_px`, before `long_press_s` from the last one landing. `at` is the middle of where they landed. Each tap of a double tap arrives as `tapped` too.
- **Double tap:** the second tap lands within `double_tap_s` of the first one lifting, closer than `double_tap_px` and with the same number of fingers. `tapped` arrives and then `double_tapped`. A second tap that lands sooner than 40 ms is a bounce of the screen and is ignored, as on Android.
- **`tap_confirmed`:** a tap that no other tap followed within `double_tap_s`. Use it when a tap and a double tap do different things (select and open): it arrives a little later, but never before a double tap. If the area forgets the fingers before that (it hides, for example), that tap is not confirmed.
- **Long press:** the fingers stay still for `long_press_s`. If another finger lands, the wait starts over (and the tap is timed from it). `fingers` is the most fingers of the gesture, even if one has already lifted. After it, no tap or swipe arrives; if the fingers move, they drag from where they were held. When the last one lifts, `long_press_ended(at)` arrives, also after dragging or if the area forgets the fingers: «hold to charge, let go to fire». `reader.hold_progress()` goes from 0 to 1 meanwhile.
- **Drag:** the middle of the fingers moved more than `slop_px` from where they landed. `drag_started(at)` says where they landed, and the first `dragged` includes that margin: whatever follows the fingers stays under them. There is only one drag per gesture. A finger that lands or lifts moves nothing. `reader.center()` says where the middle of the fingers is: an aiming line goes from `drag_started(at)` to there. `drag_ended(velocity)` brings the velocity of the last tenth of a second, zero if the fingers had already stopped. After a pause longer than 40 ms only what came after it counts, as on Android, and it never divides by less than a frame at 120 fps: a throw that fits in one frame does not come out at millions of pixels per second.
- **Swipe:** a quick line, at least `swipe_min_px`, that ends within `swipe_max_s` of the fingers starting to move: a thumb that waits on the screen and then slides also swipes. There is no swipe after a long press, a pinch or a twist. A swipe is also a drag: `drag_ended` arrives and then `swiped`. `direction` is a vector of length 1 set by `swipe_directions`: `FOUR` gives `Vector2.LEFT`, `RIGHT`, `UP` or `DOWN` (compare with `==`), `EIGHT` adds the diagonals and `ANY` gives the exact direction.
- **Pinch and twist:** the two fingers with the lowest index. `pinched(ratio, center)` starts when the distance between them changed by more than `slop_px`, and `twisted(radians, center)` when they turned more than `twist_start_deg`. Both signals give what changed since the previous one, so a zoom multiplies by `ratio`. The twist is positive clockwise, like `rotation` in 2D. Two fingers closer than twice `slop_px` do not turn (their angle is noise), and a distance under 1 px counts as 1.
- **The two fingers are read together.** Godot sends one event per finger. If both move together, the distance between them goes up and down with each event and it would look like a pinch. That is why the pair is read when both have moved. If only one moved, it is read on the second frame, in case the other one arrives a frame later.
- **All together:** a pinch, a twist and a drag can arrive in the same gesture, as on a map that moves, zooms in and turns with two fingers.
- **Positions:** in the viewport's pixels, like an `InputEventScreenTouch` in `_input`, even when the area is offset or scaled in its `CanvasLayer`. With *Stretch Mode* `canvas_items` they are the design resolution's; inside a `SubViewport`, its own.
- **Thresholds in pixels** (`slop_px`, `double_tap_px`, `swipe_min_px`): viewport pixels by default. With no *Stretch Mode* they are the screen's own pixels, and on a phone they are small: 12 px is less than 5 dp, and a thumb tap becomes a drag. `units = DENSITY_PIXELS` reads them as dp (160 per inch, as Android does), from the screen's DPI and the window's scale: they measure the same on every screen.
- **The UI:** a `Control` on top of the area keeps its own fingers. A finger that landed on the area stays the area's until it lifts, even if it leaves the area or passes over a button.
- **`mouse_filter`:** with `Stop` (Godot's default), the fingers are the area's only, and so are the wheel and the other mouse buttons. With `Pass` they also reach `_unhandled_input`: a 3D world that picks with clicks, or a game that zooms with the wheel. With `Ignore`, the area gets nothing and warns about it.
- **No finger stays down:** if the area hides, leaves the tree, is paused, is disabled (`process_mode`), the window loses focus or the system cancels a touch, the area forgets the fingers. A drag in progress ends with a zero `velocity` and a long press with `long_press_ended`. Whatever those fingers do afterwards does not count. A canceled touch forgets every finger: the system cancels them together (a call, a system gesture).
- **Actions:** they are pressed and released in one go, as events (`Input.parse_input_event`). `_unhandled_input` and `Input.is_action_just_pressed` see them, once. They are no good for something held: `Input.is_action_pressed` and `Input.get_axis` never see them pressed. A swipe presses the action of the nearest of the four directions; a diagonal of `EIGHT` presses both of its own.
- **The trackpad:** a pinch (`InputEventMagnifyGesture`) arrives as `pinched`, but not while a finger is down. If you turn on Android's *Enable Pan And Scale Gestures*, Godot sends both: leave it off.
- **The clock:** the area measures time with `Time` and processes only while it waits for something (a long press, a tap to confirm, the pair of fingers). The reader gets the time with each call (`now`, in seconds).

## API

### `GestureReader` (RefCounted)

| Signal | When |
|---|---|
| `tapped(at, fingers)` | A tap. `at`: the middle of where the fingers landed |
| `double_tapped(at, fingers)` | The second tap of a pair, after its `tapped` |
| `tap_confirmed(at, fingers)` | A tap that no other tap followed within `double_tap_s` |
| `long_pressed(at, fingers)` | The fingers stayed still for `long_press_s` |
| `long_press_ended(at, fingers)` | The fingers of a long press lifted (also after dragging), or `clear()` |
| `swiped(direction, fingers)` | A quick line, after `drag_ended` |
| `drag_started(at, fingers)` | The fingers went past `slop_px`. `at`: where the drag started |
| `dragged(relative, fingers)` | The middle of the fingers moved by `relative` (where it is: `center()`) |
| `drag_ended(velocity, fingers)` | The last finger lifted (or `clear()`, with zero velocity) |
| `pinched(ratio, center)` | Two fingers moved apart (above 1) or together (below 1) |
| `twisted(radians, center)` | Two fingers turned, clockwise when positive |

| Member | What it does |
|---|---|
| `slop_px` (12), `long_press_s` (0.5), `double_tap_s` (0.3), `double_tap_px` (50) | The tap thresholds. A value out of range stays at the edge (`long_press_s` never below 0.01) |
| `swipe_min_px` (60), `swipe_max_s` (0.5), `swipe_directions` (`FOUR`) | The swipe's. `Directions`: `FOUR`, `EIGHT`, `ANY` |
| `twist_start_deg` (10) | The degrees before it twists |
| `press(index, at, now)`, `move(index, at, now)`, `lift(index, at, now)` | A finger lands, moves, lifts. A finger it does not know is ignored; one that lands twice lost its `lift` and the gesture starts over |
| `update(now)` | Moves the clock forward: the long press, `tap_confirmed` and the pending pair of fingers arrive. Call it every frame while `is_waiting()` |
| `is_waiting() -> bool` | Something can arrive with time |
| `clear()` | Forgets the fingers and the tap it was waiting on. A drag in progress ends with zero velocity and a long press with `long_press_ended` |
| `fingers_down() -> int`, `finger_positions() -> Dictionary[int, Vector2]` | How many fingers are down now and where (a copy). The signals' `fingers` is something else: the most fingers of the gesture |
| `center() -> Vector2` | The middle of the fingers down; after they lift, where they were |
| `is_dragging() -> bool` | The fingers are dragging |
| `hold_progress() -> float` | From 0 to 1 while you hold, to draw a ring. 0 with no fingers, if they moved or if the long press already happened |
| `VELOCITY_WINDOW_S` (0.1), `STOPPED_GAP_S` (0.04), `MIN_SPAN_S` (1/120), `DOUBLE_TAP_MIN_S` (0.04) | The constants of the velocity and the bounce |

### `GestureArea` (Control)

- **Signals:** the reader's eleven, with the same rules and positions in the viewport's pixels.
- **Inspector:** `units` (the thresholds in viewport pixels or in dp) and the thresholds in the **Taps**, **Swipe** and **Two fingers** groups. Changing them changes the reader at once.
- **Actions:** `tap_action`, `double_tap_action`, `long_press_action`, `swipe_left_action`, `swipe_right_action`, `swipe_up_action` and `swipe_down_action`. Empty: none. They are pressed and released in one go.
- **Testing:** `use_mouse` (the mouse is a finger; with Alt, two) and `show_fingers` (draws the fingers in the game).
- **`reader`:** its `GestureReader`, read only, for `hold_progress()`, `center()`, `finger_positions()` or `is_dragging()`. It is there to query: the area does not notice fingers you pass to it yourself.
- **Editor warnings:** `mouse_filter` on `Ignore`, and an action that does not exist in the Input Map.
- **In the editor** it draws a border and its name, so you can see where it is. It reads no fingers and processes nothing.

## You want → you write

| You want | Write |
|---|---|
| Gestures on the whole screen | A `GestureArea` with **Layout → Full Rect** |
| A HUD button that keeps working | Draw it on top of the area (lower in the tree) |
| Jump with an upward swipe, without code | `swipe_up_action = jump` |
| Jump with a tap | `tap_action = jump`, or `tapped.connect(...)` |
| A tap that is not mistaken for a double tap | `tap_confirmed` instead of `tapped` |
| Two-finger zoom (2D) | `pinched`: `camera.zoom *= ratio` |
| Two-finger zoom (3D, distance) | `pinched`: `distance /= ratio` |
| The point under the fingers to stay put | `pinched(ratio, center)`: `position = center + (position - center) * ratio` |
| Turn something with two fingers | `twisted`: `rotation += radians` |
| Move something with one finger | `dragged`: `position += relative` |
| Throw what you were dragging | `drag_ended(velocity)`: keep moving it with that velocity |
| Drag only what was under the finger | In `drag_started(at)`, check whether `at` falls on it |
| A menu on a long press | `long_pressed(at)`: open it at `at` |
| A ring that fills up while holding | `area.reader.hold_progress()` in `_process` or `_draw` |
| Hold to charge, let go to fire | `long_pressed` starts charging; `long_press_ended` fires |
| An aiming line while dragging | From `drag_started(at)` to `area.reader.center()` in `dragged` |
| Undo with two fingers | `tapped`: `if fingers == 2: undo()` |
| Diagonal swipes | `swipe_directions = EIGHT` |
| A shorter or slower swipe | `swipe_min_px`, `swipe_max_s` |
| A pinch that does not turn | A higher `twist_start_deg` |
| The 3D world to get the touches too | `mouse_filter = Pass` |
| The mouse wheel to keep reaching the game | `mouse_filter = Pass` |
| Thresholds of the same size on every screen (no *Stretch Mode*) | `units = DENSITY_PIXELS` |
| To move while a swipe lasts (`get_axis`) | Actions will not do: connect `swiped` and move in your code |
| See the fingers on the phone | `show_fingers = true` |
| Try two fingers with the mouse | Alt + drag; Alt + Shift + drag to move them together |
| Read gestures without a node (tests, another input) | `GestureReader.new()`, and `press`, `move`, `lift` and `update` with your time |

## Tips

- **A swipe is also a drag.** If both mean something, decide with the `at` of `drag_started`, like the example: dragging the card moves it and a swipe off it changes the color.
- **The area does not own the camera.** For a map, connect `dragged`, `pinched` and `twisted` to your camera. If your camera already reads the fingers on its own, do not put an area with `Stop` on top of it: the area would take its fingers.
- **Several areas.** Each one reads only the fingers that land on it: one half of the screen to look and the other for swipes, or one per card.
- **Stick and buttons, from Godot.** `VirtualJoystick` and `TouchScreenButton` on top of the area keep their own fingers and the area gets the rest.
- **Viewport pixels or dp.** With *Stretch Mode* `canvas_items`, the thresholds follow the design resolution: on a phone they are close to Android's, but on a tablet they measure more millimeters. With no *Stretch Mode*, or to have them measure the same on every screen, use `units = DENSITY_PIXELS`.
- **On the web,** *Emulate Mouse From Touch* can stay on: the area ignores the mouse Godot emulates and reads the finger.

## Tests

```bash
godot --headless --path gesturekit_lab --script res://addons/gesture_kit/tests/gesture_test_runner.gd
```

It prints `GESTUREKIT TESTS PASS (n)`. They cover:

- **The reader, with exact times:**
  - taps with 1, 2 and 3 fingers (also a late second finger), and the margin;
  - the double tap (in time, late, far, with other fingers, with the second one still down and a bounce) and `tap_confirmed`;
  - the long press (with another finger landing, without `update`, dragging afterwards, `long_press_ended` and `fingers`);
  - the swipe in 4, 8 and any direction, too slow or too short, with two fingers, after waiting on the screen, and that a pinch is no swipe;
  - the drag with fingers that land and lift, `center()` and the velocity (steady, after a pause and within one frame);
  - pinching and twisting, the third finger, the two fingers read together (also a frame apart) and fingers very close together;
  - `clear`, a finger that lands twice, an index that comes back and thresholds out of range.
- **The area, through Godot's own input:**
  - a tap counts once with the emulated mouse, and its actions (a diagonal presses both; `is_action_just_pressed` sees it once);
  - the positions with an offset and scaled `CanvasLayer`, with `canvas_items` and inside a `SubViewport`;
  - a button on top, and `Pass` letting the fingers reach the world;
  - two real fingers;
  - the mouse as one or two fingers (also with an offset area), with *Emulate Touch From Mouse* and with `use_mouse` off;
  - the clock, and that no finger stays down (hiding, leaving the tree, pausing, disabling, losing focus, a canceled touch with two fingers);
  - `show_fingers`, `long_press_ended`, the thresholds in dp, the trackpad, the inspector and its warnings.
- **The example,** played with fingers at a touch screen's pace.
- **Independence:** the addon names no other kit.

In the real editor, the lab has a check that opens the example and edits the area from the inspector: a threshold that reaches the reader and is undone with the shortcut, an action that does not exist (a warning) and one that does, and `mouse_filter` on `Ignore`. Then it saves a copy:

```bash
godot --headless --editor --path gesturekit_lab -- --gesturekit-editor-check
```

It prints `GESTUREKIT EDITOR CHECK PASS (n)`.
