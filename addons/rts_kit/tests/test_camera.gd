extends "res://addons/rts_kit/tests/rts_test.gd"

## RtsCamera3D (follow and free) and RtsCamera2D: placement, the ground, the limits of the look, the
## drag threshold, the wheel blockers, the edges (and the UI over them), the pan, the bounds, the
## shared yaw contract, the fingers (tap, drag, pinch and twist around them, none left down, the UI's
## own), the emulated mouse, takes_drag, the select drag and the focus glide.


func _camera_3d(mode: RtsCamera3D.Mode) -> RtsCamera3D:
	RtsKeymap.install()
	var camera := RtsCamera3D.new()
	camera.mode = mode
	root.add_child(camera)
	camera.current = true
	return camera


func _follow(camera: RtsCamera3D, at := Vector3.ZERO) -> Node3D:
	var body := Node3D.new()
	root.add_child(body)
	body.global_position = at
	camera.set_follow(body)
	return body


func test_follow_placement() -> void:
	var camera := _camera_3d(RtsCamera3D.Mode.FOLLOW)
	_follow(camera)
	camera._place()
	# h 1.5: distance max(0.6 + 2.32·1.5, 4.5) = 4.5 · (0.6 + 3.13·0.125); height (1.75·1.5 - 1.15) ·
	# (0.6 + 2.8·0.125); the eye one meter above that, behind the body (yaw 0 faces +Z).
	var distance := 4.5 * (0.6 + 3.13 * 0.125)
	var height := (1.75 * 1.5 - 1.15) * (0.6 + 2.8 * 0.125)
	check(near(camera.global_position, Vector3(0, height + 1.0, -distance), 0.0005), "the eye: %s" % camera.global_position)
	var focus := (1.75 * 1.5 - 1.15) - 0.3 * 0.5
	check(near(camera.view_pitch_deg, rad_to_deg(atan2(height - focus, distance)), 0.001), "looking down at the focus: %s°" % camera.view_pitch_deg)
	check(near(RtsSpace.yaw_of_direction(-camera.global_basis.z), 0.0, 0.001), "facing the yaw")


func test_follow_keeps_over_the_ground() -> void:
	var camera := _camera_3d(RtsCamera3D.Mode.FOLLOW)
	_follow(camera)
	camera.height_at = func(_x: float, _z: float) -> float: return 10.0
	camera._place()
	check(camera.global_position.y >= 10.0 + camera.ground_clearance - 0.0001, "never under live ground: %s" % camera.global_position.y)
	camera.height_at = func(_x: float, _z: float) -> float: return NAN
	camera._place()
	var distance := 4.5 * (0.6 + 3.13 * 0.125)
	check(near(camera.global_position.z, -distance, 0.001) and camera.global_position.y < 5.0, "unknown ground does not lift the eye")


func test_look_limits() -> void:
	var camera := _camera_3d(RtsCamera3D.Mode.FOLLOW)
	_follow(camera)
	camera.look_pitch_deg = 500.0
	camera._place()
	check(near(camera.view_pitch_deg, camera.look_down_max_deg), "at most 85° down")
	camera.look_pitch_deg = -500.0
	camera._place()
	check(near(camera.view_pitch_deg, -camera.look_up_max_deg), "at most 80° up")


func test_drag_threshold() -> void:
	var camera := _camera_3d(RtsCamera3D.Mode.FOLLOW)
	_follow(camera)
	Input.action_press(&"rts_camera_orbit")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(2, 0)
	var yaw_before := camera.yaw
	camera._on_motion(motion)
	check(not camera.is_dragging(), "2 px: not a drag")
	check(not near(camera.yaw, yaw_before), "free look turned the view")
	camera._on_motion(motion)
	check(camera.is_dragging(), "4 px: a drag (the click that ends it is no order)")
	Input.action_release(&"rts_camera_orbit")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	camera._input(press)
	check(not camera.is_dragging(), "a new press starts over")


func test_wheel_and_its_blockers() -> void:
	var camera := _camera_3d(RtsCamera3D.Mode.FREE)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = Vector2(100, 100)
	var before := camera.target_zoom
	camera._input(wheel)
	check(near(camera.target_zoom, before + camera.wheel_step), "the wheel zooms out")
	var script := GDScript.new()
	script.source_code = "extends Control\nfunc covers(_screen: Vector2) -> bool:\n\treturn true\n"
	script.reload()
	var minimap := Control.new()
	minimap.set_script(script)
	root.add_child(minimap)
	camera.wheel_blockers = [minimap]
	before = camera.target_zoom
	camera._input(wheel)
	check(near(camera.target_zoom, before), "not over a blocker that covers the pointer")


func test_follow_edges_turn_the_view() -> void:
	var camera := _camera_3d(RtsCamera3D.Mode.FOLLOW)
	_follow(camera)
	camera.debug_pointer = Vector2(10, 360)
	camera._process(1.0)
	check(near(camera.yaw, deg_to_rad(36.0), 0.001), "the left edge turns 36°/s: %s" % rad_to_deg(camera.yaw))


## A SubViewport of the test's own: its hover follows pushed events (a headless window's does not).
func _ui_view() -> SubViewport:
	var view := SubViewport.new()
	view.size = Vector2i(1280, 720)
	root.add_child(view)
	return view


## A HUD button on the left edge, y 300 to 420 (in a CanvasLayer: a 2D camera does not move it).
func _edge_button(view: SubViewport) -> Button:
	var hud := CanvasLayer.new()
	view.add_child(hud)
	var button := Button.new()
	button.position = Vector2(0, 300)
	button.size = Vector2(60, 120)
	hud.add_child(button)
	return button


## Moves the real pointer of `view` to `at` and lets its hover update.
func _hover(view: SubViewport, at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	view.push_input(motion)
	await tree.process_frame


func test_follow_edges_and_the_ui() -> void:
	RtsKeymap.install()
	var view := _ui_view()
	var area := Control.new()
	area.size = Vector2(1280, 720)
	area.visible = false
	view.add_child(area)
	_edge_button(view)
	var label := Label.new()
	label.text = "wood 30"
	label.position = Vector2(0, 500)
	label.size = Vector2(60, 100)
	view.add_child(label)
	var camera := RtsCamera3D.new()
	camera.mode = RtsCamera3D.Mode.FOLLOW
	view.add_child(camera)
	camera.current = true
	_follow(camera)
	var turns := func(at: Vector2) -> bool:
		await _hover(view, at)
		var before := camera.yaw
		camera._process(1.0)
		return not near(camera.yaw, before, 0.001)
	check(not await turns.call(Vector2(10, 360)), "a HUD button at the edge does not turn the view")
	check(await turns.call(Vector2(10, 200)), "the edge over the world turns it")
	check(await turns.call(Vector2(10, 550)), "a label that ignores the mouse is not UI")
	camera.edges_over_gui = true
	check(await turns.call(Vector2(10, 360)), "edges_over_gui: it turns over the button too")
	camera.edges_over_gui = false
	area.visible = true
	camera.edge_area = area
	check(await turns.call(Vector2(10, 200)), "edge_area: the edge turns it over the area")
	check(not await turns.call(Vector2(10, 360)), "edge_area: not over a button on top of the area")


func test_free_mode_pans_turns_and_stays_in_bounds() -> void:
	var camera := _camera_3d(RtsCamera3D.Mode.FREE)
	camera.bounds = Rect2(-10, -10, 20, 20)
	check(camera.focus(Vector3(50, 0, -50)) and near(camera.free_target, Vector3(10, 0, -10)), "focus, kept in bounds")
	camera.focus(Vector3.ZERO)
	camera._place()
	var look := -camera.global_basis.z
	var to_target := (camera.free_target - camera.global_position).normalized()
	check(near(look, to_target, 0.001), "it looks at its target")
	check(near(camera.view_pitch_deg, camera.free_pitch_deg), "from its pitch")
	Input.action_press(&"rts_camera_pan_right")
	camera._process(0.5)
	Input.action_release(&"rts_camera_pan_right")
	var moved := camera.free_target
	check(moved.dot(RtsSpace.right(camera.yaw)) > 0.5 and absf(moved.dot(RtsSpace.ahead(camera.yaw))) < 0.001, "the pan key moves it to the view's right: %s" % moved)
	Input.action_press(&"rts_camera_turn_left")
	camera._process(0.5)
	Input.action_release(&"rts_camera_turn_left")
	check(near(camera.yaw, deg_to_rad(90.0), 0.001), "the turn key turns it")
	var pointer := RtsPointer.new()
	pointer.dimension = RtsPointer.Dimension.D3
	root.add_child(pointer)
	camera._place()
	check(near(pointer.camera_yaw(), camera.yaw, 0.001), "the pointer reads the same yaw the camera keeps")
	var follow_camera := _camera_3d(RtsCamera3D.Mode.FOLLOW)
	check(not follow_camera.focus(Vector3.ONE), "follow mode ignores focus")



func _touch(camera: Node, index: int, at: Vector2, pressed: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.position = at
	touch.pressed = pressed
	camera._input(touch)


func _drag(camera: Node, index: int, from: Vector2, to: Vector2) -> void:
	var drag := InputEventScreenDrag.new()
	drag.index = index
	drag.position = to
	drag.relative = to - from
	camera._input(drag)


## The screen point `at` turned by `degrees` around `center` (clockwise on screen).
func _turned(at: Vector2, center: Vector2, degrees: float) -> Vector2:
	return center + (at - center).rotated(deg_to_rad(degrees))


func test_touch_tap_and_drag() -> void:
	var camera := _camera_3d(RtsCamera3D.Mode.FREE)
	camera._place()
	_touch(camera, 0, Vector2(400, 300), true)
	_drag(camera, 0, Vector2(400, 300), Vector2(405, 304))
	check(near(camera.free_target, Vector3.ZERO), "a finger that shakes under touch_drag_px does not move the map")
	_touch(camera, 0, Vector2(405, 304), false)
	check(not camera.is_dragging(), "and the tap stays a click")
	_touch(camera, 0, Vector2(400, 300), true)
	_drag(camera, 0, Vector2(400, 300), Vector2(500, 300))
	check(camera.is_dragging(), "a finger drag is a drag")
	var moved := camera.free_target
	check(moved.dot(RtsSpace.right(camera.yaw)) < -0.5, "the map follows the finger (the view goes left): %s" % moved)
	_touch(camera, 0, Vector2(500, 300), false)
	_touch(camera, 0, Vector2(400, 300), true)
	check(not camera.is_dragging(), "a new gesture starts over")
	_touch(camera, 1, Vector2(600, 300), true)
	check(camera.is_dragging(), "a second finger makes it a gesture, never a click")
	_touch(camera, 0, Vector2(400, 300), false)
	_touch(camera, 1, Vector2(600, 300), false)
	var follow_camera := _camera_3d(RtsCamera3D.Mode.FOLLOW)
	_follow(follow_camera)
	_touch(follow_camera, 0, Vector2(400, 300), true)
	_drag(follow_camera, 0, Vector2(400, 300), Vector2(500, 300))
	check(not near(follow_camera.yaw, 0.0), "FOLLOW: a finger looks around")
	_touch(follow_camera, 0, Vector2(500, 300), false)


func test_touch_pinch_and_twist_around_the_fingers() -> void:
	var camera := _camera_3d(RtsCamera3D.Mode.FREE)
	camera.zoom = 0.5
	camera.target_zoom = 0.5
	camera._place()
	var distance := camera.free_distance()
	var a := Vector2(500, 400)
	var b := Vector2(700, 400)
	_touch(camera, 0, a, true)
	_touch(camera, 1, b, true)
	var anchor: Vector3 = camera._ground_under((a + b) * 0.5, 0.0)
	_drag(camera, 1, b, Vector2(900, 400))
	b = Vector2(900, 400)
	var halved := near(camera.free_distance(), distance * 0.5, 0.01)
	check(halved, "the gap doubles, the distance halves: %s -> %s" % [distance, camera.free_distance()])
	camera._place()
	var middle := (a + b) * 0.5
	var shown := camera.unproject_position(anchor)
	check(shown.distance_to(middle) < 1.0, "the ground under the fingers stays under them: %s" % shown)
	var yaw := camera.yaw
	var small := _turned(b, middle, 6.0)
	_drag(camera, 1, b, small)
	b = small
	check(near(camera.yaw, yaw), "a twist under twist_start_deg does not turn the view")
	camera._place()
	var mark := camera._ground_under(middle + Vector2(150, 0), 0.0) as Vector3
	var mark_angle := (camera.unproject_position(mark) - camera.unproject_position(anchor)).angle()
	var big := _turned(b, middle, 40.0)
	_drag(camera, 1, b, big)
	b = big
	check(not near(camera.yaw, yaw), "past it, the view turns")
	camera._place()
	var mark_now := camera.unproject_position(mark) - camera.unproject_position(anchor)
	var turned := angle_difference(mark_angle, mark_now.angle())
	check(turned > 0.15, "twisting clockwise turns the map clockwise: %s rad" % turned)
	check(camera.unproject_position(anchor).distance_to((a + b) * 0.5) < 1.0, "around the fingers")
	camera.pinch_zoom = 0.0
	camera.twist_turn = 0.0
	var zoom := camera.zoom
	yaw = camera.yaw
	_drag(camera, 1, b, Vector2(1000, 200))
	check(near(camera.zoom, zoom) and near(camera.yaw, yaw), "pinch_zoom and twist_turn at 0: neither")
	_touch(camera, 0, a, false)
	_touch(camera, 1, Vector2(1000, 200), false)
	var follow_camera := _camera_3d(RtsCamera3D.Mode.FOLLOW)
	_follow(follow_camera)
	follow_camera.zoom = 0.2
	var scale := func() -> float:
		return follow_camera.distance_zoom_base + follow_camera.distance_zoom_scale * follow_camera.zoom
	var before: float = scale.call()
	_touch(follow_camera, 0, Vector2(500, 400), true)
	_touch(follow_camera, 1, Vector2(700, 400), true)
	_drag(follow_camera, 1, Vector2(700, 400), Vector2(600, 400))
	check(near(scale.call(), before * 2.0, 0.001), "FOLLOW: the gap halves, the distance doubles")
	_touch(follow_camera, 0, Vector2(500, 400), false)
	_touch(follow_camera, 1, Vector2(600, 400), false)


func test_touch_no_finger_stays_down() -> void:
	var camera := _camera_3d(RtsCamera3D.Mode.FREE)
	camera.zoom = 0.5
	camera.target_zoom = 0.5
	camera._place()
	_touch(camera, 0, Vector2(400, 300), true)
	_touch(camera, 1, Vector2(600, 300), true)
	var modal := Node.new()
	root.add_child(modal)
	modal.add_to_group(RtsWorldInput.modal_group)
	_touch(camera, 0, Vector2(400, 300), false)
	_touch(camera, 1, Vector2(600, 300), false)
	modal.queue_free()
	await tree.process_frame
	check(camera._touch.is_idle(), "fingers lifted while a modal is open are lifted")
	_touch(camera, 0, Vector2(400, 300), true)
	_drag(camera, 0, Vector2(400, 300), Vector2(400, 380))
	check(near(camera.zoom, 0.5) and near(camera.yaw, 0.0), "one finger after it only drags")
	camera.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(camera._touch.is_idle(), "the window losing the focus lifts them")
	_touch(camera, 0, Vector2(400, 300), true)
	camera.touch_enabled = false
	check(camera._touch.is_idle(), "and turning touch off")
	camera.touch_enabled = true
	var at := camera.free_target
	camera.touch_enabled = false
	_touch(camera, 0, Vector2(400, 300), true)
	_drag(camera, 0, Vector2(400, 300), Vector2(500, 300))
	check(near(camera.free_target, at) and camera._touch.is_idle(), "touch off: fingers do nothing")
	_touch(camera, 0, Vector2(500, 300), false)


func test_touch_over_the_ui_is_the_uis() -> void:
	RtsKeymap.install()
	var view := _ui_view()
	_edge_button(view)
	var camera := RtsCamera3D.new()
	camera.mode = RtsCamera3D.Mode.FREE
	view.add_child(camera)
	camera.current = true
	var moves := func(at: Vector2) -> bool:
		# Godot hovers the control under a finger with the mouse it emulates, before the finger.
		await _hover(view, at)
		var before := camera.free_target
		_touch(camera, 0, at, true)
		_drag(camera, 0, at, at + Vector2(80, 0))
		_touch(camera, 0, at + Vector2(80, 0), false)
		return not near(camera.free_target, before)
	check(not await moves.call(Vector2(30, 360)), "a finger that lands on a HUD button does not move the map")
	check(await moves.call(Vector2(400, 200)), "one on the world does")
	camera.edges_over_gui = true
	check(await moves.call(Vector2(30, 360)), "edges_over_gui: over the UI too")
	camera.edges_over_gui = false
	var area := Control.new()
	area.position = Vector2(200, 0)
	area.size = Vector2(1080, 720)
	view.add_child(area)
	camera.edge_area = area
	check(await moves.call(Vector2(400, 200)), "edge_area: a finger on it moves the map")
	Input.emulate_mouse_from_touch = false
	check(await moves.call(Vector2(400, 200)), "with no emulated mouse, edge_area's rectangle tells")
	check(not await moves.call(Vector2(100, 200)), "and a finger outside it does nothing")
	Input.emulate_mouse_from_touch = true


func test_the_emulated_mouse() -> void:
	var view := _ui_view()
	var camera := RtsCamera3D.new()
	camera.mode = RtsCamera3D.Mode.FREE
	view.add_child(camera)
	camera.current = true
	RtsKeymap.install()
	camera.select_drag_pans = true
	Input.action_press(&"rts_select")
	var motion := InputEventMouseMotion.new()
	motion.device = InputEvent.DEVICE_ID_EMULATION
	motion.relative = Vector2(80, 0)
	camera._input(motion)
	Input.action_release(&"rts_select")
	check(near(camera.free_target, Vector3.ZERO), "the mouse emulated from a finger does not pan a second time")
	var at_edge := InputEventMouseMotion.new()
	at_edge.device = InputEvent.DEVICE_ID_EMULATION
	at_edge.position = Vector2(5, 200)
	camera._input(at_edge)
	camera._process(0.5)
	check(near(camera.free_target, Vector3.ZERO), "nor is the pointer at an edge (a finger lifted there)")
	await _hover(view, Vector2(5, 200))
	camera._process(0.5)
	check(not near(camera.free_target, Vector3.ZERO), "a real mouse at the edge pans")
	var at := camera.free_target
	_touch(camera, 0, Vector2(400, 300), true)
	Input.action_press(&"rts_camera_orbit")
	var real := InputEventMouseMotion.new()
	real.relative = Vector2(80, 0)
	camera._input(real)
	Input.action_release(&"rts_camera_orbit")
	check(near(camera.free_target, at), "while the camera's fingers are down, the mouse does not move it")
	_touch(camera, 0, Vector2(400, 300), false)


func test_takes_drag() -> void:
	var camera := _camera_3d(RtsCamera3D.Mode.FREE)
	check(not camera.takes_drag(), "nothing held")
	Input.action_press(&"rts_select")
	check(not camera.takes_drag(), "the select button draws the box in an RTS")
	camera.select_drag_pans = true
	check(camera.takes_drag(), "with select_drag_pans it moves the map")
	Input.action_release(&"rts_select")
	Input.action_press(&"rts_camera_orbit")
	check(camera.takes_drag(), "the orbit button drags the map")
	Input.action_release(&"rts_camera_orbit")
	_touch(camera, 0, Vector2(400, 300), true)
	check(camera.takes_drag(), "a finger on the map")
	var modal := Node.new()
	root.add_child(modal)
	modal.add_to_group(RtsWorldInput.modal_group)
	check(not camera.takes_drag(), "nothing under a modal")
	modal.free()
	_touch(camera, 0, Vector2(400, 300), false)
	check(not camera.takes_drag(), "the finger lifted")
	camera.mode = RtsCamera3D.Mode.FOLLOW
	Input.action_press(&"rts_select")
	check(not camera.takes_drag(), "FOLLOW: the select button is no pan")
	Input.action_release(&"rts_select")
	Input.action_press(&"rts_camera_orbit")
	check(camera.takes_drag(), "FOLLOW: the orbit button looks around")
	Input.action_release(&"rts_camera_orbit")
	var pointer := RtsPointer.new()
	root.add_child(pointer)
	check(not pointer.camera_takes_drag(), "the pointer with no camera: no")
	pointer.camera = camera
	Input.action_press(&"rts_camera_orbit")
	check(pointer.camera_takes_drag(), "the pointer asks its camera")
	Input.action_release(&"rts_camera_orbit")


func test_select_drag_pans() -> void:
	var camera := _camera_3d(RtsCamera3D.Mode.FREE)
	camera._place()
	Input.action_press(&"rts_select")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(80, 0)
	camera._on_motion(motion)
	check(near(camera.free_target, Vector3.ZERO), "off by default (an RTS draws its box)")
	camera.select_drag_pans = true
	var small := InputEventMouseMotion.new()
	small.relative = Vector2(1, 0)
	camera._dragged = false
	camera._drag_travel = 0.0
	camera._on_motion(small)
	check(near(camera.free_target, Vector3.ZERO) and not camera.is_dragging(), "a shaky click does not nudge the map")
	camera._on_motion(motion)
	var went_left := camera.free_target.dot(RtsSpace.right(camera.yaw)) < -0.5
	check(went_left and camera.is_dragging(), "on: a select drag moves the map")
	Input.action_release(&"rts_select")


func test_focus_glides() -> void:
	var camera := _camera_3d(RtsCamera3D.Mode.FREE)
	check(camera.focus(Vector3(6, 0, 0), 0.4), "a glide starts")
	check(near(camera.free_target, Vector3.ZERO), "not there at once")
	camera._glide.custom_step(0.2)
	check(camera.free_target.x > 1.0 and camera.free_target.x < 5.0, "halfway: %s" % camera.free_target)
	camera._glide.custom_step(0.3)
	check(near(camera.free_target, Vector3(6, 0, 0), 0.001), "there at the end")
	camera.focus(Vector3(-6, 0, 0), 0.4)
	camera._glide.custom_step(0.1)
	camera._pan(Vector2(1, 0))
	var kept := camera.free_target
	check(camera._glide == null, "a pan by the player stops the glide")
	camera._process(0.3)
	check(near(camera.free_target, kept), "and it stays where the player left it")
	var loose := RtsCamera3D.new()
	check(loose.focus(Vector3(3, 0, 0), 1.0) and near(loose.free_target, Vector3(3, 0, 0)), "out of the tree: at once")
	loose.free()


func test_camera_2d() -> void:
	RtsKeymap.install()
	var camera := RtsCamera2D.new()
	root.add_child(camera)
	camera.make_current()
	check(near(camera.yaw, PI), "unturned: formations face up the screen")
	camera.bounds = Rect2(0, 0, 1000, 1000)
	check(camera.focus(Vector3(5000, 0, 300)) and near(camera.global_position, Vector2(1000, 300)), "focus, kept in bounds")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	var zoom_before := camera.zoom.x
	camera._input(wheel)
	check(camera.zoom.x > zoom_before, "the wheel zooms in")
	Input.action_press(&"rts_camera_orbit")
	var drag := InputEventMouseMotion.new()
	drag.relative = Vector2(10, 0)
	var at := camera.global_position
	camera._input(drag)
	Input.action_release(&"rts_camera_orbit")
	check(camera.global_position.x < at.x and camera.is_dragging(), "a middle drag moves the map with the pointer")
	camera.can_turn = true
	camera.ignore_rotation = false
	camera.rotation = PI * 0.5
	var up := Vector2(0, -1).rotated(PI * 0.5)
	check(near(camera.yaw, atan2(up.x, up.y)), "turned: the yaw follows the screen's up")


func test_camera_2d_edges_and_the_ui() -> void:
	RtsKeymap.install()
	var view := _ui_view()
	_edge_button(view)
	var camera := RtsCamera2D.new()
	view.add_child(camera)
	camera.make_current()
	var pans := func(at: Vector2) -> bool:
		await _hover(view, at)
		var before := camera.global_position
		camera._process(0.5)
		return not near(camera.global_position, before)
	check(not await pans.call(Vector2(10, 360)), "2D: not over a HUD button at the edge")
	check(await pans.call(Vector2(10, 200)), "2D: the edge over the world pans it")
	camera.edges_over_gui = true
	check(await pans.call(Vector2(10, 360)), "2D: edges_over_gui pans over the button too")


func test_camera_2d_touch() -> void:
	RtsKeymap.install()
	var camera := RtsCamera2D.new()
	root.add_child(camera)
	camera.make_current()
	camera.global_position = Vector2(500, 500)
	_touch(camera, 0, Vector2(400, 300), true)
	_drag(camera, 0, Vector2(400, 300), Vector2(405, 304))
	_touch(camera, 0, Vector2(405, 304), false)
	var still := near(camera.global_position, Vector2(500, 500))
	check(still and not camera.is_dragging(), "2D: a tap moves nothing and stays a click")
	_touch(camera, 0, Vector2(400, 300), true)
	_drag(camera, 0, Vector2(400, 300), Vector2(500, 300))
	_touch(camera, 0, Vector2(500, 300), false)
	check(camera.global_position.x < 500.0 and camera.is_dragging(), "2D: a finger drags the map")
	var a := Vector2(500, 400)
	var b := Vector2(700, 400)
	var zoom := camera.zoom.x
	var anchor: Vector2 = camera._world_at((a + b) * 0.5)
	_touch(camera, 0, a, true)
	_touch(camera, 1, b, true)
	_drag(camera, 1, b, Vector2(900, 400))
	b = Vector2(900, 400)
	check(near(camera.zoom.x, zoom * 2.0, 0.001), "2D: the gap doubles, the zoom doubles")
	check(camera._world_at((a + b) * 0.5).distance_to(anchor) < 0.5, "2D: the world under the fingers stays under them")
	var rotation := camera.rotation
	var turned := _turned(b, (a + b) * 0.5, 40.0)
	_drag(camera, 1, b, turned)
	check(near(camera.rotation, rotation), "2D: no twist without can_turn")
	camera.can_turn = true
	camera.ignore_rotation = false
	var middle := (a + turned) * 0.5
	var mark: Vector2 = camera._world_at(middle + Vector2(150, 0))
	var screen_of := func(world: Vector2) -> Vector2:
		var size := camera.get_viewport().get_visible_rect().size
		return ((world - camera.global_position - camera.offset) * camera.zoom).rotated(-camera.global_rotation) + size * 0.5
	var before_angle: float = (screen_of.call(mark) - middle).angle()
	var again := _turned(turned, middle, 40.0)
	_drag(camera, 1, turned, again)
	var after_middle := (a + again) * 0.5
	var spin := angle_difference(before_angle, (screen_of.call(mark) - after_middle).angle())
	check(spin > 0.15, "2D: with can_turn the map turns with the fingers: %s rad" % spin)
	_touch(camera, 0, a, false)
	_touch(camera, 1, again, false)
	check(not camera.takes_drag(), "2D: nothing held")
	_touch(camera, 0, Vector2(400, 300), true)
	check(camera.takes_drag(), "2D: a finger on the map takes the drag")
	_touch(camera, 0, Vector2(400, 300), false)


func test_camera_2d_select_drag_and_glide() -> void:
	RtsKeymap.install()
	var camera := RtsCamera2D.new()
	root.add_child(camera)
	camera.make_current()
	Input.action_press(&"rts_select")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(80, 0)
	camera._input(motion)
	var kept := near(camera.global_position, Vector2.ZERO)
	check(kept and not camera.takes_drag(), "2D: the select drag is the box's by default")
	camera.select_drag_pans = true
	check(camera.takes_drag(), "2D: with select_drag_pans it is the camera's")
	camera._dragged = false
	camera._drag_travel = 0.0
	var small := InputEventMouseMotion.new()
	small.relative = Vector2(1, 0)
	camera._input(small)
	check(near(camera.global_position, Vector2.ZERO), "2D: a shaky click does not nudge it")
	camera._input(motion)
	check(camera.global_position.x < 0.0 and camera.is_dragging(), "2D: a select drag moves the map")
	Input.action_release(&"rts_select")
	var from := camera.global_position
	check(camera.focus(Vector3(300, 0, 0), 0.4), "2D: a glide starts")
	check(near(camera.global_position, from), "2D: not there at once")
	camera._glide.custom_step(0.4)
	check(near(camera.global_position, Vector2(300, 0), 0.01), "2D: there at the end")
	camera.focus(Vector3(-300, 0, 0), 0.4)
	camera._glide.custom_step(0.1)
	camera._move_screen(Vector2(5, 0))
	check(camera._glide == null, "2D: a pan by the player stops the glide")
