extends "res://addons/command_kit/tests/command_test.gd"

## GameCommands in a tree: the game it finds, signals, use_log and the editor's warnings.

const GAME := preload("res://addons/command_kit/tests/fixture_game.gd")
const RULES := preload("res://addons/command_kit/tests/fixture_rules.gd")
const TYPOS := preload("res://addons/command_kit/tests/fixture_typos.gd")
const EMPTY := preload("res://addons/command_kit/tests/fixture_empty.gd")


## A game node with a GameCommands child.
func _scene() -> Array:
	var game := GAME.new() as Node
	var commands := GameCommands.new()
	game.add_child(commands)
	tree.root.add_child(game)
	return [game, commands]


func test_the_parent_is_the_game() -> void:
	var scene := _scene()
	var game: Node = scene[0]
	var commands: GameCommands = scene[1]
	check(commands.run(0, &"add", [3]) == "" and game.total == 3, "with no game set it runs the parent's commands")
	check(commands.has_command(&"add") and commands.commands().has(&"take"), "it lists them")
	check(
		commands.size() == 1 and commands.history() == [{"name": &"add", "seat": 0, "args": [3]}],
		"and keeps the history"
	)
	check(commands.can_run(0, &"add", [0]) == "bad_amount", "can_run says why not")
	check(commands.can_undo() and commands.undo() and game.total == 0, "undo")
	check(commands.owns_log() and commands.command_log.game == game, "its own log, pointing at the parent")
	game.free()


func test_game_set_in_the_inspector() -> void:
	var holder := Node.new()
	var other := GAME.new() as Node
	var commands := GameCommands.new()
	holder.add_child(other)
	holder.add_child(commands)
	commands.game = other
	tree.root.add_child(holder)
	check(commands.run(0, &"add", [2]) == "" and other.total == 2, "game points at another node")
	check(commands.command_log.game == other, "the log follows it")
	var third := GAME.new() as Node
	holder.add_child(third)
	commands.game = third
	check(
		commands.size() == 1 and commands.run(0, &"add", [1]) == "" and third.total == 1,
		"changing it keeps the history"
	)
	check(commands.size() == 2, "and goes on in it")
	holder.free()


func test_signals_are_forwarded() -> void:
	var scene := _scene()
	var commands: GameCommands = scene[1]
	var heard: Array[String] = []
	commands.done.connect(
		func(seat: int, name: StringName, args: Array) -> void: heard.append("done %d %s %s" % [seat, name, args])
	)
	commands.rejected.connect(
		func(seat: int, name: StringName, args: Array, why: String) -> void:
			heard.append("no %d %s %s %s" % [seat, name, args, why])
	)
	commands.undone.connect(
		func(seat: int, name: StringName, args: Array) -> void: heard.append("undone %d %s %s" % [seat, name, args])
	)
	commands.run(1, &"add", [1])
	commands.run(1, &"add", [0])
	commands.undo()
	var expected: Array[String] = ["done 1 add [1]", "no 1 add [0] bad_amount", "undone 1 add [1]"]
	check(heard == expected, "the node relays the log: %s" % [heard])
	(scene[0] as Node).free()


func test_replay_and_clear_through_the_node() -> void:
	var scene := _scene()
	var game: Node = scene[0]
	var commands: GameCommands = scene[1]
	game.rng.seed = 9
	for i in 3:
		commands.run(0, &"add", [i + 1])
		commands.run(0, &"roll")
	var saved := commands.history()
	var total: int = game.total
	commands.clear()
	game.total = 0
	game.rng.seed = 9
	check(commands.size() == 0 and commands.replay(saved) == "" and game.total == total, "replay rebuilds the total")
	check(commands.history() == saved and not commands.is_replaying(), "and the history")
	game.free()


func test_keep_history_and_use_log() -> void:
	var scene := _scene()
	var game: Node = scene[0]
	var commands: GameCommands = scene[1]
	commands.keep_history = false
	commands.run(0, &"add", [1])
	check(commands.size() == 0, "keep_history off reaches the own log")
	var rules := RULES.new()
	var count := [0]
	commands.rebuilt.connect(func() -> void: count[0] += 1)
	commands.use_log(rules.commands)
	check(count[0] == 1 and not commands.owns_log(), "use_log emits rebuilt")
	var heard := [0]
	commands.done.connect(func(_seat: int, _name: StringName, _args: Array) -> void: heard[0] += 1)
	check(commands.run(0, &"score", [4]) == "" and rules.points == 4, "the node runs the rules' commands")
	check(heard[0] == 1 and commands.size() == 1, "and shows their history")
	rules.commands.run(0, &"score", [1])
	check(heard[0] == 2 and commands.size() == 2, "what the rules run on their own is heard too")
	rules.commands.keep_history = false
	commands.keep_history = true
	check(not rules.commands.keep_history, "the inspector does not touch a log it does not own")
	commands.use_own_log()
	rules.commands.run(0, &"score", [1])
	check(count[0] == 2 and heard[0] == 2 and commands.owns_log(), "back to its own log: the old one is not heard")
	check(commands.size() == 0 and commands.command_log.game == game, "empty, on the parent again")
	game.free()


func test_the_log_is_built_when_it_is_used() -> void:
	var commands := GameCommands.new()
	var game := GAME.new() as Node
	check(commands.command_log != null and commands.commands().is_empty(), "alone it has a log and no commands")
	game.add_child(commands)
	check(commands.has_command(&"add"), "it reads the parent once it has one")
	game.free()


func test_warnings() -> void:
	var alone := GameCommands.new()
	check(
		alone._get_configuration_warnings().size() == 1,
		"no parent and no game: %s" % [alone._get_configuration_warnings()]
	)
	alone.free()
	var scene := _scene()
	check((scene[1] as GameCommands)._get_configuration_warnings().is_empty(), "a good game: no warnings")
	(scene[0] as Node).free()
	var bare := Node.new()
	var bare_commands := GameCommands.new()
	bare.add_child(bare_commands)
	check(bare_commands._get_configuration_warnings().size() == 1, "a parent with no script")
	bare.free()
	var empty := EMPTY.new() as Node
	var empty_commands := GameCommands.new()
	empty.add_child(empty_commands)
	var warnings := empty_commands._get_configuration_warnings()
	check(warnings.size() == 1 and warnings[0].contains("no do_"), "no do_ function: %s" % [warnings])
	empty.free()
	var typos := TYPOS.new() as Node
	var typo_commands := GameCommands.new()
	typos.add_child(typo_commands)
	var text := "\n".join(typo_commands._get_configuration_warnings())
	check(text.contains("do_move has no parameters"), "do_ with no seat: %s" % text)
	check(
		text.contains("can_mvoe has no do_mvoe") and text.contains("undo_mvoe has no do_mvoe"),
		"typos in can_ and undo_"
	)
	check(text.contains("can_jump takes 1 parameters and do_jump 2"), "can_ that does not match")
	check(text.contains("can_jump must return a String"), "can_ that returns a bool")
	check(text.contains("undo_jump takes 4 parameters"), "undo_ that does not match")
	typos.free()


func test_found_commands() -> void:
	var scene := _scene()
	var game: Node = scene[0]
	var commands: GameCommands = scene[1]
	var found: String = commands.get(&"found_commands")
	check(found.begins_with("add (can, undo), any, defaults,"), "the inspector lists what it found: %s" % found)
	check(found.contains("take (undo)") and found.contains("roll,"), "undo and no checks: %s" % found)
	var listed := false
	for info in commands.get_property_list():
		if info["name"] == "found_commands":
			listed = true
			check(int(info["usage"]) & PROPERTY_USAGE_STORAGE == 0, "it is not stored in the scene")
			check(int(info["usage"]) & PROPERTY_USAGE_READ_ONLY != 0, "and it is read only")
	check(listed, "found_commands is a property")
	var other := EMPTY.new() as Node
	game.add_child(other)
	commands.game = other
	check(commands.get(&"found_commands") == "(none)", "it follows game: %s" % commands.get(&"found_commands"))
	game.free()
