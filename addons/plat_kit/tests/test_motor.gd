extends "res://addons/plat_kit/tests/plat_test.gd"

## PlatMotor on real physics: landing and running, the jump and its cut, the apex, the jump buffer,
## coyote time, the jump corner, the wall jump, the lift, and a driver that ticks the motor itself.
## Every motor here is fed by code (read_input off). Each test builds its own small world (floor top
## at y = 0) and plays it tick by tick.

const BODY := Vector2(20.0, 40.0)

var _world: Node2D


func _start() -> void:
	_world = Node2D.new()
	tree.root.add_child(_world)


func _end() -> void:
	_world.queue_free()
	await tree.process_frame


func _box(rect: Rect2) -> StaticBody2D:
	var box := StaticBody2D.new()
	box.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var size := RectangleShape2D.new()
	size.size = rect.size
	shape.shape = size
	box.add_child(shape)
	_world.add_child(box)
	return box


## A body standing at `feet` (its bottom middle) with a PlatMotor that a driver feeds (read_input off).
func _player(feet: Vector2) -> PlatMotor:
	var body := CharacterBody2D.new()
	body.position = feet - Vector2(0.0, BODY.y * 0.5 + 0.5)
	var shape := CollisionShape2D.new()
	var size := RectangleShape2D.new()
	size.size = BODY
	shape.shape = size
	body.add_child(shape)
	var motor := PlatMotor.new()
	motor.body = body
	motor.read_input = false
	body.add_child(motor)
	_world.add_child(body)
	return motor


func _ticks(count: int) -> void:
	for i in count:
		await tree.physics_frame


## Ticks until the body is on the floor again (at most `limit`), returning the highest its feet got
## (smallest y) and how many ticks it was airborne.
func _flight(motor: PlatMotor, release_after := -1, limit := 240) -> Dictionary:
	var top := INF
	var ticks := 0
	var left_floor := false
	for i in limit:
		if i == release_after:
			motor.release_jump()
		await tree.physics_frame
		var feet := motor.body.position.y + BODY.y * 0.5
		top = minf(top, feet)
		if not motor.body.is_on_floor():
			left_floor = true
			ticks += 1
		elif left_floor:
			break
	return {"top": top, "ticks": ticks}


func test_lands_runs_and_stops() -> void:
	_start()
	_box(Rect2(-2000, 0, 4000, 40))
	var motor := _player(Vector2(0, -30))
	await _ticks(40)
	check(motor.body.is_on_floor(), "falls and lands")
	motor.axis = 1.0
	await _ticks(20)
	check(is_equal_approx(motor.body.velocity.x, motor.max_speed), "runs at max_speed (%.1f)" % motor.body.velocity.x)
	check(motor.body.position.x > 20.0, "moves right")
	motor.axis = 0.0
	await _ticks(10)
	check(motor.body.velocity.x == 0.0, "friction stops it")
	await _end()


func test_jump_hold_and_cut() -> void:
	_start()
	_box(Rect2(-2000, 0, 4000, 40))
	var motor := _player(Vector2.ZERO)
	await _ticks(10)
	motor.request_jump()
	var held := await _flight(motor)
	check(held.ticks > 20, "a held jump leaves the floor (%d ticks)" % held.ticks)
	check(held.top < -50.0, "and rises (%.1f px)" % -held.top)
	motor.request_jump()
	var cut := await _flight(motor, 3)
	check(cut.top > held.top + 20.0, "releasing early cuts it (%.1f vs %.1f px)" % [-cut.top, -held.top])
	check(cut.ticks < held.ticks, "and lands sooner")
	await _end()


func test_apex_floats_while_held() -> void:
	_start()
	_box(Rect2(-2000, 0, 4000, 40))
	var motor := _player(Vector2.ZERO)
	await _ticks(10)
	motor.apex_gravity_mult = 1.0
	motor.request_jump()
	var plain := await _flight(motor)
	motor.apex_gravity_mult = 0.3
	motor.request_jump()
	var floaty := await _flight(motor)
	check(floaty.ticks > plain.ticks, "a lower apex_gravity_mult hangs longer (%d vs %d ticks)" % [floaty.ticks, plain.ticks])
	await _end()


func test_jump_buffer() -> void:
	_start()
	_box(Rect2(-2000, 0, 4000, 40))
	var motor := _player(Vector2(0, -4))
	motor.request_jump()
	motor.release_jump()
	var rose := false
	for i in 30:
		await tree.physics_frame
		rose = rose or motor.body.velocity.y < -100.0
	check(rose, "a tap just before landing jumps on landing")
	await _ticks(90)
	var high := _player(Vector2(200, -120))
	high.request_jump()
	high.release_jump()
	var jumped := false
	for i in 60:
		await tree.physics_frame
		jumped = jumped or high.body.velocity.y < -100.0
	check(not jumped, "a tap long before landing is forgotten")
	await _end()


func test_coyote_time() -> void:
	_start()
	_box(Rect2(-2000, 0, 2000, 40))
	_box(Rect2(-2000, 400, 6000, 40))
	for late in [2, 12]:
		var motor := _player(Vector2(-40, 0))
		await _ticks(10)
		motor.axis = 1.0
		for i in 120:
			await tree.physics_frame
			if not motor.body.is_on_floor():
				break
		motor.axis = 0.0
		await _ticks(late)
		motor.request_jump()
		await _ticks(1)
		if late == 2:
			check(motor.body.velocity.y < 0.0, "jump %d ticks after running off the ledge: coyote" % late)
		else:
			check(motor.body.velocity.y > 0.0, "jump %d ticks after: too late, it falls" % late)
		motor.body.queue_free()
		await tree.process_frame
	await _end()


func test_jump_corner() -> void:
	for pixels in [4, 0]:
		_start()
		_box(Rect2(-2000, 0, 4000, 40))
		# A ceiling 30 px above the head whose edge overlaps the body's right side by 2 px.
		_box(Rect2(8, -BODY.y - 40, 200, 10))
		var motor := _player(Vector2.ZERO)
		motor.jump_corner_pixels = pixels
		await _ticks(10)
		motor.request_jump()
		var flight := await _flight(motor)
		var head: float = flight.top - BODY.y
		if pixels > 0:
			check(head < -BODY.y - 40.0, "jump_corner_pixels slips past a 2 px corner (head at %.1f)" % head)
		else:
			check(head >= -BODY.y - 30.5, "with it off the head bonks (head at %.1f)" % head)
		await _end()


func test_wall_jump() -> void:
	_start()
	_box(Rect2(-2000, 0, 4000, 40))
	_box(Rect2(BODY.x * 0.5, -400, 40, 400))
	var motor := _player(Vector2(0, -150))
	motor.wall_jump_enabled = true
	await _ticks(4)
	check(motor.wall_dir() == 1, "a wall on the right")
	motor.request_jump()
	await _ticks(1)
	check(motor.body.velocity.x < 0.0 and motor.body.velocity.y < 0.0, "jumps up and away (%s)" % motor.body.velocity)
	await _end()


func test_lift_is_kept_on_the_jump() -> void:
	# Godot's default adds the platform's velocity on leaving; with DO_NOTHING the motor adds the lift.
	for leave in [CharacterBody2D.PLATFORM_ON_LEAVE_ADD_VELOCITY, CharacterBody2D.PLATFORM_ON_LEAVE_DO_NOTHING]:
		_start()
		var lift := AnimatableBody2D.new()
		lift.position = Vector2(0, 20)
		var shape := CollisionShape2D.new()
		var size := RectangleShape2D.new()
		size.size = Vector2(400, 40)
		shape.shape = size
		lift.add_child(shape)
		_world.add_child(lift)
		var motor := _player(Vector2.ZERO)
		motor.body.platform_on_leave = leave
		motor.friction = 0.0
		await _ticks(10)
		for i in 10:
			lift.position.x += 2.0
			await tree.physics_frame
		var carried := motor.body.get_platform_velocity().x
		check(carried > 100.0, "the platform carries the body (%.1f px/s)" % carried)
		motor.request_jump()
		lift.position.x += 2.0
		await _ticks(3)
		var kept := motor.body.velocity.x
		check(not motor.body.is_on_floor() and absf(kept - carried) < 10.0, "platform_on_leave %d: the jump keeps its speed once (%.1f)" % [leave, kept])
		await _end()


func test_a_driver_ticks_it_itself() -> void:
	_start()
	_box(Rect2(-2000, 0, 4000, 40))
	var motor := _player(Vector2(0, -10))
	motor.auto_process = false
	var step := 1.0 / Engine.physics_ticks_per_second
	for i in 20:
		await tree.physics_frame
		motor.tick(step)
	check(motor.body.is_on_floor(), "auto_process off: nothing moves until tick(), which lands it")
	motor.axis = -1.0
	motor.request_jump()
	var top := 0.0
	for i in 20:
		await tree.physics_frame
		motor.tick(step)
		top = minf(top, motor.body.position.y + BODY.y * 0.5)
	check(top < -30.0 and motor.body.position.x < -20.0, "tick() runs, jumps and moves (feet %.0f, x %.0f)" % [top, motor.body.position.x])
	await _end()
