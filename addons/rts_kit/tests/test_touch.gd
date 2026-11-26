extends "res://addons/rts_kit/tests/rts_test.gd"

## The fingers through Godot's own input (Input.parse_input_event, with the mouse Godot emulates from
## a finger arriving before the finger), on a 3D scene with the camera, the pointer, the selection
## and the select input together: a tap selects, a finger that moves the map never draws a box, a
## two-finger touch is no click, a finger on the HUD is the HUD's, and a select drag that moves the
## map draws no box.

var camera: RtsCamera3D
var selection: RtsSelection
var pointer: RtsPointer
var select_input: RtsSelectInput
var empties := 0


func _scene() -> RtsUnit:
	RtsKeymap.install()
	Input.use_accumulated_input = false
	camera = RtsCamera3D.new()
	camera.mode = RtsCamera3D.Mode.FREE
	root.add_child(camera)
	camera.current = true
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 400)
	shape.shape = box
	ground.add_child(shape)
	root.add_child(ground)
	ground.global_position = Vector3(0, -0.5, 0)
	var drawn := ColorRect.new()
	drawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(drawn)
	selection = RtsSelection.new()
	selection.box = drawn
	root.add_child(selection)
	pointer = RtsPointer.new()
	pointer.dimension = RtsPointer.Dimension.D3
	pointer.camera = camera
	root.add_child(pointer)
	select_input = RtsSelectInput.new()
	select_input.selection = selection
	select_input.pointer = pointer
	root.add_child(select_input)
	empties = 0
	select_input.clicked_empty.connect(func() -> void: empties += 1)
	var body := StaticBody3D.new()
	body.collision_layer = 2
	var unit_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.6
	unit_shape.shape = sphere
	body.add_child(unit_shape)
	root.add_child(body)
	body.global_position = Vector3(0, 0.5, 0)
	var unit := RtsUnit.new()
	body.add_child(unit)
	camera._place()
	return unit


func _done() -> void:
	Input.use_accumulated_input = true


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


func _mouse_button(pressed: bool, at: Vector2) -> void:
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = pressed
	button.position = at
	button.global_position = at
	_send(button)


func _mouse_to(from: Vector2, to: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = to
	motion.global_position = to
	motion.relative = to - from
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	_send(motion)


func test_a_tap_is_a_click_with_the_kits_keymap() -> void:
	RtsKeymap.install()
	var all := true
	var bindings := RtsKeymap.bindings()
	for action: StringName in bindings:
		for event: InputEvent in bindings[action]:
			all = all and event.device == RtsKeymap.ALL_DEVICES
	check(all, "every default binding is for every device, as Project Settings saves them")
	var tap := InputEventMouseButton.new()
	tap.device = InputEvent.DEVICE_ID_EMULATION
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	check(tap.is_action_pressed(&"rts_select"), "the mouse Godot emulates from a finger is the select button")


func test_a_finger_pans_and_never_draws_a_box() -> void:
	var unit := _scene()
	await physics(3)
	var at := camera.unproject_position(unit.body.global_position)
	_finger(0, at, true)
	_finger(0, at, false)
	await tree.process_frame
	check(selection.units() == [unit], "a tap selects the unit under it")
	var start := camera.free_target
	var from := Vector2(300, 500)
	var boxed := false
	_finger(0, from, true)
	for i in 10:
		var to := from + Vector2(4, 0)
		_slide(0, from, to)
		from = to
		boxed = boxed or select_input.is_boxing()
	for i in 4:
		var to := from + Vector2(60, -20)
		_slide(0, from, to)
		from = to
		boxed = boxed or select_input.is_boxing()
	_finger(0, from, false)
	await tree.process_frame
	check(not boxed, "the finger that moved the map never drew a box")
	check(selection.units() == [unit] and empties == 0, "and it changed no selection when it lifted")
	check(not near(camera.free_target, start), "the map moved")
	_finger(0, Vector2(200, 600), true)
	_finger(1, Vector2(320, 600), true)
	_finger(0, Vector2(200, 600), false)
	_finger(1, Vector2(320, 600), false)
	await tree.process_frame
	check(selection.units() == [unit] and empties == 0, "a two-finger touch is no click")
	_finger(0, Vector2(200, 600), true)
	_finger(0, Vector2(200, 600), false)
	await tree.process_frame
	check(selection.is_empty() and empties == 1, "a tap on the ground clears the selection")
	_done()


func test_a_finger_on_the_hud_is_the_huds() -> void:
	_scene()
	var button := Button.new()
	button.position = Vector2(0, 0)
	button.size = Vector2(200, 100)
	root.add_child(button)
	var presses: Array = []
	button.pressed.connect(func() -> void: presses.append(true))
	await physics(3)
	var start := camera.free_target
	_finger(0, Vector2(100, 50), true)
	_slide(0, Vector2(100, 50), Vector2(150, 60))
	_finger(0, Vector2(150, 60), false)
	await tree.process_frame
	check(presses.size() == 1, "the button took the touch")
	check(near(camera.free_target, start), "a finger that landed on the HUD did not move the map")
	_done()


func test_a_select_drag_that_moves_the_map_draws_no_box() -> void:
	var unit := _scene()
	camera.select_drag_pans = true
	await physics(3)
	selection.click(unit, Vector2.ZERO, false, false)
	var start := camera.free_target
	var from := Vector2(300, 500)
	var boxed := false
	_mouse_button(true, from)
	for i in 12:
		var to := from + Vector2(1, 0)
		_mouse_to(from, to)
		from = to
		boxed = boxed or select_input.is_boxing()
	_mouse_button(false, from)
	await tree.process_frame
	check(not boxed, "a slow straight select drag drew no box")
	check(not near(camera.free_target, start), "it moved the map")
	check(selection.units() == [unit] and empties == 0, "and the release was no click")
	_done()
