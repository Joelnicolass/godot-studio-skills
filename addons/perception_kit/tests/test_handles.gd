extends "res://addons/perception_kit/tests/perception_test.gd"

## The handles' drags without the editor: the 3D gizmo's and the 2D view's, from a ray or a point
## of the screen to the sensor's own values (the editor check drags them in a real editor).

const Gizmo := preload("res://addons/perception_kit/editor/perception_gizmo_3d.gd")
const Plugin := preload("res://addons/perception_kit/plugin.gd")


func test_drag_3d() -> void:
	var sensor := PerceptionSensor3D.new()
	root.add_child(sensor)
	sensor.global_position = Vector3(2, 0, 0)
	sensor.eye_height_m = 1.5
	# From above, onto the view's plane (the eyes' height), 12 m ahead.
	Gizmo.drag(sensor, 0, Vector3(2, 40, -12), Vector3.DOWN)
	check(near(sensor.sight_radius_m, 12.0), "the sight handle dragged 12 m ahead (%.1f)" % sensor.sight_radius_m)
	Gizmo.drag(sensor, 1, Vector3(2, 40, -9), Vector3.DOWN)
	check(near(sensor.lose_radius_m, 12.0), "the lose handle stops at the sight radius")
	Gizmo.drag(sensor, 1, Vector3(2, 40, -25), Vector3.DOWN)
	check(near(sensor.lose_radius_m, 25.0), "and goes out to 25 m")
	Gizmo.drag(sensor, 2, Vector3(12, 40, -10), Vector3.DOWN)
	check(near(sensor.view_angle_deg, 90.0), "the angle handle at 45° off: a 90° view (%.0f)" % sensor.view_angle_deg)
	Gizmo.drag(sensor, 3, Vector3(2, 40, 3), Vector3.DOWN)
	check(near(sensor.near_radius_m, 3.0), "the near handle 3 m behind")
	Gizmo.drag(sensor, 4, Vector3(2, 1.8, 10), Vector3.FORWARD)
	check(near(sensor.eye_height_m, 1.8), "the eye handle at 1.8 m (%.2f)" % sensor.eye_height_m)
	sensor.rotation = Vector3(0, PI * 0.5, 0)
	Gizmo.drag(sensor, 0, Vector3(-8, 40, 0), Vector3.DOWN)
	check(near(sensor.sight_radius_m, 10.0), "turned 90°, ahead is -X (%.1f)" % sensor.sight_radius_m)


func test_drag_2d() -> void:
	var sensor := PerceptionSensor2D.new()
	root.add_child(sensor)
	sensor.global_position = Vector2(100, 100)
	var handles := Plugin.screen_handles(sensor)
	var to_screen := sensor.get_viewport_transform()
	check(handles.size() == 4 and near(handles[0], to_screen * Vector2(420, 100)), "four handles; sight 320 px ahead (+X)")
	check(Plugin.handle_at(sensor, handles[2] + Vector2(3, 3)) == 2, "a press next to the angle handle grabs it")
	check(Plugin.handle_at(sensor, to_screen * Vector2(100, 400)) == -1, "away from them, none")
	Plugin.drag(sensor, 0, to_screen * Vector2(350, 100))
	check(near(sensor.sight_radius_px, 250.0), "the sight handle dragged 250 px ahead")
	Plugin.drag(sensor, 2, to_screen * Vector2(200, 200))
	check(near(sensor.view_angle_deg, 90.0), "the angle handle at 45°: a 90° view")
	Plugin.drag(sensor, 3, to_screen * Vector2(40, 100))
	check(near(sensor.near_radius_px, 60.0), "the near handle 60 px behind")
	sensor.scale = Vector2(3, 3)
	Plugin.drag(sensor, 1, to_screen * Vector2(600, 100))
	check(near(sensor.lose_radius_px, 500.0), "the node's scale does not change the world's pixels")
