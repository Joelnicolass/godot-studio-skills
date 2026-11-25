extends "res://addons/rts_kit/tests/rts_test.gd"

## The command rig as one node (rts_command_rig_3d.tscn, rts_command_rig_2d.tscn): instanced, with
## its camera and ground assigned, mouse events on its view select the units and order them; the
## warnings when a socket is missing; the menu socket; the camera's edges; a HUD over the view.

const RIG_3D := preload("res://addons/rts_kit/rig/rts_command_rig_3d.tscn")
const RIG_2D := preload("res://addons/rts_kit/rig/rts_command_rig_2d.tscn")
const MENU := preload("res://addons/rts_kit/ui/radial/rts_radial_menu.tscn")


func _button(index: MouseButton, pressed: bool, at: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = pressed
	event.position = at
	event.global_position = at
	return event


func _motion(at: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	return event


func _tap(view: Control, index: MouseButton, at: Vector2) -> void:
	view.gui_input.emit(_button(index, true, at))
	view.gui_input.emit(_button(index, false, at))


func _unit_3d(at: Vector3, slot := 1) -> RtsUnit:
	var body := StaticBody3D.new()
	body.collision_layer = 2
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.6
	shape.shape = sphere
	body.add_child(shape)
	root.add_child(body)
	body.global_position = at
	var unit := RtsUnit.new()
	unit.owner_slot = slot
	body.add_child(unit)
	return unit


func _unit_2d(parent: Node, at: Vector2, slot := 1) -> RtsUnit:
	var body := StaticBody2D.new()
	body.collision_layer = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	body.add_child(shape)
	parent.add_child(body)
	body.global_position = at
	var unit := RtsUnit.new()
	unit.owner_slot = slot
	unit.size = 30.0
	body.add_child(unit)
	return unit


func _floor_3d(layer := 1) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	body.add_child(shape)
	root.add_child(body)
	body.global_position = Vector3(0, -0.5, 0)
	return body


func test_rig_3d_selects_and_orders() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.global_transform = Transform3D(
		Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), Vector3(0, 40, 0)
	)
	camera.current = true
	var ground := _floor_3d()
	var mine := [_unit_3d(Vector3(-2, 0.5, 0)), _unit_3d(Vector3(2, 0.5, 0))]
	var foe := _unit_3d(Vector3(12, 0.5, 0), 2)
	# The game's part: one node, two sockets.
	var rig: RtsCommandRig = RIG_3D.instantiate()
	rig.camera = camera
	rig.ground = ground
	root.add_child(rig)
	await physics(3)
	check(not rig.is_2d() and rig.pointer.dimension == RtsPointer.Dimension.D3, "the 3D rig")
	check(
		rig.pointer.camera == camera and rig.pointer.ground == ground, "the sockets reach Pointer"
	)
	check(rig._get_configuration_warnings().is_empty(), "no warnings with both sockets")
	var low := camera.unproject_position(Vector3(-2, 0.5, 0))
	var high := camera.unproject_position(Vector3(2, 0.5, 0))
	rig.view.gui_input.emit(_button(MOUSE_BUTTON_LEFT, true, low.min(high) - Vector2(40, 40)))
	rig.view.gui_input.emit(_motion(low.max(high) + Vector2(40, 40)))
	check(rig.box.visible, "dragging shows the rig's box")
	rig.view.gui_input.emit(_button(MOUSE_BUTTON_LEFT, false, low.max(high) + Vector2(40, 40)))
	check(rig.selection.size() == 2 and not rig.box.visible, "a box on the view selected both")
	check(mine.all(func(u: RtsUnit) -> bool: return u.selected), "they are marked selected")
	var ordered: Array = []
	rig.order_input.ordered.connect(
		func(command: StringName, point: Vector3, _t: Node) -> void:
			ordered.append([command, point])
	)
	_tap(rig.view, MOUSE_BUTTON_RIGHT, camera.unproject_position(Vector3(0, 0, 10)))
	check(
		mine.all(func(u: RtsUnit) -> bool: return u.current_order() != null),
		"a right tap on the ground ordered both"
	)
	check(
		(
			ordered.size() == 1
			and ordered[0][0] == &"move"
			and near(ordered[0][1], Vector3(0, 0, 10), 0.1)
		),
		"a move at the ground point: %s" % [ordered]
	)
	var apart: float = mine[0].current_order().spot().distance_to(mine[1].current_order().spot())
	check(near(apart, 1.25 * 1.0 + 0.85, 0.01), "spaced in meters: %s" % apart)
	_tap(rig.view, MOUSE_BUTTON_RIGHT, camera.unproject_position(Vector3(12, 0.5, 0)))
	check(
		mine.all(func(u: RtsUnit) -> bool: return u.current_order().command == &"attack"),
		"a right tap on a foe: attack"
	)
	check(foe.current_order() == null, "the foe got no order")
	_tap(rig.view, MOUSE_BUTTON_LEFT, camera.unproject_position(Vector3(-2, 0.5, 0)))
	check(rig.selection.units() == [mine[0]], "a left tap selects the unit under it")
	rig.command.local_slot = 2
	check(
		(
			rig.selection.local_slot == 2
			and rig.orders.local_slot == 2
			and rig.pointer.local_slot == 2
		),
		"rig.command.local_slot reaches the pieces"
	)


func test_rig_3d_ground_socket() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.global_transform = Transform3D(
		Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), Vector3(0, 40, 0)
	)
	camera.current = true
	var ground := _floor_3d()
	# A building on the ground's layer, over the floor at x 20.
	var building := StaticBody3D.new()
	building.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 4)
	shape.shape = box
	building.add_child(shape)
	root.add_child(building)
	building.global_position = Vector3(20, 2, 0)
	var rig: RtsCommandRig = RIG_3D.instantiate()
	rig.camera = camera
	rig.ground = ground
	root.add_child(rig)
	await physics(3)
	var at := camera.unproject_position(Vector3(20, 4, 0))
	var hit: Variant = rig.pointer.ground_at(at)
	check(
		hit is Vector3 and absf((hit as Vector3).y) < 0.01, "the building is not ground: %s" % hit
	)
	check(rig.pointer.body_under(at) == building, "it is a body to order on")
	# Changing a socket later reaches the piece too.
	rig.ground = null
	hit = rig.pointer.ground_at(at)
	check(hit is Vector3 and (hit as Vector3).y > 3.0, "no ground socket: anything on the layer")


func test_rig_2d_selects_and_orders() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var camera := Camera2D.new()
	world.add_child(camera)
	var mine := [_unit_2d(world, Vector2(-40, 0)), _unit_2d(world, Vector2(40, 0))]
	var foe := _unit_2d(world, Vector2(300, 0), 2)
	var rig: RtsCommandRig = RIG_2D.instantiate()
	rig.camera = camera
	world.add_child(rig)
	await physics(3)
	check(rig.is_2d() and rig.pointer.dimension == RtsPointer.Dimension.D2, "the 2D rig")
	check(rig._get_configuration_warnings().is_empty(), "2D: the camera is enough, no warnings")
	check(
		(
			near(rig.orders.spacing_base, 8.0)
			and near(rig.orders.max_spacing, 120.0)
			and near(rig.orders.retarget_range, 1200.0)
			and near(rig.selection.same_type_radius, 600.0)
		),
		"its distances come in pixels"
	)
	var screen := func(at: Vector2) -> Vector2:
		return RtsSpace.screen_of(root.get_viewport(), RtsSpace.from_2d(at), true)
	var low: Vector2 = screen.call(Vector2(-40, 0)) - Vector2(30, 30)
	var high: Vector2 = screen.call(Vector2(40, 0)) + Vector2(30, 30)
	rig.view.gui_input.emit(_button(MOUSE_BUTTON_LEFT, true, low))
	rig.view.gui_input.emit(_motion(high))
	rig.view.gui_input.emit(_button(MOUSE_BUTTON_LEFT, false, high))
	check(rig.selection.size() == 2, "a box on the view selected both (%d)" % rig.selection.size())
	_tap(rig.view, MOUSE_BUTTON_RIGHT, screen.call(Vector2(0, -200)))
	var moving := func(u: RtsUnit) -> bool:
		return u.current_order() != null and u.current_order().command == &"move"
	check(mine.all(moving), "a right tap on the ground: move")
	var spots: Array = mine.map(func(u: RtsUnit) -> Vector2: return u.current_order().spot_2d())
	var middle: Vector2 = (spots[0] + spots[1]) * 0.5
	check(near(middle, Vector2(0, -200), 0.5), "around the clicked point: %s" % middle)
	var apart: float = spots[0].distance_to(spots[1])
	check(near(apart, 1.25 * 30.0 + 8.0, 0.01), "spaced in pixels: %s" % apart)
	_tap(rig.view, MOUSE_BUTTON_RIGHT, screen.call(Vector2(300, 0)))
	check(
		mine.all(func(u: RtsUnit) -> bool: return u.current_order().command == &"attack"),
		"a right tap on a foe: attack"
	)
	check(foe.current_order() == null, "the foe got no order")


func test_warnings_when_a_socket_is_missing() -> void:
	var rig_3d: RtsCommandRig = RIG_3D.instantiate()
	root.add_child(rig_3d)
	var warnings := rig_3d._get_configuration_warnings()
	check(warnings.size() == 2, "3D, nothing assigned: two warnings (%d)" % warnings.size())
	check("camera" in warnings[0] and "Camera3D" in warnings[0], "the camera: %s" % warnings[0])
	check("ground" in warnings[1], "the ground: %s" % warnings[1])
	var camera_3d := Camera3D.new()
	root.add_child(camera_3d)
	rig_3d.camera = camera_3d
	warnings = rig_3d._get_configuration_warnings()
	check(warnings.size() == 1 and "ground" in warnings[0], "camera assigned: the ground is left")
	var floor_3d := Node3D.new()
	root.add_child(floor_3d)
	rig_3d.ground = floor_3d
	check(rig_3d._get_configuration_warnings().is_empty(), "both assigned: none")
	var camera_2d := Camera2D.new()
	root.add_child(camera_2d)
	rig_3d.camera = camera_2d
	warnings = rig_3d._get_configuration_warnings()
	check(
		warnings.size() == 1 and "rts_command_rig_2d.tscn" in warnings[0],
		"a 2D camera on the 3D rig names the other scene: %s" % [warnings]
	)
	var rig_2d: RtsCommandRig = RIG_2D.instantiate()
	root.add_child(rig_2d)
	warnings = rig_2d._get_configuration_warnings()
	check(
		warnings.size() == 1 and "Camera2D" in warnings[0],
		"2D, nothing assigned: the camera only (%s)" % [warnings]
	)
	rig_2d.camera = camera_3d
	warnings = rig_2d._get_configuration_warnings()
	check(
		warnings.size() == 1 and "rts_command_rig_3d.tscn" in warnings[0],
		"a 3D camera on the 2D rig names the other scene"
	)
	rig_2d.camera = camera_2d
	check(rig_2d._get_configuration_warnings().is_empty(), "2D with its camera: none")
	# With nothing assigned the rig still runs: the viewport's camera, anything on the ground layer.
	_tap(rig_2d.view, MOUSE_BUTTON_LEFT, Vector2(100, 100))
	check(rig_2d.selection.is_empty(), "a click with no sockets is no error")


func test_sockets_filter_by_dimension() -> void:
	var hints := func(rig: RtsCommandRig) -> Dictionary:
		var found := {}
		for info in rig.get_property_list():
			if info["name"] in ["camera", "ground", "menu", "dimension"]:
				found[info["name"]] = info
		return found
	var rig_3d: RtsCommandRig = RIG_3D.instantiate()
	root.add_child(rig_3d)
	var rig_2d: RtsCommandRig = RIG_2D.instantiate()
	root.add_child(rig_2d)
	var in_3d: Dictionary = hints.call(rig_3d)
	var in_2d: Dictionary = hints.call(rig_2d)
	check(
		in_3d["camera"]["hint_string"] == "Camera3D" and in_3d["ground"]["hint_string"] == "Node3D",
		"3D: the sockets take a Camera3D and a Node3D"
	)
	check(
		in_2d["camera"]["hint_string"] == "Camera2D" and in_2d["ground"]["hint_string"] == "Node2D",
		"2D: the sockets take a Camera2D and a Node2D"
	)
	check(in_3d["camera"]["hint"] == PROPERTY_HINT_NODE_TYPE, "they are node sockets")
	check(
		not (in_3d["dimension"]["usage"] & PROPERTY_USAGE_EDITOR),
		"the dimension is the scene's: not in the inspector"
	)


func test_menu_socket() -> void:
	RtsKeymap.install()
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.global_transform = Transform3D(
		Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), Vector3(0, 40, 0)
	)
	camera.current = true
	var ground := _floor_3d()
	var mine := _unit_3d(Vector3(0, 0.5, 0))
	var rig: RtsCommandRig = RIG_3D.instantiate()
	rig.camera = camera
	rig.ground = ground
	root.add_child(rig)
	var hud := CanvasLayer.new()
	root.add_child(hud)
	var menu: RtsRadialMenu = MENU.instantiate()
	hud.add_child(menu)
	await physics(3)
	check(rig.order_button.menu == null, "no menu: a plain right click")
	rig.menu = menu
	check(
		rig.order_button.menu == menu, "the menu socket reaches OrderButton after the rig is ready"
	)
	rig.selection.select_only([mine])
	var at := camera.unproject_position(Vector3(0, 0, 10))
	rig.view.gui_input.emit(_button(MOUSE_BUTTON_RIGHT, true, at))
	rig.order_button._process(menu.hold_s + 0.01)
	check(menu.is_open(), "holding the right button opens it")
	var entry := RtsMenuEntry.for_command(rig.orders.commands.find(&"attack_move"))
	menu.entry_chosen.emit(entry)
	check(
		mine.current_order() != null and mine.current_order().command == &"attack_move",
		"the chosen entry runs at the press point"
	)
	check(
		near(mine.current_order().point, Vector3(0, 0, 10), 0.1),
		"there: %s" % mine.current_order().point
	)
	menu.cancel()
	rig.menu = null
	mine.stop()
	menu.entry_chosen.emit(entry)
	check(mine.current_order() == null, "taken out, the menu orders nothing")


func test_camera_edges_get_the_view() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var camera := RtsCamera2D.new()
	world.add_child(camera)
	var rig: RtsCommandRig = RIG_2D.instantiate()
	rig.camera = camera
	world.add_child(rig)
	check(camera.edge_area == rig.view, "an RtsCamera with no edge_area gets the rig's view")
	var own_area := Control.new()
	root.add_child(own_area)
	var other := RtsCamera2D.new()
	other.edge_area = own_area
	world.add_child(other)
	rig.camera = other
	check(other.edge_area == own_area, "a camera with its own edge_area keeps it")
	var plain := Camera2D.new()
	world.add_child(plain)
	rig.camera = plain
	check(rig.pointer.camera == plain, "a plain Camera2D is taken as it is")


## A real pointer on a viewport of the test's own: the HUD after the rig keeps its clicks, the
## world under the view gets the rest.
func test_hud_after_the_rig_keeps_its_clicks() -> void:
	RtsKeymap.install()
	var screen := SubViewport.new()
	screen.size = Vector2i(1280, 720)
	root.add_child(screen)
	var world := Node2D.new()
	screen.add_child(world)
	var unit := _unit_2d(world, Vector2(400, 300))
	var rig: RtsCommandRig = RIG_2D.instantiate()
	world.add_child(rig)
	var hud := CanvasLayer.new()
	world.add_child(hud)
	var button := Button.new()
	button.position = Vector2(380, 280)
	button.size = Vector2(40, 40)
	hud.add_child(button)
	var presses: Array = []
	button.pressed.connect(func() -> void: presses.append(true))
	await physics(3)
	var click := func(at: Vector2) -> void:
		screen.push_input(_motion(at))
		screen.push_input(_button(MOUSE_BUTTON_LEFT, true, at))
		screen.push_input(_button(MOUSE_BUTTON_LEFT, false, at))
	click.call(Vector2(400, 300))
	check(presses.size() == 1, "the HUD button over the unit took the click")
	check(rig.selection.is_empty(), "the world did not: nothing selected")
	button.visible = false
	click.call(Vector2(400, 300))
	check(rig.selection.units() == [unit], "with the button gone, the same click selects the unit")
