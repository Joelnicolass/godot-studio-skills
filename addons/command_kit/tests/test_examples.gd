extends "res://addons/command_kit/tests/command_test.gd"

## The minimal example plays as a person would: place stones, hit an occupied cell, undo, replay.


func test_minimal_runs() -> void:
	var scene := (load("res://addons/command_kit/examples/minimal/minimal.tscn") as PackedScene).instantiate()
	scene.set(&"replay_step", 0.0)
	tree.root.add_child(scene)
	await tree.process_frame
	var bus := scene.get_node(^"%Commands") as CommandBus
	var board := scene.get_node(^"%Board") as GridContainer
	var status := scene.get_node(^"%Status") as Label
	var undo := scene.get_node(^"%Undo") as Button
	var cell := func(column: int, row: int) -> Button: return board.get_child(row * 5 + column) as Button
	check(board.get_child_count() == 25 and undo.disabled, "a 5 × 5 board, nothing to undo")
	(cell.call(0, 0) as Button).pressed.emit()
	(cell.call(1, 0) as Button).pressed.emit()
	check((cell.call(0, 0) as Button).text == "X" and (cell.call(1, 0) as Button).text == "O", "X then O")
	(cell.call(1, 0) as Button).pressed.emit()
	check(status.text.contains("occupied") and bus.size() == 2, "an occupied cell is rejected: %s" % status.text)
	(cell.call(2, 2) as Button).pressed.emit()
	undo.pressed.emit()
	check((cell.call(2, 2) as Button).text == "" and bus.size() == 2, "undo takes the last stone back")
	(scene.get_node(^"%Replay") as Button).pressed.emit()
	await tree.process_frame
	check((cell.call(0, 0) as Button).text == "X" and (cell.call(1, 0) as Button).text == "O", "replay puts them back")
	check(bus.size() == 2 and status.text.contains("Replayed 2"), "with the same log: %s" % status.text)
	scene.queue_free()
	await tree.process_frame
