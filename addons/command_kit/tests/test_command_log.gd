extends "res://addons/command_kit/tests/command_test.gd"

## CommandLog alone, no tree: run and reject, the argument checks and the game it runs against.

const GAME := preload("res://addons/command_kit/tests/fixture_game.gd")
const CHILD := preload("res://addons/command_kit/tests/fixture_child.gd")
const RULES := preload("res://addons/command_kit/tests/fixture_rules.gd")
const UNTYPED := preload("res://addons/command_kit/tests/fixture_untyped.gd")


func test_run_and_reject() -> void:
	var game := GAME.new()
	var commands := CommandLog.new(game)
	var heard: Array[String] = []
	commands.done.connect(
		func(seat: int, name: StringName, args: Array) -> void: heard.append("done %d %s %s" % [seat, name, args])
	)
	commands.rejected.connect(
		func(seat: int, name: StringName, args: Array, why: String) -> void:
			heard.append("no %d %s %s %s" % [seat, name, args, why])
	)
	check(commands.run(1, &"add", [3]) == "", "an accepted command returns empty")
	check(game.total == 3, "and ran")
	check(commands.run(1, &"add", [0]) == "bad_amount", "a rejected command returns its reason")
	check(game.total == 3 and commands.size() == 1, "and changes nothing, not even the history")
	check(heard == (["done 1 add [3]", "no 1 add [0] bad_amount"] as Array[String]), "signals: %s" % [heard])
	check(game.checked == (["can_run add", "can_add", "can_run add", "can_add"] as Array[String]), "both checks ran")
	game.free()


func test_the_general_check_goes_first() -> void:
	var game := GAME.new()
	var commands := CommandLog.new(game)
	game.only_seat = 0
	check(commands.run(1, &"add", [0]) == "not_your_turn", "can_run answers before can_add")
	check(game.checked == (["can_run add"] as Array[String]), "can_add did not even run: %s" % [game.checked])
	check(commands.run(0, &"add", [0]) == "bad_amount", "when can_run lets it through, can_add decides")
	check(commands.run(0, &"roll") == "", "a command without can_ only goes through the general check")
	game.free()


func test_can_run_changes_nothing() -> void:
	var game := GAME.new()
	var commands := CommandLog.new(game)
	var heard := [0]
	commands.done.connect(func(_seat: int, _name: StringName, _args: Array) -> void: heard[0] += 1)
	commands.rejected.connect(func(_seat: int, _name: StringName, _args: Array, _why: String) -> void: heard[0] += 1)
	check(commands.can_run(0, &"add", [2]) == "", "it can")
	check(commands.can_run(0, &"add", [0]) == "bad_amount", "it cannot, and says why")
	check(commands.can_run(0, &"nothing") == CommandLog.UNKNOWN_COMMAND, "an unknown one")
	check(game.total == 0 and commands.size() == 0 and heard[0] == 0, "no change, no history, no signal")
	game.free()


func test_unknown_commands() -> void:
	var game := GAME.new()
	var commands := CommandLog.new(game)
	var heard: Array[String] = []
	commands.rejected.connect(func(_seat: int, _name: StringName, _args: Array, why: String) -> void: heard.append(why))
	# A native method, one that exists in the script without do_, a check, an undo, nothing at all.
	for name: StringName in [
		&"free", &"queue_free", &"set", &"call", &"helper_total", &"can_add", &"undo_add", &"", &"run"
	]:
		check(commands.run(0, name, []) == CommandLog.UNKNOWN_COMMAND, "%s is not a command" % name)
	check(is_instance_valid(game) and game.total == 0, "nothing ran")
	check(heard.size() == 9 and heard.count(CommandLog.UNKNOWN_COMMAND) == 9, "rejected says unknown_command each time")
	check(not commands._warned_gone, "a live game is never reported as gone")
	var nobody := CommandLog.new()
	check(nobody.run(0, &"add", [1]) == CommandLog.UNKNOWN_COMMAND, "no game: unknown_command, no error")
	check(nobody.commands().is_empty() and not nobody.has_command(&"add"), "and no commands")
	game.free()


func test_a_freed_game_is_unknown() -> void:
	var game := GAME.new()
	var commands := CommandLog.new(game)
	check(commands.has_command(&"add"), "it knows the game's commands")
	game.free()
	check(commands.game == null, "the log does not keep the game alive")
	check(commands.run(0, &"add", [1]) == CommandLog.UNKNOWN_COMMAND, "a freed game: unknown_command")


func test_the_arguments_are_checked() -> void:
	var game := GAME.new()
	var commands := CommandLog.new(game)
	var bad := CommandLog.BAD_ARGUMENTS
	check(commands.run(0, &"add", [1, 2]) == bad, "one too many")
	check(commands.run(0, &"add") == bad, "one too few")
	check(commands.run(0, &"add", ["3"]) == bad, "wrong type")
	check(commands.run(0, &"add", [1.5]) == bad, "a float is not an int")
	check(commands.run(0, &"add", [null]) == bad, "null is not an int")
	check(commands.run(0, &"roll", [1]) == bad, "a command with no arguments gets none")
	check(game.total == 0 and commands.size() == 0, "nothing ran, nothing kept")
	check(commands.can_run(0, &"add", ["x"]) == bad, "can_run checks them too")
	check(game.checked.is_empty(), "the game's checks never saw a bad call: %s" % [game.checked])
	game.free()


func test_the_seat_is_checked_too() -> void:
	var game := GAME.new()
	var commands := CommandLog.new(game)
	check(commands.run(0, &"label", [&"a"]) == "", "a seat of 0 is fine")
	check(commands.run(-1, &"label", [&"a"]) == "", "so is -1: the kit does not know your seats")
	game.free()


func test_the_argument_types_that_are_accepted() -> void:
	var game := GAME.new()
	var commands := CommandLog.new(game)
	check(
		commands.run(0, &"scale", [3]) == "" and is_equal_approx(game.last_factor, 3.0),
		"an int goes where a float is asked"
	)
	check(commands.run(0, &"scale", [0.5]) == "", "a float too")
	check(commands.run(0, &"scale", ["1"]) == CommandLog.BAD_ARGUMENTS, "a text does not")
	check(
		commands.run(0, &"label", ["abc"]) == "" and game.last_label == &"abcx",
		"a String goes where a StringName is asked"
	)
	check(
		commands.run(0, &"shout", [&"hey"]) == "" and game.last_label == &"HEY", "a StringName where a String is asked"
	)
	check(commands.run(0, &"label", [5]) == CommandLog.BAD_ARGUMENTS, "a number is neither")
	check(
		commands.run(0, &"label", [&"a", &"b"]) == "" and game.last_label == &"ab",
		"an argument that has a default can be given"
	)
	check(commands.run(0, &"defaults", [1]) == "" and game.total == 6, "or left out: the default counts")
	check(commands.run(0, &"defaults", [1, 2]) == "" and game.total == 9, "or given")
	check(commands.run(0, &"defaults") == CommandLog.BAD_ARGUMENTS, "but the others are needed")
	check(commands.run(0, &"defaults", [1, 2, 3]) == CommandLog.BAD_ARGUMENTS, "and no more than the function has")
	var node := Node.new()
	check(commands.run(0, &"pick", [node]) == "" and commands.run(0, &"pick", [null]) == "", "an object, or null")
	check(commands.run(0, &"pick", [3]) == CommandLog.BAD_ARGUMENTS, "a number is not an object")
	check(commands.run(0, &"any", [Vector2i(1, 2)]) == "", "an untyped parameter takes anything")
	check(commands.run(0, &"any", [null]) == "", "even null")
	check(
		commands.run(0, &"many", [1, "two", Vector2.ONE]) == "" and game.last_rest.size() == 3,
		"and ...rest takes any number"
	)
	node.free()
	game.free()


func test_changing_the_game() -> void:
	var first := GAME.new()
	var commands := CommandLog.new(first)
	commands.run(0, &"add", [1])
	var second := CHILD.new()
	commands.game = second
	check(commands.has_command(&"extra"), "it reads the commands of the new game")
	check(commands.size() == 1, "the history stays")
	check(commands.run(0, &"extra") == "" and second.total == 100, "it runs against the new game")
	var rules := RULES.new()
	commands.game = rules
	check(commands.commands() == ([&"score"] as Array[StringName]), "and a game of another kind")
	first.free()
	second.free()


func test_commands_are_the_do_functions_sorted() -> void:
	var game := CHILD.new()
	var commands := CommandLog.new(game)
	var names := commands.commands()
	var expected: Array[StringName] = [
		&"add",
		&"any",
		&"defaults",
		&"extra",
		&"label",
		&"many",
		&"nested",
		&"nodes",
		&"path",
		&"pick",
		&"push",
		&"roll",
		&"scale",
		&"shout",
		&"take",
		&"weights"
	]
	check(names == expected, "do_ functions, base script included, sorted: %s" % [names])
	check(
		(
			commands.has_command(&"add")
			and not commands.has_command(&"can_add")
			and not commands.has_command(&"helper_total")
		),
		"has_command"
	)
	game.free()


func test_rules_that_are_not_a_node() -> void:
	var rules := RULES.new()
	check(rules.commands.run(0, &"score", [3]) == "" and rules.points == 3, "a RefCounted game runs its commands")
	check(rules.commands.undo() and rules.points == 0, "and undoes them")
	check(rules.commands.game == rules, "the log knows its game, without keeping it alive")


func test_typed_collections() -> void:
	var game := GAME.new()
	var commands := CommandLog.new(game)
	var bad := CommandLog.BAD_ARGUMENTS
	var path: Array = [Vector2i(1, 1), Vector2i(2, 2)]
	check(
		commands.run(0, &"path", [path]) == "" and game.last_cells.size() == 2,
		"a plain Array goes into an Array[Vector2i]"
	)
	var typed: Array[Vector2i] = [Vector2i.ONE]
	check(commands.run(0, &"path", [typed]) == "" and game.last_cells == typed, "a typed one too")
	check(commands.run(0, &"path", [[]]) == "" and game.last_cells.is_empty(), "an empty one")
	check(commands.run(0, &"path", [[Vector2i.ONE, "x"]]) == bad, "an item of another type")
	check(commands.run(0, &"path", [[1, 2]]) == bad, "all of them of another type")
	var ints: Array[int] = [1]
	check(commands.run(0, &"path", [ints]) == bad, "an Array[int] is not an Array[Vector2i]")
	check(commands.run(0, &"path", [5]) == bad, "and a number is no array")
	var weights := {&"a": 1, &"b": 2.5}
	check(
		commands.run(0, &"weights", [weights]) == "" and is_equal_approx(game.last_weights[&"a"], 1.0),
		"a plain Dictionary"
	)
	check(commands.run(0, &"weights", [{"a": 1.0}]) == bad, "a key of another type")
	check(commands.run(0, &"weights", [{&"a": "x"}]) == bad, "a value of another type")
	var node := Node.new()
	check(commands.run(0, &"nodes", [[node]]) == bad, "a plain Array of objects needs to be typed")
	var nodes: Array[Node] = [node]
	check(commands.run(0, &"nodes", [nodes]) == "" and game.total == 1, "an Array[Node] goes in")
	check(commands.undo() == false, "no undo_ for it")
	var saved := commands.history()
	var fresh := GAME.new()
	var again := CommandLog.new(fresh)
	check(again.replay(saved.slice(0, 4)) == "" and fresh.last_weights.size() == 2, "a history with them replays")
	node.free()
	game.free()
	fresh.free()


func test_a_can_function_that_does_not_return_text() -> void:
	var game := UNTYPED.new()
	var commands := CommandLog.new(game)
	game.answer = "why"
	check(commands.run(0, &"flag") == "why" and game.ran == 0, "a text is the reason")
	game.answer = &"sn"
	check(commands.run(0, &"flag") == "sn", "so is a StringName")
	game.answer = true
	check(commands.run(0, &"flag") == "" and game.ran == 1, "true lets it run")
	game.answer = null
	check(commands.run(0, &"flag") == "" and game.ran == 2, "so does nothing at all")
	game.answer = false
	check(commands.run(0, &"flag") == CommandLog.NOT_ALLOWED and game.ran == 2, "false rejects with not_allowed")
	game.answer = 5
	check(commands.run(0, &"flag") == CommandLog.NOT_ALLOWED and game.ran == 2, "anything else rejects too")
	check(commands.size() == 2, "only the two that ran are in the history")
	game.free()


func test_a_game_that_is_gone_says_so_once() -> void:
	var commands := CommandLog.new(RULES.new())
	check(commands.run(0, &"score", [1]) == CommandLog.UNKNOWN_COMMAND, "the rules were freed: unknown_command")
	check(commands.can_run(0, &"score", [1]) == CommandLog.UNKNOWN_COMMAND, "still")
	check(commands._warned_gone, "and it said why, once")
	var nobody := CommandLog.new()
	nobody.run(0, &"x")
	check(not nobody._warned_gone, "no game ever assigned: no error")
