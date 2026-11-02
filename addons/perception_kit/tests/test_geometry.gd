extends "res://addons/perception_kit/tests/perception_test.gd"

## The pure rules: a view's angle in 3D and 2D, strength, the drawn lines, and the handles' math.

const Handles := preload("res://addons/perception_kit/editor/perception_handles.gd")


func test_view_3d() -> void:
	var half := deg_to_rad(120.0) * 0.5
	var eye := Vector3(0, 1.6, 0)
	var basis := Basis.IDENTITY
	check(PerceptionGeometry.in_view_3d(eye, basis, Vector3(0, 1.6, -10), half), "straight ahead (-Z) is in view")
	check(PerceptionGeometry.in_view_3d(eye, basis, Vector3(5, 1.6, -10), half), "26° off is in a 120° view")
	check(not PerceptionGeometry.in_view_3d(eye, basis, Vector3(10, 1.6, -3), half), "73° off is not")
	check(not PerceptionGeometry.in_view_3d(eye, basis, Vector3(0, 1.6, 10), half), "behind is not")
	check(PerceptionGeometry.in_view_3d(eye, basis, Vector3(0.5, 9.0, -1.0), half), "the height does not count: high up ahead is in view")
	check(PerceptionGeometry.in_view_3d(eye, basis, Vector3(0, 5, 0), half), "straight above counts as in view")
	check(PerceptionGeometry.in_view_3d(eye, basis, Vector3(0, 1.6, 10), PI), "a full view sees behind")
	var turned := Basis(Vector3.UP, PI * 0.5)
	check(PerceptionGeometry.in_view_3d(eye, turned, Vector3(-10, 1.6, 0), half), "turned 90° left it looks along -X")
	check(not PerceptionGeometry.in_view_3d(eye, turned, Vector3(0, 1.6, -10), half), "and -Z is then off to its side")
	var scaled := Basis.IDENTITY.scaled(Vector3(3, 1, 0.2))
	check(PerceptionGeometry.in_view_3d(eye, scaled, Vector3(5, 1.6, -10), half), "the basis's scale does not change the angle")


func test_view_2d() -> void:
	var half := deg_to_rad(90.0) * 0.5
	check(PerceptionGeometry.in_view_2d(Vector2.ZERO, 0.0, Vector2(100, 0), half), "2D: straight ahead (+X)")
	check(PerceptionGeometry.in_view_2d(Vector2.ZERO, 0.0, Vector2(100, 90), half), "42° off is in a 90° view")
	check(not PerceptionGeometry.in_view_2d(Vector2.ZERO, 0.0, Vector2(100, 110), half), "48° off is not")
	check(not PerceptionGeometry.in_view_2d(Vector2.ZERO, 0.0, Vector2(-100, 0), half), "behind is not")
	check(PerceptionGeometry.in_view_2d(Vector2(50, 50), PI * 0.5, Vector2(50, 150), half), "rotated 90° it looks down (+Y)")


func test_strength() -> void:
	check(near(PerceptionGeometry.strength_at(0.0, 10.0), 1.0), "1 at the eye")
	check(near(PerceptionGeometry.strength_at(7.5, 10.0), 0.25), "0.25 at three quarters")
	check(near(PerceptionGeometry.strength_at(12.0, 10.0), 0.0), "0 past the radius")
	check(near(PerceptionGeometry.strength_at(1.0, 0.0), 0.0), "0 with no radius")


func test_view_lines() -> void:
	var lines := PerceptionGeometry.view_lines_3d(15.0, 20.0, 120.0, 2.5)
	check(lines.size() > 0 and lines.size() % 2 == 0, "pairs of points (%d)" % lines.size())
	var far := 0.0
	var flat := true
	for point in lines:
		far = maxf(far, point.length())
		flat = flat and is_zero_approx(point.y)
	check(near(far, 20.0, 0.01) and flat, "on the plane, out to the lose radius (%.2f)" % far)
	check(lines[1].z < 0.0, "the fan's edges go forward (-Z)")
	var round := PerceptionGeometry.view_lines_2d(10.0, 10.0, 360.0, 0.0)
	var from_eye := 0
	for point in round:
		if point == Vector2.ZERO:
			from_eye += 1
	check(from_eye == 0, "a full view is a circle, without edges from the eye")


func test_handles_on_the_plane() -> void:
	var points := Handles.points(15.0, 20.0, 120.0, 2.5)
	check(points[Handles.SIGHT] == Vector2(15, 0) and points[Handles.LOSE] == Vector2(20, 0), "sight and lose ahead")
	check(near(points[Handles.ANGLE].angle(), deg_to_rad(60.0)) and near(points[Handles.ANGLE].length(), 15.0), "the angle on the sight arc's edge")
	check(points[Handles.NEAR] == Vector2(-2.5, 0), "near behind")
	check(near(Handles.value_at(Handles.SIGHT, Vector2(12.04, 3.0), 15.0, 20.0, 0.1), 12.4), "sight: the distance, snapped")
	check(near(Handles.value_at(Handles.SIGHT, Vector2(30, 0), 15.0, 20.0, 0.1), 20.0), "sight stays under lose")
	check(near(Handles.value_at(Handles.LOSE, Vector2(5, 0), 15.0, 20.0, 0.1), 15.0), "lose stays over sight")
	check(near(Handles.value_at(Handles.ANGLE, Vector2.from_angle(deg_to_rad(-45.0)) * 9.0, 15.0, 20.0, 0.1), 90.0), "the angle: twice the side's, either side")
	check(near(Handles.value_at(Handles.ANGLE, Vector2(-1, 0.001), 15.0, 20.0, 0.1), 360.0), "behind: all around")
	check(near(Handles.value_at(Handles.NEAR, Vector2(0, 3.33), 15.0, 20.0, 0.1), 3.3), "near: the distance")


func test_handles_in_space() -> void:
	var frame := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(4, 1.6, 0))
	var ahead := Handles.to_space(frame, Vector2(10, 0))
	check(near(ahead, Vector3(-6, 1.6, 0), 0.001), "the plane's forward is the frame's -Z (%s)" % ahead)
	var from := Vector3(-6, 30, 0)
	var at: Variant = Handles.on_plane(frame, from, Vector3.DOWN)
	check(at is Vector2 and near(at, Vector2(10, 0), 0.001), "a ray down onto the plane (%s)" % [at])
	check(Handles.on_plane(frame, from, Vector3.UP) == null, "a ray away from the plane misses")
	var height := Handles.height_at(Vector3(4, 0, 0), Vector3(4, 2.5, 10), Vector3.FORWARD)
	check(near(height, 2.5), "the eye height where a level ray passes the sensor (%.2f)" % height)
	check(is_nan(Handles.height_at(Vector3.ZERO, Vector3(0, 9, 0), Vector3.DOWN)), "no height from a ray straight down")
