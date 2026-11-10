extends RefCounted

## Builds the tests' worlds: a floor with walls under a NavigationRegion3D, baked from its colliders (layer 1), and
## characters (layer 2) that read their bot's keys like a game's character reads `Input`.

const CHARACTER := preload("res://addons/bot_kit/tests/bot_test_character.gd")


## A square floor `size` m wide at y 0, with box walls (each [center, size]) on layer 1, under a baked region.
static func arena(root: Node, size := 30.0, walls: Array = []) -> NavigationRegion3D:
	var region := NavigationRegion3D.new()
	region.name = "Navigation"
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1
	mesh.agent_radius = 0.5
	mesh.agent_height = 1.75
	mesh.agent_max_climb = 0.25
	region.navigation_mesh = mesh
	root.add_child(region)
	box(region, Vector3(0.0, -0.5, 0.0), Vector3(size, 1.0, size))
	for wall: Array in walls:
		box(region, wall[0], wall[1])
	return region


## A static box on layer 1.
static func box(parent: Node, center: Vector3, extents: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = extents
	shape.shape = box_shape
	body.add_child(shape)
	body.position = center
	parent.add_child(body)
	return body


## Bakes the region and waits for the navigation map to have it (the map takes a few frames, on its own thread).
static func bake(tree: SceneTree, region: NavigationRegion3D) -> void:
	region.bake_navigation_mesh(false)
	var map := region.get_world_3d().navigation_map
	for i in 60:
		await tree.physics_frame
		if NavigationServer3D.map_get_iteration_id(map) != 0 and NavigationServer3D.map_get_closest_point_owner(map, Vector3.ZERO).is_valid():
			return


## A character at `at` facing `yaw`, in the group `bot_target`, with a Bot3D named "Bot" unless `with_bot` is off.
static func character(root: Node, at: Vector3, with_bot := true, yaw := 0.0) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.set_script(CHARACTER)
	body.collision_layer = 2
	body.collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	body.add_child(shape)
	body.position = at
	body.rotation.y = yaw
	body.add_to_group(&"bot_target")
	if with_bot:
		var bot := Bot3D.new()
		bot.name = "Bot"
		bot.random_seed = 7
		body.add_child(bot)
		body.set(&"input", bot.input)
	root.add_child(body)
	return body


static func bot_of(body: Node) -> Bot3D:
	return body.get_node(^"Bot") as Bot3D
