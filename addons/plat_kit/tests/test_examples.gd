extends "res://addons/plat_kit/tests/plat_test.gd"

## The minimal example runs as a player would play it, through the InputMap actions its motor reads:
## it lands, runs, jumps from the floor onto the low ledge, and a tap jumps lower than a hold.


func _ticks(count: int) -> void:
	for i in count:
		await tree.physics_frame


func _send(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


## Jumps through the InputMap, holding for `hold` ticks, and returns the highest the feet got.
func _jump(body: CharacterBody2D, hold: int) -> float:
	var top := body.position.y
	_send(&"ui_accept", true)
	for i in 120:
		if i == hold:
			_send(&"ui_accept", false)
		await tree.physics_frame
		top = minf(top, body.position.y)
		if i > hold and body.is_on_floor():
			break
	return top


func test_minimal_2d_runs() -> void:
	var scene := (load("res://addons/plat_kit/examples/minimal_2d/minimal_2d.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	var body := scene.get_node(^"Player") as CharacterBody2D
	await _ticks(20)
	check(body.is_on_floor(), "the player stands on the floor")
	var floor_y := body.position.y
	var tap := floor_y - await _jump(body, 2)
	await _ticks(10)
	var hold := floor_y - await _jump(body, 60)
	check(tap > 5.0 and hold > tap + 20.0, "a tap hops (%.0f px), a hold jumps higher (%.0f px)" % [tap, hold])
	Input.action_press(&"ui_right")
	for i in 120:
		await tree.physics_frame
		if body.position.x > 260.0:
			break
	check(body.position.x > 260.0, "the arrows run it right")
	_send(&"ui_accept", true)
	for i in 60:
		await tree.physics_frame
	_send(&"ui_accept", false)
	Input.action_release(&"ui_right")
	await _ticks(60)
	check(body.is_on_floor() and body.position.y < floor_y - 60.0, "it jumps onto the low ledge (y %.0f)" % body.position.y)
	scene.queue_free()
	await tree.process_frame
