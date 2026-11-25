extends "res://addons/turn_kit/tests/turn_test.gd"

## The minimal example plays as a person would: Spend action, Next phase and End turn until the match is over, with the
## time pushed by hand.


func test_minimal_runs() -> void:
	var scene := (load("res://addons/turn_kit/examples/minimal/minimal.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	var clock := scene.get_node(^"%Turns") as TurnClock
	clock.advance_time = false
	var spend := scene.get_node(^"%Spend") as Button
	var next_phase := scene.get_node(^"%NextPhase") as Button
	var end := scene.get_node(^"%End") as Button
	var status := scene.get_node(^"%Status") as Label
	var log_label := scene.get_node(^"%Log") as Label
	check(clock.current_seat == 0 and status.text.begins_with("Ana"), "Ana starts: %s" % status.text)
	check(clock.current_phase == &"draw" and status.text.contains("draw"), "in the draw phase: %s" % status.text)
	check(log_label.text.contains("Round 1 opens with Ana"), "the log says who opens: %s" % log_label.text)
	spend.pressed.emit()
	check(clock.actions_left == 0 and status.text.contains("actions 0"), "Spend uses an action: %s" % status.text)
	check(spend.disabled, "and none is left")
	next_phase.pressed.emit()
	check(clock.current_phase == &"play" and clock.current_seat == 0, "Next phase moves on")
	clock.tick(4.0)
	await tree.process_frame
	check(status.text.contains("%.1f s" % clock.time_left), "the time is shown: %s" % status.text)
	check(clock.time_left > 5.0 and clock.time_left < 6.01, "6 s left, give or take a frame")
	next_phase.pressed.emit()
	check(clock.current_seat == 1, "Next phase in the last phase passes the turn")
	clock.tick(10.0)
	check(clock.current_seat == 2 and log_label.text.contains("Beto ran out of time"), "no time: the turn passes")
	await tree.process_frame
	check(clock.current_seat == 1 and clock.turn_cycle.round_number == 2, "the bot passed by itself: round 2")
	check(log_label.text.contains("Round 2 opens with Beto"), "and Beto opens it: %s" % log_label.text)
	for i in 12:
		if clock.turn_cycle.is_finished:
			break
		end.pressed.emit()
		await tree.process_frame
	check(clock.turn_cycle.is_finished, "2 cycles of 2 rounds: the match is over")
	check(status.text == "Match over" and spend.disabled and end.disabled and next_phase.disabled, "buttons are off")
	scene.queue_free()
	await tree.process_frame
