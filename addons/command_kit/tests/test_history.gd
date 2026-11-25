extends "res://addons/command_kit/tests/command_test.gd"

## The history of a CommandLog: its copy and format, undo, replay (seeded, stopping, with listeners) and re-entry.

const GAME := preload("res://addons/command_kit/tests/fixture_game.gd")


func test_history_is_a_deep_copy() -> void:
	var game := GAME.new()
	var commands := CommandLog.new(game)
	var items: Array = [1, [2]]
	commands.run(1, &"push", [items])
	check(items == [1, [2], 99], "the game changed the array it was given")
	var saved := commands.history()
	check(
		saved == [{"name": &"push", "seat": 1, "args": [[1, [2]]]}], "the history kept what it was before: %s" % [saved]
	)
	saved[0]["args"][0].append("x")
	saved[0]["seat"] = 7
	check(commands.history() == [{"name": &"push", "seat": 1, "args": [[1, [2]]]}], "history() is a copy")
	items.append("later")
	check(commands.history()[0]["args"] == [[1, [2]]], "changing the array after run changes nothing")
	game.free()


func test_the_history_format() -> void:
	var game := GAME.new()
	var commands := CommandLog.new(game)
	commands.run(1, &"add", [2])
	commands.run(0, &"roll")
	var saved := commands.history()
	check(
		saved == [{"name": &"add", "seat": 1, "args": [2]}, {"name": &"roll", "seat": 0, "args": []}],
		"{name, seat, args}"
	)
	check(saved[0]["name"] is StringName, "the name is a StringName")
	game.free()


func test_undo_and_what_do_returned() -> void:
	var game := GAME.new()
	var commands := CommandLog.new(game)
	var heard: Array[String] = []
	commands.undone.connect(
		func(seat: int, name: StringName, args: Array) -> void: heard.append("%d %s %s" % [seat, name, args])
	)
	commands.run(0, &"add", [10])
	commands.run(1, &"add", [5])
	check(commands.can_undo() and commands.undo(), "undo the last one")
	check(game.total == 10 and commands.size() == 1, "it is taken back and leaves the history")
	check(heard == (["1 add [5]"] as Array[String]), "undone says what: %s" % [heard])
	commands.run(0, &"take", [4])
	check(game.total == 6, "take removed 4")
	commands.run(0, &"take", [100])
	check(game.total == 0, "the second take only took 6")
	check(commands.undo() and game.total == 6, "undo_take got what do_take returned (6)")
	check(commands.undo() and game.total == 10, "and the one before (4)")
	check(commands.history() == [{"name": &"add", "seat": 0, "args": [10]}], "the history is back to the first add")
	check(not (commands.history()[0] as Dictionary).has("returned"), "what do_ returned is not in the history")
	game.free()


func test_a_command_with_no_undo() -> void:
	var game := GAME.new()
	var commands := CommandLog.new(game)
	check(not commands.undo(), "nothing to undo")
	commands.run(0, &"add", [2])
	commands.run(0, &"roll")
	check(not commands.can_undo() and not commands.undo(), "the last one has no undo_")
	check(commands.size() == 2, "and stays in the history")
	game.free()


func test_keep_history_off() -> void:
	var game := GAME.new()
	var commands := CommandLog.new(game)
	commands.keep_history = false
	var ran := [0]
	commands.done.connect(func(_seat: int, _name: StringName, _args: Array) -> void: ran[0] += 1)
	check(commands.run(0, &"add", [1]) == "" and ran[0] == 1 and game.total == 1, "it still runs and emits")
	check(commands.size() == 0 and commands.history().is_empty() and not commands.can_undo(), "but keeps nothing")
	game.free()


func test_replay_rebuilds_the_same_state() -> void:
	var game := GAME.new()
	game.rng.seed = 42
	var commands := CommandLog.new(game)
	for i in 5:
		commands.run(i % 2, &"add", [i + 1])
		commands.run(i % 2, &"roll")
	commands.run(0, &"add", [0])
	var saved := commands.history()
	var fresh := GAME.new()
	fresh.rng.seed = 42
	var again := CommandLog.new(fresh)
	check(again.replay(saved) == "", "the whole history replays")
	check(fresh.total == game.total, "same total, rolls included: %d and %d" % [fresh.total, game.total])
	check(again.history() == saved, "the new history equals the old one")
	game.free()
	fresh.free()


func test_replay_stops_at_the_first_that_does_not_run() -> void:
	var game := GAME.new()
	var commands := CommandLog.new(game)
	var entries: Array = [
		{"name": &"add", "seat": 0, "args": [2]},
		{"name": &"add", "seat": 0, "args": [0]},
		{"name": &"add", "seat": 0, "args": [5]},
	]
	check(commands.replay(entries) == "bad_amount", "a rejection stops it, with its reason")
	check(game.total == 2 and commands.size() == 1, "the entries before it ran")
	check(commands.replay([{"name": &"fly", "seat": 0, "args": []}]) == CommandLog.UNKNOWN_COMMAND, "an unknown name")
	check(commands.replay([{"name": &"add", "seat": 0, "args": ["x"]}]) == CommandLog.BAD_ARGUMENTS, "bad arguments")
	game.free()


func test_replay_with_a_listener_that_answers() -> void:
	# A bot answers every move of seat 0 with a move of its own: live it runs once, in a replay it must not run again.
	var game := GAME.new()
	var live := CommandLog.new(game)
	var answer := func(seat: int, _name: StringName, _args: Array) -> void:
		if not live.is_replaying() and seat == 0:
			live.run(1, &"add", [10])
	live.done.connect(answer)
	live.run(0, &"add", [1])
	check(game.total == 11 and live.size() == 2, "live: the answer runs once (%d)" % game.total)
	check(live.history()[1]["seat"] == 1, "and it is in the history after the move that caused it")
	var saved := live.history()
	live.clear()
	game.total = 0
	check(not live.is_replaying(), "not replaying before")
	check(live.replay(saved) == "", "the history replays")
	check(game.total == 11 and live.history() == saved, "same total and history: %d" % game.total)
	check(not live.is_replaying(), "not replaying after")
	live.done.disconnect(answer)  # the listener holds the log: let both go
	game.free()


func test_replay_of_nothing() -> void:
	var game := GAME.new()
	var commands := CommandLog.new(game)
	var heard := [0]
	commands.done.connect(func(_seat: int, _name: StringName, _args: Array) -> void: heard[0] += 1)
	check(commands.replay([]) == "" and heard[0] == 0 and commands.size() == 0, "an empty history: nothing happens")
	game.free()


func test_replay_of_bad_entries() -> void:
	var game := GAME.new()
	var commands := CommandLog.new(game)
	var unknown := CommandLog.UNKNOWN_COMMAND
	var bad := CommandLog.BAD_ARGUMENTS
	check(commands.replay([5]) == unknown, "an entry that is not a Dictionary")
	check(commands.replay([{}]) == unknown, "an entry with no name")
	check(commands.replay([{"name": 5, "seat": 0, "args": []}]) == unknown, "a name that is not a text")
	check(commands.replay([{"name": &"add", "seat": 0, "args": 5}]) == bad, "args that is not an Array")
	check(commands.replay([{"name": &"add", "seat": 0}]) == bad, "no args")
	check(commands.replay([{"name": &"add", "args": [1]}]) == bad, "no seat")
	check(commands.replay([{"name": &"add", "seat": "0", "args": [1]}]) == bad, "a seat that is not an int")
	check(
		game.total == 0 and commands.size() == 0 and not commands.is_replaying(),
		"nothing ran and it is not stuck replaying"
	)
	game.free()


func test_replay_adds_to_the_end() -> void:
	var game := GAME.new()
	var commands := CommandLog.new(game)
	commands.run(0, &"add", [1])
	var saved := commands.history()
	commands.replay(saved)
	check(commands.size() == 2 and game.total == 2, "replay on a history that is not empty adds at the end")
	game.free()


func test_a_command_cannot_run_another() -> void:
	var game := GAME.new()
	var commands := CommandLog.new(game)
	game.log_of_the_game = commands
	check(commands.run(0, &"nested", [&"run"]) == "", "do_nested ran")
	check(
		game.total == 0 and commands.size() == 1,
		"the command it tried to run did not: only do_nested is in the history"
	)
	check(commands.run(0, &"add", [1]) == "" and commands.size() == 2, "and the log works after that")
	commands.run(0, &"nested", [&"undo"])
	check(commands.size() == 3 and game.total == 1, "undo from inside do_ does nothing either")
	commands.run(0, &"nested", [&"replay"])
	check(commands.size() == 4, "nor replay")
	game.log_of_the_game = null
	game.free()


func test_the_history_survives_a_text_round_trip() -> void:
	var game := GAME.new()
	game.rng.seed = 5
	var commands := CommandLog.new(game)
	commands.run(0, &"add", [3])
	commands.run(1, &"pick", [null])
	commands.run(0, &"scale", [0.5])
	commands.run(1, &"any", [Vector2i(2, 3)])
	commands.run(0, &"roll")
	var saved := commands.history()
	var text := var_to_str(saved)
	var loaded: Array = str_to_var(text)
	check(loaded == saved, "var_to_str and str_to_var give the same history back: %s" % text)
	var fresh := GAME.new()
	fresh.rng.seed = 5
	var again := CommandLog.new(fresh)
	check(again.replay(loaded) == "" and fresh.total == game.total, "and it replays")
	check(again.history() == saved, "to the same history")
	game.free()
	fresh.free()
