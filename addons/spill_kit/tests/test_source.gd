extends "res://addons/spill_kit/tests/spill_test.gd"

## SpillSource3D: the rules of a hit, the one value that travels, and what each machine plays.


func test_a_hit_sprays_and_marks_the_floor_under_the_body() -> void:
	box(Vector3.ZERO)
	var pool := new_pool()
	var type := new_type()
	var source := new_body(type)
	await physics()
	check(source.hit(30, 100, Vector3(0, 1.2, 2)), "a 30 % hit spills")
	check(pool.sprays_played(type) == 1, "one spray")
	check(not SpillWound.is_heavy(source.wound), "light")
	check(pool.mark_count(type) == 1, "one mark (marks_per_spray 1)")
	var mark: Transform3D = pool.marks_of(type)[0]
	check(near(mark.origin.y, pool.mark_lift_m, 0.001), "the mark lies on the floor, lifted (%.4f)" % mark.origin.y)
	check(Vector2(mark.origin.x, mark.origin.z).length() <= type.mark_radius_m + 0.001, "within mark_radius_m of the body")
	var size := mark.basis.x.length()
	check(size >= type.mark_min_m - 0.001 and size <= type.mark_max_m + 0.001, "a size between mark_min_m and mark_max_m (%.2f)" % size)
	check(near(mark.basis.y.normalized(), Vector3.UP, 0.001), "flat on a flat floor")


func test_the_drops_fly_away_from_where_the_hit_came_from() -> void:
	box(Vector3.ZERO)
	var pool := new_pool()
	var source := new_body(new_type())
	await physics()
	source.hit(30, 100, Vector3(0, 1.2, 3))
	var sprays := flying(pool)
	check(sprays.size() == 1, "one spray in the air")
	if sprays.size() == 1:
		# A spray flies along its -Z.
		check(near(-sprays[0].global_basis.z, Vector3(0, 0, -1), 0.001), "away from the hit, along -Z (%s)" % -sprays[0].global_basis.z)
		check(near(sprays[0].global_position, source.global_position, 0.001), "from the source")
		check(sprays[0].emitting, "emitting")


func test_heavy_at_forty_percent_or_by_the_blow() -> void:
	box(Vector3.ZERO)
	var pool := new_pool()
	var type := new_type()
	var source := new_body(type)
	await physics()
	check(source.hit(40, 100), "40 % spills")
	check(SpillWound.is_heavy(source.wound), "heavy")
	check(pool.mark_count(type) == 3, "3 marks (marks_per_heavy)")
	check(source.hit(1, 100, Vector3.INF, true), "a heavy blow right after spills anyway")
	check(SpillWound.is_heavy(source.wound) and SpillWound.sprays_of(source.wound) == 2, "heavy, the second")
	source.heavy_from = 0.6
	await wait_s(source.every_s + 0.05)
	source.hit(50, 100)
	check(not SpillWound.is_heavy(source.wound), "with heavy_from 0.6, 50 % is light")


func test_light_sprays_keep_apart_and_tiny_hits_add_up() -> void:
	box(Vector3.ZERO)
	var pool := new_pool()
	var type := new_type()
	var source := new_body(type)
	await physics()
	check(source.hit(10, 100), "the first hit spills")
	check(not source.hit(10, 100), "the next one, right after, does not")
	await wait_s(source.every_s + 0.05)
	check(source.hit(10, 100), "past every_s it spills again")
	for i in 20:
		source.hit(1, 100)
	check(pool.sprays_played(type) == 2, "a stream of 1 %% hits right after a spray adds no spray yet (%d)" % pool.sprays_played(type))
	await wait_s(source.every_s + 0.05)
	check(source.hit(1, 100), "past every_s, what the stream lost (20 %) spills")
	check(not source.hit(0, 100) and not source.hit(5, 0), "no damage or no max HP: nothing")


func test_a_death_grows_a_puddle_under_the_body() -> void:
	box(Vector3.ZERO)
	var pool := new_pool()
	var type := new_type({"puddle_grow_s": 0.2})
	var source := new_body(type, Vector3(1, 0, 1))
	await physics()
	source.die()
	var puddles := pool.puddles_of(type)
	check(puddles.size() == 1, "a puddle")
	check(SpillWound.sprays_of(source.wound) == 0, "a death is no spray")
	check(pool.sprays_played(type) == 0, "no drops")
	if puddles.size() == 1:
		check(near(puddles[0].basis.x.length(), pool.puddle_start_m, 0.001), "starts at puddle_start_m")
		check(near(puddles[0].origin, Vector3(1, pool.puddle_lift_m, 1), 0.001), "under the body, lifted")
	await wait_s(0.35)
	puddles = pool.puddles_of(type)
	if puddles.size() == 1:
		check(near(puddles[0].basis.x.length(), type.puddle_size_m, 0.001), "grown to puddle_size_m (%.2f)" % puddles[0].basis.x.length())
	source.die()
	check(pool.puddles_of(type).size() == 2, "a body that came back dies again: a second puddle")


func test_a_machine_that_reads_the_value_plays_the_same() -> void:
	box(Vector3.ZERO)
	var pool := new_pool()
	var type := new_type()
	var server := new_body(type)
	var client := new_body(type, Vector3(4, 0, 0))
	await physics()
	server.hit(45, 100, Vector3(0, 1.2, 2))
	client.wound = server.wound
	check(pool.sprays_played(type) == 2, "the copy played its spray too")
	check(pool.mark_count(type) == 6, "and its marks (3 heavy each)")
	var near_client := 0
	for mark in pool.marks_of(type):
		if mark.origin.x > 2.0:
			near_client += 1
	check(near_client == 3, "the copy's marks are under the copy")
	client.wound = server.wound
	check(pool.sprays_played(type) == 2, "the same value again plays nothing")
	server.die()
	client.wound = server.wound
	check(pool.puddles_of(type).size() == 2, "a death, on both")


func test_a_machine_that_meets_the_body_late_plays_nothing_old() -> void:
	box(Vector3.ZERO)
	var pool := new_pool()
	var type := new_type()
	var server := new_body(type)
	await physics()
	server.hit(45, 100)
	server.die()
	var marks := pool.mark_count(type)
	# The late one's synchronizer gives it the value before it is ready (spawn on).
	var late := SpillSource3D.new()
	late.type = type
	late.wound = server.wound
	late.position = Vector3(4, 1.2, 0)
	root.add_child(late)
	check(pool.sprays_played(type) == 1, "no old spray")
	check(pool.mark_count(type) == marks, "no old marks")
	check(pool.puddles_of(type).size() == 1, "no old puddle")
	await wait_s(server.every_s + 0.05)
	server.hit(30, 100)
	late.wound = server.wound
	check(pool.sprays_played(type) == 3, "what comes after, it plays")


func test_the_body_that_spills_lets_the_floor_rays_through() -> void:
	box(Vector3.ZERO)
	var pool := new_pool()
	var type := new_type({"mark_radius_m": 0.0, "marks_per_spray": 2})
	# A shell on the floor layer, under the source: without the exclusion the marks would sit on it.
	var shell := StaticBody3D.new()
	shell.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(1, 0.6, 1)
	shape.shape = box_shape
	shape.position = Vector3(0, 0.6, 0)
	shell.add_child(shape)
	var source := SpillSource3D.new()
	source.type = type
	source.position = Vector3(0, 1.2, 0)
	shell.add_child(source)
	root.add_child(shell)
	await physics()
	source.spray()
	check(pool.mark_count(type) == 2, "two marks")
	for mark in pool.marks_of(type):
		check(mark.origin.y < 0.1, "on the floor, not on the shell (%.2f)" % mark.origin.y)
	check(SpillSource3D.body_above(source) == shell, "the body above it")


func test_no_mark_behind_a_wall_or_in_the_air() -> void:
	box(Vector3.ZERO)
	box(Vector3(0.3, 3, 0), Vector3(0.1, 3, 10))
	var pool := new_pool()
	var type := new_type({"mark_radius_m": 2.0, "marks_per_spray": 16})
	var source := new_body(type)
	await physics()
	for i in 4:
		source.spray()
	check(pool.mark_count(type) == 64, "64 marks")
	var behind := 0
	for mark in pool.marks_of(type):
		if mark.origin.x > 0.25:
			behind += 1
	check(behind == 0, "none behind the wall at x 0.25 (%d)" % behind)
	var high := new_body(type, Vector3(-5, 5, 0))
	await physics()
	var before := pool.sprays_played(type)
	high.spray()
	check(pool.sprays_played(type) == before + 1, "in the air the drops fly")
	var landed := 0
	for mark in pool.marks_of(type):
		if mark.origin.x < -2.5:
			landed += 1
	check(landed == 0, "but leave no mark: the floor is past floor_reach_m")


func test_without_a_pool_one_is_made() -> void:
	box(Vector3.ZERO)
	var type := new_type()
	var source := new_body(type)
	await physics()
	var made := SpillPool3D.of(source.get_world_3d())
	check(made != null, "the world has a pool now")
	check(source.current_pool() == made, "the source draws in it")
	source.spray()
	check(made != null and made.sprays_played(type) == 1, "and it draws")
	if made != null:
		made.queue_free()


func test_a_spray_of_the_game_s_own() -> void:
	box(Vector3.ZERO)
	var pool := new_pool()
	var type := new_type()
	var source := new_body(type)
	await physics()
	source.spray(true)
	source.spray(true)
	check(pool.sprays_played(type) == 2, "spray() skips the rules")
	check(not SpillWound.from_of(source.wound).is_finite(), "from nowhere")
	check(flying(pool).size() == 2, "two heavy sprays in the air")
	var bare := SpillSource3D.new()
	var warnings := bare._get_configuration_warnings()
	bare.free()
	check(warnings.size() == 1 and warnings[0].contains("type"), "with no type the editor warns")


func test_a_low_source_has_its_own_floor_reach() -> void:
	box(Vector3.ZERO)
	var pool := new_pool()
	var type := new_type({"mark_radius_m": 0.0})
	# A bug's shell, 0.8 m up: the floor may be 1.4 m under it (0.6 under its feet).
	var low := new_body(type)
	low.position = Vector3(0, 0.8, 0)
	low.floor_reach_m = 1.4
	await physics()
	low.spray()
	check(pool.mark_count(type) == 1, "on the floor: a mark")
	# The same bug in the air, 0.7 m over the floor: past its reach, though under the pool's 2 m.
	var flying_bug := new_body(type, Vector3(4, 0.7, 0))
	flying_bug.position = Vector3(0, 0.8, 0)
	flying_bug.floor_reach_m = 1.4
	await physics()
	flying_bug.spray()
	check(pool.mark_count(type) == 1, "in the air: no mark (%d)" % pool.mark_count(type))
	flying_bug.floor_reach_m = 0.0
	flying_bug.spray()
	check(pool.mark_count(type) == 2, "0: the pool's floor_reach_m (2 m) finds the floor")
	flying_bug.floor_reach_m = 1.4
	flying_bug.die()
	check(pool.puddles_of(type).is_empty(), "nor a puddle in the air")
