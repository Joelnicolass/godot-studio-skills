extends "res://addons/command_kit/tests/command_test.gd"

## The minimal example plays as a person would: place stones, hit an occupied cell, undo, replay.


func _board() -> Array:
	var scene := (load("res://addons/command_kit/examples/minimal/minimal.tscn") as PackedScene).instantiate()
	scene.set(&"replay_step", 0.0)
	tree.root.add_child(scene)
	return [scene, scene.get_node(^"%Board")]


func test_minimal_runs() -> void:
	var made := _board()
	var scene: Node = made[0]
	var board := made[1] as GridContainer
	var commands := scene.get_node(^"%Commands") as GameCommands
	var status := scene.get_node(^"%Status") as Label
	var undo := scene.get_node(^"%Undo") as Button
	var cell := func(column: int, row: int) -> Button: return board.get_child(row * 5 + column) as Button
	check(board.get_child_count() == 25 and undo.disabled, "a 5 × 5 board, nothing to undo")
	check(commands.get(&"found_commands") == "place (can, undo)", "the node found the example's command")
	check(commands._get_configuration_warnings().is_empty(), "no warnings")
	(cell.call(0, 0) as Button).pressed.emit()
	(cell.call(1, 0) as Button).pressed.emit()
	check((cell.call(0, 0) as Button).text == "X" and (cell.call(1, 0) as Button).text == "O", "X then O")
	(cell.call(1, 0) as Button).pressed.emit()
	check(
		status.text.contains("Rejected: occupied") and commands.size() == 2,
		"an occupied cell says why: %s" % status.text
	)
	(cell.call(2, 2) as Button).pressed.emit()
	check((cell.call(2, 2) as Button).text == "X" and not undo.disabled, "a third stone")
	undo.pressed.emit()
	check((cell.call(2, 2) as Button).text == "" and commands.size() == 2, "undo takes the last stone back")
	(scene.get_node(^"%Replay") as Button).pressed.emit()
	await tree.process_frame
	check((cell.call(0, 0) as Button).text == "X" and (cell.call(1, 0) as Button).text == "O", "replay puts them back")
	check(commands.size() == 2 and status.text.contains("Replayed 2"), "with the same history: %s" % status.text)
	scene.queue_free()
	await tree.process_frame


func test_replay_with_a_pause() -> void:
	var made := _board()
	var scene: Node = made[0]
	var board := made[1] as GridContainer
	var commands := scene.get_node(^"%Commands") as GameCommands
	scene.set(&"replay_step", 0.02)
	(board.get_child(0) as Button).pressed.emit()
	(board.get_child(1) as Button).pressed.emit()
	(scene.get_node(^"%Replay") as Button).pressed.emit()
	check(commands.size() == 0 and (board.get_child(0) as Button).text == "", "it starts from an empty board")
	(board.get_child(5) as Button).pressed.emit()
	check(commands.size() == 0, "clicks are ignored while it plays")
	await tree.create_timer(0.3).timeout
	check(commands.size() == 2 and (board.get_child(1) as Button).text == "O", "and ends with the same two stones")
	check(not (scene.get_node(^"%Replay") as Button).disabled, "the button is back")
	scene.queue_free()
	await tree.process_frame
