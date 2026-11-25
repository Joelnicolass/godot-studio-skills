extends "res://addons/command_kit/tests/command_test.gd"

## CommandLog alone, no tree: run and reject, the commands format, undo, replay with a seeded state, make and register.

const ADD := preload("res://addons/command_kit/tests/fixture_add.gd")
const ROLL := preload("res://addons/command_kit/tests/fixture_roll.gd")
const UNTYPED := preload("res://addons/command_kit/tests/fixture_untyped.gd")


func _log() -> CommandLog:
	var commands := CommandLog.new()
	commands.register(ADD)
	commands.register(ROLL)
	return commands


func _add(amount: int, seat := 0) -> GameCommand:
	var command: GameCommand = ADD.new()
	command.set(&"amount", amount)
	command.seat = seat
	return command


func _state(seed_value := 7) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return {"total": 0, "rng": rng}


func test_run_and_reject() -> void:
	var commands := _log()
	var state := _state()
	var heard: Array[String] = []
	commands.executed.connect(func(c: GameCommand) -> void: heard.append("ran %s" % c.type()))
	commands.rejected.connect(func(c: GameCommand, why: StringName) -> void: heard.append("no %s %s" % [c.type(), why]))
	check(commands.run(_add(3), state) == &"", "an accepted command returns empty")
	check(int(state["total"]) == 3, "and ran")
	check(commands.run(_add(0), state) == &"bad_amount", "a rejected command returns its code")
	check(int(state["total"]) == 3 and commands.size() == 1, "and changes nothing, not even the log")
	check(heard == (["ran add", "no add bad_amount"] as Array[String]), "signals: %s" % [heard])
	check(commands.run(null, state) == CommandLog.NO_COMMAND, "no command: an error code")


func test_entry_format() -> void:
	var commands := _log()
	commands.run(_add(2, 1), _state())
	var entry := commands.entries()[0]
	check(entry == {"type": &"add", "seat": 1, "args": {"amount": 2}}, "{type, seat, args}: %s" % [entry])
	entry["args"]["amount"] = 99
	check(commands.entries()[0]["args"]["amount"] == 2, "entries() is a copy")


func test_undo() -> void:
	var commands := _log()
	var state := _state()
	commands.run(_add(2), state)
	commands.run(_add(5), state)
	var undone: Array[int] = []
	commands.undone.connect(func(c: GameCommand) -> void: undone.append(int(c.get(&"amount"))))
	check(commands.can_undo() and commands.undo(state), "undo the last one")
	check(int(state["total"]) == 2 and commands.size() == 1, "it is taken back and leaves the log")
	check(undone == ([5] as Array[int]), "undone signal")
	commands.run(ROLL.new(), state)
	check(not commands.can_undo() and not commands.undo(state), "a roll cannot be undone")
	check(commands.size() == 2, "and stays in the log")
	var empty := _log()
	check(not empty.undo(state), "nothing to undo")


func test_replay_rebuilds_the_same_state() -> void:
	var commands := _log()
	var state := _state(42)
	for i in 5:
		commands.run(_add(i + 1, i % 2), state)
		commands.run(ROLL.new(), state)
	commands.run(_add(0), state)
	var saved := commands.entries()
	var again := _log()
	var fresh := _state(42)
	check(again.replay(saved, fresh) == &"", "the whole log replays")
	check(int(fresh["total"]) == int(state["total"]), "same total: %d and %d" % [fresh["total"], state["total"]])
	check(again.entries() == saved, "the new log equals the old one")


func test_replay_stops_at_a_bad_entry() -> void:
	var commands := _log()
	var state := _state()
	var entries: Array = [{"type": &"add", "seat": 0, "args": {"amount": 2}}, {"type": &"fly", "args": {}}]
	check(commands.replay(entries, state) == CommandLog.UNKNOWN_COMMAND, "an unknown type stops it")
	check(int(state["total"]) == 2 and commands.size() == 1, "the entries before it ran")
	state["locked"] = true
	check(commands.replay([{"type": "add", "args": {"amount": 1}}], state) == &"locked", "a rejection stops it too")


func test_make() -> void:
	var commands := _log()
	var command := commands.make({"type": "add", "seat": 3, "args": {"amount": 4}})
	check(command != null and command.type() == &"add", "String types work")
	check(command.seat == 3 and int(command.get(&"amount")) == 4, "seat and args come back")
	check(commands.make({"type": &"fly"}) == null, "an unknown type makes nothing")


func test_register() -> void:
	var commands := CommandLog.new()
	check(commands.register(ADD), "a GameCommand script registers")
	check(commands.register(ADD), "the same script again is fine")
	check(not commands.register(UNTYPED), "no command_type: refused")
	check(not commands.register(load("res://addons/command_kit/tests/command_test.gd") as Script), "not a GameCommand")
	check(commands.types() == ([&"add"] as Array[StringName]), "types: %s" % [commands.types()])


func test_keep_log_off() -> void:
	var commands := _log()
	commands.keep_log = false
	var state := _state()
	var ran := [0]
	commands.executed.connect(func(_c: GameCommand) -> void: ran[0] += 1)
	commands.run(_add(1), state)
	check(ran[0] == 1 and int(state["total"]) == 1, "it still runs and emits")
	check(commands.size() == 0 and not commands.can_undo(), "but keeps nothing")


func test_replay_with_a_listener_that_answers() -> void:
	# A bot answers every move of seat 0 with a move of its own: live it runs once, in a replay it must not run again.
	var live := _log()
	var target: Array[Dictionary] = [_state()]
	var answer := func(command: GameCommand) -> void:
		if not live.is_replaying() and command.seat == 0:
			live.run(_add(10, 1), target[0])
	live.executed.connect(answer)
	live.run(_add(1, 0), target[0])
	check(int(target[0]["total"]) == 11 and live.size() == 2, "live: the answer runs once (%d)" % target[0]["total"])
	var saved := live.entries()
	live.clear()
	target[0] = _state()
	check(not live.is_replaying(), "not replaying before")
	check(live.replay(saved, target[0]) == &"", "the log replays")
	check(int(target[0]["total"]) == 11 and live.entries() == saved, "same total and log: %d" % target[0]["total"])
	check(not live.is_replaying(), "not replaying after")
	live.executed.disconnect(answer)  # the listener holds the log: let both go


func test_replay_appends() -> void:
	var commands := _log()
	var state := _state()
	commands.run(_add(1), state)
	var saved := commands.entries()
	commands.replay(saved, state)
	check(commands.size() == 2, "replay on a log that is not empty adds at the end")
