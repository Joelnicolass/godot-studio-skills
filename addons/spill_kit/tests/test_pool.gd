extends "res://addons/spill_kit/tests/spill_test.gd"

## SpillPool3D: the rings of marks and puddles, the floor they lie on, the player's option and the
## cost.


func test_marks_stay_and_the_oldest_is_reused() -> void:
	box(Vector3.ZERO)
	var pool := new_pool()
	pool.marks_per_type = 8
	var type := new_type({"mark_radius_m": 0.0})
	await physics()
	for i in 10:
		pool.spill(type, Vector3(i * 0.1, 1, 0))
	check(pool.mark_count(type) == 8, "8 marks: the ring is full")
	var marks := pool.marks_of(type)
	check(marks.size() == 8, "8 transforms")
	# The ninth and tenth went in slots 0 and 1: their x is the farthest.
	check(marks[0].origin.x > 0.3 and marks[1].origin.x > 0.4, "slots 0 and 1 hold the newest")
	var heights: Array[float] = []
	for mark in marks:
		heights.append(mark.origin.y)
	check(heights[7] > heights[2], "each slot a bit higher, no two at one height")
	check(near(heights[2] - heights[1], pool.mark_lift_step_m, 0.00005), "mark_lift_step_m apart")


func test_a_puddle_follows_a_slope() -> void:
	var slope := Basis(Vector3.RIGHT, deg_to_rad(15))
	box(Vector3.ZERO, Vector3(20, 0.2, 20), 1, slope)
	var pool := new_pool()
	var type := new_type({"puddle_grow_s": 0.0})
	await physics()
	pool.puddle(type, Vector3(0, 1, 0))
	var puddles := pool.puddles_of(type)
	check(puddles.size() == 1, "a puddle on the slope")
	if puddles.size() == 1:
		check(near(puddles[0].basis.y.normalized(), slope.y, 0.001), "lies along the floor's normal (%s)" % puddles[0].basis.y.normalized())
		check(near(puddles[0].basis.x.length(), type.puddle_size_m, 0.001), "puddle_grow_s 0: full size at once")
	pool.spill(type, Vector3(0, 1, 0))
	var mark: Transform3D = pool.marks_of(type)[0]
	check(near(mark.basis.y.normalized(), slope.y, 0.001), "a mark too")


func test_a_puddle_shrinks_to_stay_off_a_curb() -> void:
	box(Vector3.ZERO)
	# A 15 cm curb from x 0.4 on.
	box(Vector3(5.4, 0.15, 0), Vector3(10, 0.2, 20))
	var pool := new_pool()
	var type := new_type({"puddle_grow_s": 0.0})
	await physics()
	pool.puddle(type, Vector3(0, 1, 0))
	var puddles := pool.puddles_of(type)
	check(puddles.size() == 1, "a puddle by the curb")
	if puddles.size() == 1:
		var side := puddles[0].basis.x.length()
		check(side < type.puddle_size_m and side >= pool.puddle_min_m, "smaller than puddle_size_m, at least puddle_min_m (%.2f)" % side)
		check(side * pool.puddle_edge_share < 0.4, "its edge stays off the curb")
	pool.puddle(type, Vector3(0.3, 1, 0))
	check(pool.puddles_of(type).size() == 1, "too close to the curb: no puddle")


func test_the_ring_of_puddles() -> void:
	box(Vector3.ZERO)
	var pool := new_pool()
	pool.puddles = 4
	var type := new_type({"puddle_grow_s": 0.0})
	await physics()
	for i in 6:
		pool.puddle(type, Vector3(i * 2.0 - 6.0, 1, 0))
	check(pool.puddles_of(type).size() == 4, "4 puddles: the oldest are reused")
	var xs: Array[float] = []
	for each in pool.puddles_of(type):
		xs.append(each.origin.x)
	xs.sort()
	check(near(xs[0], -2.0, 0.001), "the first two gave way (%s)" % [xs])


func test_the_player_s_option_and_a_new_round() -> void:
	box(Vector3.ZERO)
	var pool := new_pool()
	var type := new_type()
	await physics()
	pool.spill(type, Vector3(0, 1, 0))
	pool.shown = false
	pool.spill(type, Vector3(0, 1, 0))
	pool.puddle(type, Vector3(0, 1, 0))
	check(pool.mark_count(type) == 1, "hidden: no new marks, the old one stays")
	check(pool.puddles_of(type).is_empty() and pool.sprays_played(type) == 1, "no puddle, no spray")
	pool.shown = true
	pool.puddle(type, Vector3(0, 1, 0))
	pool.clear()
	check(pool.mark_count(type) == 0 and pool.puddles_of(type).is_empty(), "clear() takes everything off the floor")
	check(flying(pool).is_empty(), "and out of the air")
	pool.spill(type, Vector3(0, 1, 0))
	check(pool.mark_count(type) == 1, "and it spills again")


func test_it_builds_once_per_type() -> void:
	var pool := new_pool()
	var type := new_type()
	pool.prepare(type)
	var nodes := pool.get_child_count(true)
	pool.prepare(type)
	check(pool.get_child_count(true) == nodes, "a second prepare builds nothing")
	check(nodes == 2 * pool.sprays_per_type + 1 + pool.puddles, "%d sprays, 1 MultiMesh, %d puddles (%d)" % [2 * pool.sprays_per_type, pool.puddles, nodes])
	check(pool.get_child_count() == 0, "all internal: nothing of the kit shows in the scene's tree")
	pool.prepare(new_type())
	check(pool.get_child_count(true) == nodes + 2 * pool.sprays_per_type + 1, "a second type adds its sprays and marks, and shares the puddles")


func test_the_cost() -> void:
	var pool := new_pool()
	check(pool.cost()["types"] == 0 and pool.cost_text().contains("no types"), "no types yet")
	pool.types = [new_type(), new_type()]
	var cost := pool.cost()
	check(cost["drops"] == 2 * 6 * (14 + 32), "552 drops (%d)" % cost["drops"])
	check(cost["marks"] == 128 and cost["puddles"] == 12, "128 marks, 12 puddles")
	check(cost["draw_calls"] == 2 * 13 + 12, "38 draw calls at most")
	check(pool.cost_text().contains("552 drops"), pool.cost_text())


func test_one_pool_per_world_and_its_warnings() -> void:
	var first := new_pool()
	var second := new_pool()
	check(SpillPool3D.of(first.get_world_3d()) == first, "the first one draws the world")
	check(second._get_configuration_warnings().size() == 1, "the second is warned")
	first.free()
	check(SpillPool3D.of(second.get_world_3d()) == null, "the first gone, the world has none until one enters")
	second.floor_mask = 0
	var warned := "\n".join(second._get_configuration_warnings())
	check(warned.contains("floor_mask"), "an empty floor_mask is warned")
	var small := new_type({"puddle_size_m": 0.2, "mark_min_m": 0.9})
	second.types = [small, null]
	warned = "\n".join(second._get_configuration_warnings())
	check(warned.contains("puddle_min_m"), "a puddle under puddle_min_m")
	check(warned.contains("mark_min_m"), "mark_min_m above mark_max_m")
	check(warned.contains("empty slot"), "an empty slot")


func test_it_spills_without_a_source() -> void:
	box(Vector3.ZERO)
	var pool := new_pool()
	var oil := new_type({"color": Color.BLACK, "drops": 0})
	await physics()
	pool.spill(oil, Vector3(0, 0.5, 0), Vector3.RIGHT)
	check(pool.mark_count(oil) == 1, "a leak marks the floor")
	check(flying(pool).is_empty(), "drops 0: no spray")
	pool.puddle(oil, Vector3(0, 0.5, 0))
	check(pool.puddles_of(oil).size() == 1, "and pools")


func test_each_type_is_drawn_once_at_load_so_the_first_hit_does_not_stall() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(0, 2, 5)
	root.add_child(camera)
	camera.current = true
	var pool := new_pool()
	var type := new_type()
	pool.prepare(type)
	var built := pool.get_child_count(true)
	await tree.process_frame
	await tree.process_frame
	check(pool.get_child_count(true) == built + 3, "a drop, a mark and a puddle drawn once (%d)" % (pool.get_child_count(true) - built))
	var ahead := camera.global_position - camera.global_basis.z * (camera.near + SpillPool3D.WARM_AHEAD_M)
	var drop := pool.get_child(built, true) as CPUParticles3D
	var mark := pool.get_child(built + 1, true) as MultiMeshInstance3D
	var puddle := pool.get_child(built + 2, true) as MeshInstance3D
	check(drop != null and drop.emitting and drop.global_position.distance_to(ahead) < 0.01, "a drop flying in front of the camera")
	check(drop != null and (drop.mesh as QuadMesh).size.x < 0.001, "under a pixel wide")
	check(drop != null and drop.mesh.surface_get_material(0) == pool.material_of(type, SpillShapes.Shape.DROP), "with the drops' own material")
	# A MultiMesh's instances are not kept by the headless renderer: its mesh and count are.
	check(mark != null and mark.multimesh.instance_count == 1, "one mark")
	check(mark != null and mark.multimesh.mesh.surface_get_material(0) == pool.material_of(type, SpillShapes.Shape.MARK), "with the marks' own mesh and material")
	check(puddle != null and puddle.global_position.distance_to(ahead) < 0.01 and puddle.global_basis.x.length() < 0.001, "a tiny puddle in front of the camera")
	check(puddle != null and puddle.material_override == pool.material_of(type, SpillShapes.Shape.PUDDLE), "with the puddles' own material")
	check(pool.mark_count(type) == 0, "it is not a mark on the floor")
	for i in SpillPool3D.WARM_FRAMES + 3:
		await tree.process_frame
	check(pool.get_child_count(true) == built, "then it is gone")
	camera.queue_free()
