extends "res://addons/gesture_kit/tests/gesture_test.gd"

## GestureArea through Godot's own input (Input.parse_input_event, with the mouse Godot emulates from a
## finger arriving before the finger): taps and their actions, positions in the viewport's pixels, a
## HUD button over the area, the mouse as one finger or two, the clock, no finger left down, a trackpad
## pinch, the inspector and its warnings.

const SIGNALS: Array[StringName] = [
	&"tapped",
	&"double_tapped",
	&"tap_confirmed",
	&"long_pressed",
	&"long_press_ended",
	&"swiped",
	&"drag_started",
	&"dragged",
	&"drag_ended",
	&"pinched",
	&"twisted",
]

var area: GestureArea
var layer: CanvasLayer
var heard: Array[Array] = []
var actions: Array[String] = []


class ActionEar:
	extends Node
	var heard: Array[String]

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventAction:
			var action := event as InputEventAction
			heard.append("%s %s" % [action.action, "down" if action.pressed else "up"])


class Poller:
	extends Node
	var action := &""
	var frames := 0
	var physics := 0

	func _process(_delta: float) -> void:
		if Input.is_action_just_pressed(action):
			frames += 1

	func _physics_process(_delta: float) -> void:
		if Input.is_action_just_pressed(action):
			physics += 1


class TouchEar:
	extends Node
	var touches := 0

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			touches += 1


func _scene() -> GestureArea:
	tree.root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	tree.root.size = Vector2i(1280, 720)
	Input.use_accumulated_input = false
	layer = CanvasLayer.new()
	tree.root.add_child(layer)
	area = GestureArea.new()
	area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(area)
	heard = []
	for signal_name in SIGNALS:
		area.connect(signal_name, _hear.bind(signal_name))
	actions = []
	var ear := ActionEar.new()
	ear.heard = actions
	layer.add_child(ear)
	return area


func _done() -> void:
	Input.use_accumulated_input = true
	Input.emulate_touch_from_mouse = false
	tree.paused = false
	tree.root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	layer.queue_free()
	await tree.process_frame


func _hear(first: Variant, second: Variant, signal_name: StringName) -> void:
	heard.append([signal_name, first, second])


func _names() -> Array[StringName]:
	var names: Array[StringName] = []
	for entry in heard:
		names.append(entry[0])
	return names


func _of(signal_name: StringName) -> Array[Array]:
	var found: Array[Array] = []
	for entry in heard:
		if entry[0] == signal_name:
			found.append(entry)
	return found


func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _finger(index: int, at: Vector2, pressed: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.position = at
	touch.pressed = pressed
	_send(touch)


func _slide(index: int, from: Vector2, to: Vector2) -> void:
	var drag := InputEventScreenDrag.new()
	drag.index = index
	drag.position = to
	drag.relative = to - from
	_send(drag)


func _tap(at: Vector2) -> void:
	_finger(0, at, true)
	_finger(0, at, false)


func _click(at: Vector2, pressed: bool, alt := false, shift := false) -> void:
	var button := InputEventMouseButton.new()
	button.device = 0
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = pressed
	button.position = at
	button.global_position = at
	button.alt_pressed = alt
	button.shift_pressed = shift
	_send(button)


func _mouse_to(from: Vector2, to: Vector2, alt := false, shift := false) -> void:
	var motion := InputEventMouseMotion.new()
	motion.device = 0
	motion.position = to
	motion.global_position = to
	motion.relative = to - from
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.alt_pressed = alt
	motion.shift_pressed = shift
	_send(motion)


func _action(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)


func _frames(count: int) -> void:
	for i in count:
		await tree.process_frame


func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await tree.process_frame


func test_a_tap_is_one_tap_and_presses_its_action() -> void:
	_scene()
	for action in [&"gk_tap", &"gk_double", &"gk_left", &"gk_up"]:
		_action(action)
	area.tap_action = &"gk_tap"
	area.double_tap_action = &"gk_double"
	area.swipe_left_action = &"gk_left"
	area.swipe_up_action = &"gk_up"
	await tree.process_frame
	_tap(Vector2(300, 200))
	check(heard == [[&"tapped", Vector2(300, 200), 1]], "one tap, not two with the emulated mouse: %s" % [heard])
	check(actions == ["gk_tap down", "gk_tap up"], "and its action, pressed and released: %s" % [actions])
	await _wait(0.06)
	_tap(Vector2(305, 200))
	check(_names() == [&"tapped", &"tapped", &"double_tapped"], "a double tap: %s" % [_names()])
	check(actions.slice(2) == ["gk_tap down", "gk_tap up", "gk_double down", "gk_double up"], "%s" % [actions])
	await _wait(0.35)
	actions.clear()
	_finger(0, Vector2(600, 400), true)
	_slide(0, Vector2(600, 400), Vector2(500, 380))
	_slide(0, Vector2(500, 380), Vector2(450, 370))
	_finger(0, Vector2(450, 370), false)
	check(heard.back() == [&"swiped", Vector2.LEFT, 1], "a swipe left: %s" % [heard.back()])
	check(actions == ["gk_left down", "gk_left up"], "presses the left action: %s" % [actions])
	actions.clear()
	area.swipe_directions = GestureReader.Directions.EIGHT
	_finger(0, Vector2(600, 400), true)
	_slide(0, Vector2(600, 400), Vector2(640, 330))
	_finger(0, Vector2(670, 310), false)
	check(heard.back()[1].is_equal_approx(Vector2(1, -1).normalized()), "eight: up right %s" % [heard.back()])
	check(actions == ["gk_up down", "gk_up up"], "the action of the nearest of four: %s" % [actions])
	actions.clear()
	area.swipe_right_action = &"gk_left"
	_finger(0, Vector2(600, 400), true)
	_finger(0, Vector2(680, 320), false)
	check(actions == ["gk_left down", "gk_left up", "gk_up down", "gk_up up"], "a diagonal: both: %s" % [actions])
	await _wait(0.35)
	var poller := Poller.new()
	poller.action = &"gk_tap"
	layer.add_child(poller)
	await tree.process_frame
	_tap(Vector2(300, 200))
	await _wait(0.1)
	check(poller.frames == 1 and poller.physics == 1, "is_action_just_pressed sees it once: %s" % [poller])
	check(not Input.is_action_pressed(&"gk_tap"), "and it is never held")
	layer.remove_child(poller)
	poller.free()
	for action in [&"gk_tap", &"gk_double", &"gk_left", &"gk_up"]:
		InputMap.erase_action(action)
	await _done()


func test_positions_are_the_viewports() -> void:
	_scene()
	layer.offset = Vector2(50, 20)
	layer.scale = Vector2(2, 2)
	area.set_anchors_preset(Control.PRESET_TOP_LEFT)
	area.position = Vector2(100, 100)
	area.size = Vector2(300, 200)
	await tree.process_frame
	_tap(Vector2(400, 300))
	check(heard == [[&"tapped", Vector2(400, 300), 1]], "a tap inside, where it was on screen: %s" % [heard])
	_tap(Vector2(240, 300))
	_tap(Vector2(900, 300))
	check(heard.size() == 1, "taps outside the area (left of 250, right of 850) are not its")
	await _wait(0.35)
	heard.clear()
	_finger(0, Vector2(400, 300), true)
	_slide(0, Vector2(400, 300), Vector2(430, 300))
	_slide(0, Vector2(430, 300), Vector2(900, 700))
	_finger(0, Vector2(900, 700), false)
	var total := Vector2.ZERO
	for entry in _of(&"dragged"):
		total += entry[1]
	check(_of(&"drag_started")[0][1] == Vector2(400, 300), "the drag starts where it landed: %s" % [heard[0]])
	check(total == Vector2(500, 400), "in screen pixels, also out of the area: %s" % total)
	check(_of(&"drag_ended").size() == 1, "it lifts outside, and the drag ends: %s" % [_names()])
	await _done()


func test_a_hud_button_keeps_its_fingers() -> void:
	_scene()
	var button := Button.new()
	button.position = Vector2(0, 0)
	button.size = Vector2(200, 100)
	layer.add_child(button)
	var presses: Array[bool] = []
	button.pressed.connect(func() -> void: presses.append(true))
	await tree.process_frame
	_tap(Vector2(100, 50))
	check(presses.size() == 1 and heard.is_empty(), "the button took the tap, the area heard nothing")
	_finger(1, Vector2(600, 400), true)
	_slide(1, Vector2(600, 400), Vector2(100, 50))
	_finger(1, Vector2(100, 50), false)
	var names := _names().slice(0, 3)
	check(names == [&"drag_started", &"dragged", &"drag_ended"], "a finger that landed on the area stays its")
	check(presses.size() == 1, "and does not press the button")
	await _done()


func test_two_fingers_pinch_and_twist_on_screen() -> void:
	_scene()
	await tree.process_frame
	_finger(0, Vector2(400, 300), true)
	_finger(1, Vector2(600, 300), true)
	_slide(1, Vector2(600, 300), Vector2(640, 300))
	await _frames(2)
	_slide(1, Vector2(640, 300), Vector2(720, 300))
	await _frames(2)
	var pinch := _of(&"pinched")
	check(pinch.size() == 1 and is_equal_approx(pinch[0][1], 320.0 / 240.0), "spread: %s" % [pinch])
	check(pinch[0][2] == Vector2(560, 300), "around the two fingers: %s" % [pinch])
	_slide(1, Vector2(720, 300), Vector2(400, 620))
	await _frames(2)
	_slide(1, Vector2(400, 620), Vector2(80, 300))
	await _frames(2)
	var twist := _of(&"twisted")
	check(twist.size() == 1 and is_equal_approx(twist[0][1], PI / 2.0), "a quarter turn clockwise: %s" % [twist])
	_finger(0, Vector2(400, 300), false)
	_finger(1, Vector2(80, 300), false)
	check(_of(&"tapped").is_empty(), "no tap")
	await _done()


func test_the_mouse_is_one_finger_or_two() -> void:
	_scene()
	await tree.process_frame
	_click(Vector2(300, 200), true)
	_click(Vector2(300, 200), false)
	check(heard == [[&"tapped", Vector2(300, 200), 1]], "a click is a tap: %s" % [heard])
	await _wait(0.35)
	heard.clear()
	_click(Vector2(840, 360), true, true)
	check(area.reader.fingers_down() == 2, "Alt: two fingers")
	var positions := area.reader.finger_positions()
	check(positions[GestureArea.MOUSE_TWIN] == Vector2(440, 360), "mirrored around the center: %s" % [positions])
	_mouse_to(Vector2(840, 360), Vector2(900, 360), true)
	_mouse_to(Vector2(900, 360), Vector2(960, 360), true)
	var pinch := _of(&"pinched")
	check(pinch.size() == 1 and is_equal_approx(pinch[0][1], 640.0 / 520.0), "the mouse pinches: %s" % [pinch])
	check(pinch[0][2] == Vector2(640, 360), "around the area's center: %s" % [pinch])
	_mouse_to(Vector2(960, 360), Vector2(640, 680), true)
	_mouse_to(Vector2(640, 680), Vector2(320, 360), true)
	check(_of(&"twisted").size() == 1, "and twists: %s" % [_of(&"twisted")])
	_click(Vector2(320, 360), false, true)
	check(area.reader.fingers_down() == 0, "both lift")
	heard.clear()
	_click(Vector2(700, 300), true, true)
	_mouse_to(Vector2(700, 300), Vector2(700, 340), true, true)
	_mouse_to(Vector2(700, 340), Vector2(700, 380), true, true)
	check(_of(&"pinched").is_empty() and _of(&"twisted").is_empty(), "Alt + Shift: the two move together")
	var total := Vector2.ZERO
	for entry in _of(&"dragged"):
		total += entry[1]
	check(total == Vector2(0, 80) and _of(&"dragged").back()[2] == 2, "two fingers drag 80 px: %s" % [heard])
	_click(Vector2(700, 380), false, true, true)
	await _wait(0.35)
	heard.clear()
	Input.emulate_touch_from_mouse = true
	_click(Vector2(300, 200), true)
	_click(Vector2(300, 200), false)
	check(_of(&"tapped").size() == 1, "with Emulate Touch From Mouse, Godot's touch is the finger, once")
	Input.emulate_touch_from_mouse = false
	await _wait(0.35)
	heard.clear()
	area.use_mouse = false
	_click(Vector2(300, 200), true)
	_click(Vector2(300, 200), false)
	check(heard.is_empty(), "use_mouse off: a click is nothing")
	area.use_mouse = true
	_click(Vector2(300, 200), true)
	area.use_mouse = false
	check(area.reader.fingers_down() == 0, "turning it off lifts the mouse")
	await _done()


func test_the_clock() -> void:
	_scene()
	area.long_press_s = 0.15
	area.double_tap_s = 0.1
	await tree.process_frame
	_finger(0, Vector2(300, 300), true)
	await _wait(0.07)
	var progress := area.reader.hold_progress()
	check(progress > 0.2 and progress < 1.0, "the hold fills up: %s" % progress)
	await _wait(0.15)
	check(_names() == [&"long_pressed"], "a long press on time, with no other event: %s" % [_names()])
	_finger(0, Vector2(300, 300), false)
	_tap(Vector2(500, 300))
	await _wait(0.2)
	var expected: Array[StringName] = [&"long_pressed", &"long_press_ended", &"tapped", &"tap_confirmed"]
	check(_names() == expected, "a tap confirmed on time: %s" % [_names()])
	await tree.process_frame
	check(not area.is_processing(), "nothing waits: the area stops processing")
	await _done()


func test_no_finger_stays_down() -> void:
	_scene()
	await tree.process_frame
	_finger(0, Vector2(300, 300), true)
	_slide(0, Vector2(300, 300), Vector2(360, 300))
	area.hide()
	check(heard.back() == [&"drag_ended", Vector2.ZERO, 1], "hiding ends the drag: %s" % [heard.back()])
	var count := heard.size()
	_slide(0, Vector2(360, 300), Vector2(400, 300))
	_finger(0, Vector2(400, 300), false)
	check(heard.size() == count and area.reader.fingers_down() == 0, "the hidden finger does nothing")
	area.show()
	_tap(Vector2(300, 300))
	check(heard.back()[0] == &"tapped", "shown again, a tap works")
	await _wait(0.35)
	heard.clear()
	_finger(0, Vector2(300, 300), true)
	_slide(0, Vector2(300, 300), Vector2(360, 300))
	tree.root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(heard.back() == [&"drag_ended", Vector2.ZERO, 1], "losing the focus ends it too: %s" % [heard.back()])
	_finger(0, Vector2(360, 300), false)
	heard.clear()
	_finger(0, Vector2(300, 300), true)
	var canceled := InputEventScreenTouch.new()
	canceled.position = Vector2(300, 300)
	canceled.canceled = true
	_send(canceled)
	check(heard.is_empty() and area.reader.fingers_down() == 0, "a touch the system canceled is no tap")
	await _done()


func test_a_trackpad_pinch() -> void:
	_scene()
	await tree.process_frame
	var magnify := InputEventMagnifyGesture.new()
	magnify.factor = 1.25
	magnify.position = Vector2(300, 200)
	tree.root.push_input(magnify)
	check(heard == [[&"pinched", 1.25, Vector2(300, 200)]], "a trackpad pinch is a pinch: %s" % [heard])
	_finger(0, Vector2(500, 500), true)
	tree.root.push_input(magnify)
	check(heard.size() == 1, "not while a finger is down (Android sends both)")
	_finger(0, Vector2(500, 500), false)
	await _done()


func test_the_inspector() -> void:
	_scene()
	area.slop_px = 20.0
	area.long_press_s = 0.8
	area.double_tap_s = 0.2
	area.double_tap_px = 70.0
	area.swipe_min_px = 90.0
	area.swipe_max_s = 0.4
	area.swipe_directions = GestureReader.Directions.ANY
	area.twist_start_deg = 15.0
	var reader := area.reader
	check(reader.slop_px == 20.0 and reader.long_press_s == 0.8 and reader.double_tap_s == 0.2, "taps")
	check(reader.double_tap_px == 70.0 and reader.swipe_min_px == 90.0 and reader.swipe_max_s == 0.4, "swipe")
	check(reader.swipe_directions == GestureReader.Directions.ANY and reader.twist_start_deg == 15.0, "two fingers")
	check(area._get_configuration_warnings().is_empty(), "no warnings: %s" % [area._get_configuration_warnings()])
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.swipe_down_action = &"gk_nowhere"
	var warnings := area._get_configuration_warnings()
	check(warnings.size() == 2, "Ignore and an action that does not exist: %s" % [warnings])
	area.swipe_down_action = &"ui_down"
	area.mouse_filter = Control.MOUSE_FILTER_PASS
	check(area._get_configuration_warnings().is_empty(), "a real action, and Pass")
	await _done()


func test_the_twin_of_an_area_that_is_not_the_screen() -> void:
	_scene()
	area.set_anchors_preset(Control.PRESET_TOP_LEFT)
	area.position = Vector2(100, 100)
	area.size = Vector2(400, 300)
	await tree.process_frame
	_click(Vector2(350, 250), true, true)
	var positions := area.reader.finger_positions()
	check(positions[GestureArea.MOUSE_TWIN] == Vector2(250, 250), "mirrored around its own center: %s" % [positions])
	_click(Vector2(350, 250), false, true)
	await _done()


func test_pausing_or_disabling_forgets_the_fingers() -> void:
	_scene()
	await tree.process_frame
	_finger(0, Vector2(300, 300), true)
	await _wait(0.1)
	tree.paused = true
	_finger(0, Vector2(300, 300), false)
	tree.paused = false
	await _wait(0.6)
	check(heard.is_empty() and area.reader.fingers_down() == 0, "no long press for a finger lifted while paused")
	_finger(0, Vector2(300, 300), true)
	_slide(0, Vector2(300, 300), Vector2(380, 300))
	area.process_mode = Node.PROCESS_MODE_DISABLED
	check(heard.back() == [&"drag_ended", Vector2.ZERO, 1], "disabling ends the drag: %s" % [heard.back()])
	_finger(0, Vector2(380, 300), false)
	area.process_mode = Node.PROCESS_MODE_INHERIT
	check(not area.reader.is_dragging() and area.reader.fingers_down() == 0, "nothing is left down")
	heard.clear()
	_finger(0, Vector2(300, 300), true)
	_slide(0, Vector2(300, 300), Vector2(380, 300))
	layer.remove_child(area)
	check(heard.back() == [&"drag_ended", Vector2.ZERO, 1], "leaving the tree ends it too: %s" % [heard.back()])
	layer.add_child(area)
	_finger(0, Vector2(380, 300), false)
	check(area.reader.fingers_down() == 0, "and the old finger does nothing")
	await _done()


func test_a_canceled_touch_forgets_every_finger() -> void:
	_scene()
	await tree.process_frame
	_finger(0, Vector2(300, 300), true)
	_finger(1, Vector2(500, 300), true)
	var canceled := InputEventScreenTouch.new()
	canceled.index = 1
	canceled.position = Vector2(500, 300)
	canceled.canceled = true
	_send(canceled)
	_slide(0, Vector2(300, 300), Vector2(400, 300))
	_finger(0, Vector2(400, 300), false)
	check(heard.is_empty() and area.reader.fingers_down() == 0, "the system cancels them all: %s" % [heard])
	await _done()


func test_pass_lets_the_world_hear_the_fingers() -> void:
	_scene()
	var world := TouchEar.new()
	tree.root.add_child(world)
	await tree.process_frame
	_tap(Vector2(300, 300))
	check(world.touches == 0 and heard.size() == 1, "Stop: the fingers are the area's")
	area.mouse_filter = Control.MOUSE_FILTER_PASS
	await _wait(0.06)
	_tap(Vector2(600, 300))
	check(world.touches == 2 and _of(&"tapped").size() == 2, "Pass: the world gets them too: %d" % world.touches)
	world.queue_free()
	await _done()


func test_stretched_and_inside_a_subviewport() -> void:
	_scene()
	tree.root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	tree.root.content_scale_size = Vector2i(640, 360)
	await _frames(2)
	_tap(Vector2(600, 400))
	check(heard == [[&"tapped", Vector2(300, 200), 1]], "canvas_items: positions of the design size: %s" % [heard])
	tree.root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	area.hide()
	var container := SubViewportContainer.new()
	container.position = Vector2(100, 100)
	container.size = Vector2(400, 300)
	layer.add_child(container)
	var sub := SubViewport.new()
	sub.size = Vector2i(400, 300)
	container.add_child(sub)
	var inner := GestureArea.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sub.add_child(inner)
	var inside: Array[Vector2] = []
	inner.tapped.connect(func(at: Vector2, _fingers: int) -> void: inside.append(at))
	await _frames(2)
	_tap(Vector2(150, 150))
	check(inside == [Vector2(50, 50)], "in a SubViewport: its own pixels: %s" % [inside])
	await _done()


func test_show_fingers_and_long_press_ended() -> void:
	_scene()
	area.show_fingers = true
	area.long_press_s = 0.1
	await tree.process_frame
	check(area.is_processing(), "drawing the fingers, it processes")
	_finger(0, Vector2(300, 300), true)
	_finger(1, Vector2(400, 300), true)
	await _wait(0.2)
	_finger(0, Vector2(300, 300), false)
	_finger(1, Vector2(400, 300), false)
	await _frames(3)
	check(_names() == [&"long_pressed", &"long_press_ended"], "a long press and its end: %s" % [_names()])
	check(heard[1][2] == 2, "with two fingers")
	await _done()


func test_density_pixels() -> void:
	_scene()
	await tree.process_frame
	check(area.reader.slop_px == 12.0, "viewport pixels: as written")
	area.units = GestureArea.Units.DENSITY_PIXELS
	var per_dp := DisplayServer.screen_get_dpi() / 160.0 / tree.root.get_final_transform().get_scale().x
	check(is_equal_approx(area.reader.slop_px, 12.0 * per_dp), "dp: %s for %s per dp" % [area.reader.slop_px, per_dp])
	check(is_equal_approx(area.reader.swipe_min_px, 60.0 * per_dp), "the swipe too")
	check(is_equal_approx(area.reader.double_tap_px, 50.0 * per_dp), "and the double tap")
	area.slop_px = 20.0
	check(is_equal_approx(area.reader.slop_px, 20.0 * per_dp), "a new value, in dp")
	area.units = GestureArea.Units.VIEWPORT_PIXELS
	check(area.reader.slop_px == 20.0, "back to viewport pixels")
	await _done()
