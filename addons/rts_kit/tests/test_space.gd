extends "res://addons/rts_kit/tests/rts_test.gd"

## RtsSpace: one ground for 2D and 3D, the yaw convention, conversions.


func test_yaw_convention() -> void:
	check(near(RtsSpace.ahead(0.0), Vector3(0, 0, 1)), "yaw 0 faces +Z")
	check(near(RtsSpace.right(0.0), Vector3(-1, 0, 0)), "its right is -X")
	check(near(RtsSpace.ahead(PI * 0.5), Vector3(1, 0, 0)), "yaw 90° faces +X")
	check(near(RtsSpace.yaw_of_direction(Vector3(1, 0, 0)), PI * 0.5), "the yaw of +X")
	for yaw in [0.0, 0.7, -2.1, 3.0]:
		check(near(RtsSpace.right(yaw), RtsSpace.ahead(yaw).cross(Vector3.UP)), "right = ahead × up at %s" % yaw)


func test_2d_is_the_ground_seen_from_above() -> void:
	check(RtsSpace.from_2d(Vector2(3, 4)) == Vector3(3, 0, 4), "(x, y) -> (x, 0, y)")
	check(RtsSpace.to_2d(Vector3(3, 9, 4)) == Vector2(3, 4), "(x, y, z) -> (x, z)")
	var body := Node2D.new()
	root.add_child(body)
	body.global_position = Vector2(10, -5)
	check(RtsSpace.position_of(body) == Vector3(10, 0, -5), "a Node2D's position")
	RtsSpace.place(body, Vector3(1, 7, 2))
	check(body.global_position == Vector2(1, 2), "placed back in 2D")
	body.global_rotation = 0.0
	check(near(RtsSpace.ahead(RtsSpace.yaw_of_node(body)), Vector3(1, 0, 0)), "a Node2D faces +X")
	var body3 := Node3D.new()
	root.add_child(body3)
	body3.rotation.y = 0.9
	check(near(RtsSpace.yaw_of_node(body3), 0.9), "a Node3D faces +Z of its basis (rotation.y)")


func test_distance_unit_follows_the_scene() -> void:
	var flat := Node2D.new()
	root.add_child(flat)
	var deep := Node3D.new()
	root.add_child(deep)
	check(RtsSpace.distance_unit(flat) == "px", "a Node2D measures in pixels")
	check(RtsSpace.distance_unit(deep) == "m", "a Node3D in meters")
	check(RtsSpace.distance_unit(root) == "", "neither above: no unit")
	var hud := CanvasLayer.new()
	flat.add_child(hud)
	var inner := Node.new()
	hud.add_child(inner)
	check(RtsSpace.distance_unit(inner) == "px", "the nearest of the two above it decides")
	var suffix := func(node: Node, property: String) -> String:
		for info in node.get_property_list():
			if info["name"] == property:
				return info["hint_string"]
		return "?"
	# What the inspector shows next to each world distance of the kit.
	var unit_2d := RtsUnit.new()
	flat.add_child(unit_2d)
	var unit_3d := RtsUnit.new()
	deep.add_child(unit_3d)
	check(suffix.call(unit_2d, "size") == "suffix:px", "RtsUnit.size under a 2D body: px")
	check(suffix.call(unit_3d, "size") == "suffix:m", "under a 3D body: m")
	for parent: Node in [flat, deep, root]:
		var unit: String = RtsSpace.distance_unit(parent)
		var expected := "" if unit.is_empty() else "suffix:%s" % unit
		var orders := RtsOrders.new()
		parent.add_child(orders)
		var selection := RtsSelection.new()
		parent.add_child(selection)
		for property: String in ["spacing_base", "max_spacing", "retarget_range"]:
			check(suffix.call(orders, property) == expected, "Orders.%s: '%s'" % [property, unit])
		check(suffix.call(orders, "spacing_per_size") == "", "a factor has no unit")
		check(
			suffix.call(selection, "same_type_radius") == expected,
			"Selection.same_type_radius: '%s'" % expected
		)
