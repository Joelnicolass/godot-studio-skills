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
	pool.puddle_seek_m = 0.0
	pool.puddle(type, Vector3(0.3, 1, 0))
	check(pool.puddles_of(type).size() == 1, "too close to the curb, with puddle_seek_m 0: no puddle")


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


func test_a_made_pool_gives_way_to_the_world_s_own() -> void:
	box(Vector3.ZERO)
	var type := new_type()
	var source := new_body(type)
	await physics()
	var made := SpillPool3D.of(source.get_world_3d())
	check(made != null, "a source with no pool makes one")
	var own := new_pool()
	check(SpillPool3D.of(source.get_world_3d()) == own, "a pool put in the world takes its place")
	check(own._get_configuration_warnings().is_empty(), "with no warning")
	source.spray()
	check(own.sprays_played(type) == 1, "the source draws in it")
	await tree.process_frame
	check(not is_instance_valid(made), "the made one is gone")


func test_the_heavy_spray_is_tuned_on_its_own() -> void:
	var pool := new_pool()
	var type := new_type({
		"drops": 10, "heavy_drops": 30, "drop_life_s": 0.6, "heavy_drop_life_s": 0.85,
		"drop_speed_m_s": 2.0, "heavy_drop_speed_m_s": 3.0, "heavy_drop_size_m": 0.12,
		"heavy_rise_deg": 45.0, "heavy_spread_deg": 38.0, "heavy_drop_scale_min": 0.7,
		"heavy_drop_scale_max": 1.6,
	})
	pool.prepare(type)
	var light: CPUParticles3D = null
	var heavy: CPUParticles3D = null
	for child in pool.get_children(true):
		var spray := child as CPUParticles3D
		if spray != null and spray.amount == 10:
			light = spray
		elif spray != null and spray.amount == 30:
			heavy = spray
	check(light != null and heavy != null, "a light and a heavy spray")
	if heavy == null or light == null:
		return
	check(near(heavy.lifetime, 0.85) and near(light.lifetime, 0.6), "each its own life")
	check(near((heavy.initial_velocity_min + heavy.initial_velocity_max) * 0.5, 3.0), "the heavy one's own speed")
	check(near((light.initial_velocity_min + light.initial_velocity_max) * 0.5, 2.0), "the light one's own speed")
	check(near(heavy.scale_amount_min, 0.7) and near(heavy.scale_amount_max, 1.6), "the heavy one's own size range")
	check(near(light.scale_amount_min, 0.6) and near(light.scale_amount_max, 1.4), "the light one's own size range")
	check(near((heavy.mesh as QuadMesh).size.x, 0.12) and near(heavy.spread, 38.0), "the heavy one's drop size and spread")
	check(near(heavy.direction, Vector3(0, sin(deg_to_rad(45.0)), -cos(deg_to_rad(45.0)))), "the heavy one's rise")
	check(heavy.mesh.surface_get_material(0) == light.mesh.surface_get_material(0), "both drops look alike (one material)")


func test_by_a_curb_the_puddle_moves_to_flat_floor() -> void:
	box(Vector3.ZERO)
	# A 7 cm curb from x 0.1 on: the body lies right by it.
	box(Vector3(2.55, 0.07, 0), Vector3(4.9, 0.2, 10))
	var pool := new_pool()
	var type := new_type({"puddle_grow_s": 0.0})
	await physics()
	pool.puddle(type, Vector3(0, 0.8, 0))
	var puddles := pool.puddles_of(type)
	check(puddles.size() == 1, "a puddle (it used to be none)")
	if puddles.size() == 1:
		var side := puddles[0].basis.x.length()
		check(puddles[0].origin.x + side * pool.puddle_edge_share < 0.1, "away from the curb, not into it (x %.2f, side %.2f)" % [puddles[0].origin.x, side])
		check(near(puddles[0].origin.y, pool.puddle_lift_m, 0.001), "on the low floor, not on the curb")
		check(side >= pool.puddle_min_m, "at least puddle_min_m")
		check(Vector2(puddles[0].origin.x, puddles[0].origin.z).length() <= pool.puddle_seek_m + 0.001, "within puddle_seek_m of the body")


func test_on_a_curb_s_bevel_the_puddle_moves_off_it() -> void:
	box(Vector3.ZERO)
	# A 15 cm curb for x under -0.2, and its bevel down to the floor at x -0.02 (its normal leans
	# about 40 degrees, toward +x).
	box(Vector3(-2.7, 0.15, 0), Vector3(5.0, 0.3, 10))
	var bevel := Basis(Vector3(0, 0, 1), deg_to_rad(-40.5))
	box(Vector3(-0.11, 0.075, 0), Vector3(0.24, 0.4, 10), 1, bevel)
	var pool := new_pool()
	var type := new_type({"puddle_grow_s": 0.0})
	await physics()
	pool.puddle(type, Vector3(-0.1, 0.8, 0))
	var puddles := pool.puddles_of(type)
	check(puddles.size() == 1, "a puddle (it used to be none)")
	if puddles.size() == 1:
		var side := puddles[0].basis.x.length()
		check(puddles[0].origin.x > -0.02, "its middle off the bevel, on the floor below it (x %.2f)" % puddles[0].origin.x)
		# Its edge toward the curb rises no more than puddle_flat_m, the rule of any puddle.
		var edge := puddles[0].origin + Vector3.LEFT * side * pool.puddle_edge_share
		var ray := PhysicsRayQueryParameters3D.create(edge + Vector3.UP, edge + Vector3.DOWN)
		var under := pool.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not under.is_empty() and (under["position"] as Vector3).y <= pool.puddle_flat_m + 0.001, "its edge within puddle_flat_m of the floor (%.3f)" % (under["position"] as Vector3).y if not under.is_empty() else "its edge finds a floor")
		check(near(puddles[0].origin.y, pool.puddle_lift_m, 0.001), "lying on the floor")
		check(near(puddles[0].basis.y.normalized(), Vector3.UP, 0.001), "flat")


func test_a_puddle_never_climbs_or_squeezes() -> void:
	box(Vector3.ZERO)
	# A 30 cm strip of floor between two 12 cm blocks: too narrow, and the flat tops are higher.
	box(Vector3(-2.65, 0.12, 0), Vector3(5.0, 0.2, 10))
	box(Vector3(2.65, 0.12, 0), Vector3(5.0, 0.2, 10))
	var pool := new_pool()
	var type := new_type({"puddle_grow_s": 0.0})
	await physics()
	pool.puddle(type, Vector3(0, 0.8, 0))
	check(pool.puddles_of(type).is_empty(), "no puddle: none fits in the strip and it does not climb onto a block")


func test_on_a_sidewalk_s_bevel_the_puddle_stays_on_the_sidewalk() -> void:
	# A street at y 0, a 30 cm sidewalk for x under -0.25, and its bevel at 40 degrees down to the
	# street. The body dies near the bevel's top: its puddle stays up on the sidewalk.
	box(Vector3.ZERO)
	box(Vector3(-2.75, 0.30, 0), Vector3(5.0, 0.4, 10))
	var run := 0.30 / tan(deg_to_rad(40.0))
	var bevel := Basis(Vector3(0, 0, 1), deg_to_rad(-40.0))
	box(Vector3(-0.25 + run * 0.5, 0.15, 0), Vector3(Vector2(run, 0.30).length(), 0.5, 10), 1, bevel)
	var pool := new_pool()
	var type := new_type({"puddle_grow_s": 0.0})
	await physics()
	pool.puddle(type, Vector3(-0.22, 1.1, 0))
	var puddles := pool.puddles_of(type)
	check(puddles.size() == 1, "a puddle")
	if puddles.size() == 1:
		check(near(puddles[0].origin.y, 0.30 + pool.puddle_lift_m, 0.002), "up on the sidewalk, not down on the street (y %.2f)" % puddles[0].origin.y)
		check(puddles[0].origin.x < -0.25, "on the sidewalk's side (x %.2f)" % puddles[0].origin.x)


func test_a_puddle_does_not_pass_a_low_wall() -> void:
	# A body between a 7 cm curb and a 40 cm wall, 23 cm apart: too narrow, and flat floor behind
	# the wall is the other side of it.
	box(Vector3.ZERO)
	box(Vector3(2.55, 0.07, 0), Vector3(4.9, 0.2, 10))
	box(Vector3(-0.15, 0.4, 0), Vector3(0.04, 0.4, 10))
	var pool := new_pool()
	var type := new_type({"puddle_grow_s": 0.0})
	await physics()
	pool.puddle(type, Vector3(0, 0.8, 0))
	var behind := 0
	for each in pool.puddles_of(type):
		if each.origin.x < -0.15:
			behind += 1
	check(behind == 0, "no puddle behind the wall")
	check(pool.puddles_of(type).is_empty(), "and none fits in front of it")


func test_a_puddle_never_drops_down_a_curb_to_the_street() -> void:
	# The same sidewalk, but 25 cm wide against a building: no puddle fits on it. The street below
	# has room, yet it is the other side of the curb: no puddle.
	box(Vector3.ZERO)
	box(Vector3(-0.375, 0.30, 0), Vector3(0.25, 0.4, 10))
	box(Vector3(-3.0, 3.0, 0), Vector3(5.0, 3.0, 10))
	var run := 0.30 / tan(deg_to_rad(40.0))
	var bevel := Basis(Vector3(0, 0, 1), deg_to_rad(-40.0))
	box(Vector3(-0.25 + run * 0.5, 0.15, 0), Vector3(Vector2(run, 0.30).length(), 0.5, 10), 1, bevel)
	var pool := new_pool()
	var type := new_type({"puddle_grow_s": 0.0})
	await physics()
	for i in 6:
		pool.puddle(type, Vector3(-0.22, 1.1, 0))
	check(_down_on_the_street(pool, type) == 0, "six deaths, no puddle down on the street (%d)" % _down_on_the_street(pool, type))
	pool.puddle_drop_m = 0.5
	pool.puddle(type, Vector3(-0.22, 1.1, 0))
	check(_down_on_the_street(pool, type) == 1, "with puddle_drop_m 0.5 it may run down to the street")


func _down_on_the_street(pool: SpillPool3D, type: SpillType) -> int:
	var down := 0
	for each in pool.puddles_of(type):
		if each.origin.y < 0.2:
			down += 1
	return down
