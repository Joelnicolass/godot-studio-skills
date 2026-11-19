# Touch controls

For a phone or a tablet, Godot already has the stick and the buttons: no need to write them or an addon. Both press the same InputMap actions as the keyboard, so the game only reads actions (§4 of the skill).

| You want | Godot node | How |
|---|---|---|
| A stick that appears where the finger lands | `VirtualJoystick` (Control) | `joystick_mode = JOYSTICK_DYNAMIC`; the node's rect is the area that grabs it (anchor it to the left half) |
| A fixed stick, or one that follows the finger | `VirtualJoystick` | `JOYSTICK_FIXED` / `JOYSTICK_FOLLOWING`; `initial_offset_ratio` for where it starts |
| Its actions | `VirtualJoystick` | `action_left`, `action_right`, `action_up`, `action_down`: it presses them with analog strength (`Input.get_vector` gives a smooth vector) |
| Dead zone and limit | `VirtualJoystick` | `deadzone_ratio`, `clampzone_ratio`, `joystick_size`, `tip_size` |
| Shown only while touched | `VirtualJoystick` | `visibility_mode = VISIBILITY_WHEN_TOUCHED` |
| Its look (pixel art) | `VirtualJoystick` | In the theme, the StyleBoxes `normal_joystick`, `normal_tip`, `pressed_joystick`, `pressed_tip` (a `StyleBoxTexture` with your art) |
| One button per action | `TouchScreenButton` (Node2D) | `action`, `texture_normal`, `texture_pressed`, `shape` for the area that touches it |
| Buttons only on touch screens | `TouchScreenButton` | `visibility_mode = VISIBILITY_TOUCHSCREEN_ONLY` |

Tested in Godot 4.7.2: the stick in dynamic mode, dragged 30 px to the right, gives 0.6 on its action; diagonally, 0.89 and 0.45; on release, it lets them go.

```
TouchControls (CanvasLayer)
├── Stick (VirtualJoystick)            # anchored to the left half; JOYSTICK_DYNAMIC; move_* actions
├── Fire (TouchScreenButton)           # action fire; bottom right
├── Jump (TouchScreenButton)           # action jump
└── Look (Control, look_area.gd)       # 3D only: the right half, to look by dragging
```

## What Godot does not have

**Showing it only on phones.** Desktop browsers often say they have a touch screen, so `DisplayServer.is_touchscreen_available()` (and `VISIBILITY_TOUCHSCREEN_ONLY`) show the controls on a laptop. Filter by platform, and also show them on the first real touch:

```gdscript
func _ready() -> void:
	visible = OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("android") or OS.has_feature("ios")

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not visible:
		visible = true
```

The same for any other choice that depends on "is it touch" (switching player automatically, aim assists).

**Looking by dragging (3D).** A `Control` on the right half that turns a finger's drag into a camera turn. Two cares that came from a game in a phone's browser:
- measure each finger's move from where you saw it last, never with the event's `relative`: with two fingers, the browser gets it wrong and the camera jumps;
- an event far from where its finger was is not that finger (the browser can swap indices): give it to the nearest finger, or to none.

```gdscript
# look_area.gd: a finger pressed in this area moves the camera (looked)
extends Control

signal looked(delta: Vector2)

@export var look_scale := 1.0
## An event farther than this from where its finger was is not that finger.
@export var jump_px := 40.0

var _last: Dictionary[int, Vector2] = {}


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and get_global_rect().has_point(touch.position):
			_last[touch.index] = touch.position
		elif not touch.pressed:
			var finger := _finger_of(touch.index, touch.position)
			_last.erase(finger if finger != -1 else touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		var finger := _finger_of(drag.index, drag.position)
		if finger != -1:
			looked.emit((drag.position - _last[finger]) * look_scale)
			_last[finger] = drag.position


func _finger_of(index: int, at: Vector2) -> int:
	if _last.has(index) and at.distance_to(_last[index]) <= jump_px:
		return index
	var best := -1
	var best_px := jump_px
	for finger: int in _last:
		var px := at.distance_to(_last[finger])
		if px <= best_px:
			best = finger
			best_px = px
	return best
```

Tested with simulated touches: a false `relative` does not count, an event with the other finger's index but far away is ignored, a swapped index near the looking finger keeps looking, and after the release nothing moves. Connect `looked` to what turns the camera (or, in a network game, to your input's look value).

**A one-press action the game reads as an event.** `Input.action_press()` does not generate events: what is read in `_unhandled_input` (switching weapon, pause) never hears it. Send the press and release pair as an event:

```gdscript
func tap(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
```

## Testing it without a phone

Touches are simulated with `get_viewport().push_input(event)` (`InputEventScreenTouch`, `InputEventScreenDrag` with their `index`), reading `Input.get_action_strength()`. In the editor, **Project Settings › Input Devices › Pointing › Emulate Touch From Mouse** lets you try one finger with the mouse. Two fingers and the browser, on the phone.

## Antipatterns

- Writing your own stick: `VirtualJoystick` already appears where the finger lands, has a dead zone and presses the actions with strength.
- The game reading touches: the controls press actions and the game reads actions, whether the input comes from the keyboard, a gamepad or the screen.
- `DisplayServer.is_touchscreen_available()` as "it is a phone": on the desktop web it lies.
- A `InputEventScreenDrag`'s `relative` to look, with two fingers in the browser.
