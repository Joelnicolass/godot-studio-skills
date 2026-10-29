extends "res://addons/fsm_kit/tests/fsm_test.gd"

## The minimal example runs as a player would play it: an arrow moves, releasing stops, Enter hits,
## a hit while hurt only refreshes the push, and the knockback ends in Idle.


func _physics_frames(count: int) -> void:
	for i in count:
		await tree.physics_frame


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func test_minimal_2d_runs() -> void:
	var scene := (load("res://addons/fsm_kit/examples/minimal_2d/minimal_2d.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	var mover := scene.get_node(^"Mover") as CharacterBody2D
	var states := mover.get_node(^"States") as FsmMachine
	var label := scene.get_node(^"Hud/State") as Label
	var changes: Array[String] = []
	states.state_changed.connect(func(from: StringName, to: StringName) -> void: changes.append("%s>%s" % [from, to]))
	check(states.is_in(&"Idle"), "starts in Idle")
	check(label.text.contains("Idle"), "the label shows it: %s" % label.text)
	var start := mover.position
	Input.action_press(&"ui_right")
	await _physics_frames(10)
	check(states.is_in(&"Move"), "an arrow: Move")
	check(mover.position.x > start.x + 10.0, "it walks right (%s)" % mover.position)
	check(label.text.contains("Move"), "the label follows state_changed")
	Input.action_release(&"ui_right")
	await _physics_frames(3)
	check(states.is_in(&"Idle"), "released: Idle")
	_press(&"ui_accept")
	check(states.is_in(&"Hurt") and states.payload == Vector2.UP, "Enter: Hurt with the push as payload")
	check(mover.modulate != Color.WHITE, "hurt tints the actor")
	var y := mover.position.y
	await _physics_frames(5)
	check(mover.position.y < y, "knocked back along the push")
	var before := changes.size()
	mover.call(&"hit", Vector2.LEFT)
	check(changes.size() == before and states.payload == Vector2.LEFT, "a hit while hurt: same state, a new push")
	var x := mover.position.x
	await _physics_frames(5)
	check(mover.position.x < x, "the new push wins")
	await _physics_frames(40)
	check(states.is_in(&"Idle"), "the knockback ends in Idle")
	check(mover.modulate == Color.WHITE, "and the tint goes")
	check(changes == ["Idle>Move", "Move>Idle", "Idle>Hurt", "Hurt>Idle"], "the transitions: %s" % [changes])
	scene.queue_free()
	await tree.process_frame
