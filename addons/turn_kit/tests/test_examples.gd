extends "res://addons/turn_kit/tests/turn_test.gd"

## The minimal example plays as a person would: press Spend and End until the match is over.


func test_minimal_runs() -> void:
	var scene := (load("res://addons/turn_kit/examples/minimal/minimal.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	var clock := scene.get_node(^"%Turns") as TurnClock
	var spend := scene.get_node(^"%Spend") as Button
	var end := scene.get_node(^"%End") as Button
	var status := scene.get_node(^"%Status") as Label
	check(clock.current_seat == 0 and status.text.begins_with("Ana"), "Ana starts: %s" % status.text)
	spend.pressed.emit()
	check(clock.actions_left == 2 and status.text.contains("actions 2"), "Spend uses an action: %s" % status.text)
	end.pressed.emit()
	check(clock.current_seat == 1, "End passes to Beto")
	end.pressed.emit()
	await tree.process_frame
	check(clock.current_seat == 0 and clock.turn_cycle.round_number == 2, "the bot passed by itself: round 2")
	for i in 6:
		end.pressed.emit()
		await tree.process_frame
	check(clock.turn_cycle.is_finished, "2 cycles of 2 rounds: the match is over")
	check(status.text == "Match over" and spend.disabled and end.disabled, "and the buttons are off")
	scene.queue_free()
	await tree.process_frame
