extends "res://addons/command_kit/tests/command_test.gd"

## CommandBus in a tree: commands from the inspector, context, signals, use_log and warnings.

const ADD := preload("res://addons/command_kit/tests/fixture_add.gd")
const ROLL := preload("res://addons/command_kit/tests/fixture_roll.gd")
const UNTYPED := preload("res://addons/command_kit/tests/fixture_untyped.gd")


func _bus() -> CommandBus:
	var bus := CommandBus.new()
	bus.commands = [ADD, ROLL] as Array[Script]
	tree.root.add_child(bus)
	return bus


func _add(amount: int) -> GameCommand:
	var command: GameCommand = ADD.new()
	command.set(&"amount", amount)
	return command


func test_commands_from_inspector() -> void:
	var bus := _bus()
	check(bus.command_log.types() == ([&"add", &"roll"] as Array[StringName]), "one type per script")
	check(bus.make({"type": "add", "args": {"amount": 2}}) != null, "it builds them from entries")
	check(bus._get_configuration_warnings().is_empty(), "no warnings")
	bus.free()


func test_context() -> void:
	var bus := _bus()
	var state := {"total": 0}
	bus.context = state
	check(bus.run(_add(3)) == &"" and int(state["total"]) == 3, "run() with no ctx uses context")
	var other := {"total": 10}
	bus.run(_add(1), other)
	check(int(other["total"]) == 11 and int(state["total"]) == 3, "a ctx given wins")
	check(bus.undo() and int(state["total"]) == 2, "undo uses context too (it took back the 1)")
	bus.free()


func test_signals() -> void:
	var bus := _bus()
	bus.context = {"total": 0}
	var heard: Array[String] = []
	bus.executed.connect(func(c: GameCommand) -> void: heard.append("ran %s" % c.type()))
	bus.rejected.connect(func(_c: GameCommand, why: StringName) -> void: heard.append("no %s" % why))
	bus.undone.connect(func(_c: GameCommand) -> void: heard.append("undone"))
	bus.run(_add(1))
	bus.run(_add(0))
	bus.undo()
	check(heard == (["ran add", "no bad_amount", "undone"] as Array[String]), "the bus relays the log: %s" % [heard])
	bus.free()


func test_replay_through_the_bus() -> void:
	var bus := _bus()
	var state := {"total": 0}
	bus.context = state
	for i in 4:
		bus.run(_add(i + 1))
	var saved := bus.entries()
	bus.clear()
	state["total"] = 0
	check(bus.replay(saved) == &"" and int(state["total"]) == 10, "replay rebuilds the total")
	check(bus.entries() == saved and bus.size() == 4, "and the log")
	bus.free()


func test_keep_log_and_use_log() -> void:
	var bus := _bus()
	bus.keep_log = false
	bus.run(_add(1), {"total": 0})
	check(bus.size() == 0, "keep_log off reaches the own log")
	var rules := CommandLog.new()
	rules.register(ADD)
	var count := [0]
	bus.rebuilt.connect(func() -> void: count[0] += 1)
	bus.use_log(rules)
	check(count[0] == 1, "use_log emits rebuilt")
	var heard := [0]
	bus.executed.connect(func(_c: GameCommand) -> void: heard[0] += 1)
	rules.run(_add(1), {"total": 0})
	check(heard[0] == 1 and bus.size() == 1, "the bus shows the rules' log")
	bus.commands = [] as Array[Script]
	check(rules.has_type(&"add"), "the inspector does not touch a log it does not own")
	bus.use_own_log()
	rules.run(_add(1), {"total": 0})
	check(count[0] == 2 and heard[0] == 1, "back to its own log: the old one is not heard")
	bus.free()


func test_warnings() -> void:
	var bus := CommandBus.new()
	bus.commands = [ADD, null, UNTYPED, ADD, load("res://addons/command_kit/tests/command_test.gd")] as Array[Script]
	var warnings := bus._get_configuration_warnings()
	check(warnings.size() == 4, "empty slot, no type, same type twice, not a command: %s" % [warnings])
	check(bus.command_log.types() == ([&"add"] as Array[StringName]), "the good script still registers")
	bus.free()
