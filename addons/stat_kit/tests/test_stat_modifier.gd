extends "res://addons/stat_kit/tests/stat_test.gd"

## StatModifier alone: defaults, the shortcuts, describe (with another source too), changed and to_dict.


func test_defaults_and_init() -> void:
	var empty := StatModifier.new()
	check(empty.stat == &"" and empty.op == StatModifier.Op.ADD, "the editor can create one empty")
	check(empty.amount == 0.0 and empty.source == &"", "amount 0, no source")
	var mod := StatModifier.new(&"food", StatModifier.Op.MUL, 2.0, &"granary")
	check(mod.stat == &"food" and mod.op == StatModifier.Op.MUL, "_init sets stat and op")
	check(mod.amount == 2.0 and mod.source == &"granary", "and amount and source")


func test_shortcuts() -> void:
	var sword := StatModifier.plus(&"attack", 2, &"sword")
	check(sword.op == StatModifier.Op.ADD and sword.amount == 2.0 and sword.source == &"sword", "plus")
	var granary := StatModifier.times(&"food", 1.5, &"granary")
	check(granary.op == StatModifier.Op.MUL and granary.amount == 1.5 and granary.stat == &"food", "times")
	var swamp := StatModifier.fixed(&"moves", 1)
	check(swamp.op == StatModifier.Op.SET and swamp.amount == 1.0 and swamp.source == &"", "fixed, no source")
	var ring := StatModifier.percent(&"attack", 0.1, &"ring")
	check(ring.op == StatModifier.Op.PERCENT and ring.amount == 0.1 and ring.source == &"ring", "percent")
	check(StatModifier.Op.PERCENT == 3, "PERCENT comes last, so files saved with the other three keep their op")


func test_describe() -> void:
	check(StatModifier.plus(&"attack", 2, &"sword").describe() == "+2 attack (sword)", "an ADD")
	check(StatModifier.times(&"food", 1.5, &"granary").describe() == "×1.5 food (granary)", "a MUL")
	check(StatModifier.fixed(&"moves", 1, &"swamp").describe() == "= 1 moves (swamp)", "a SET")
	check(StatModifier.plus(&"attack", -1, &"curse").describe() == "-1 attack (curse)", "a penalty")
	check(StatModifier.plus(&"luck", 0.25).describe() == "+0.25 luck", "no source, no brackets")
	check(StatModifier.percent(&"attack", 0.1, &"ring").describe() == "+10 % attack (ring)", "a PERCENT")
	check(StatModifier.percent(&"speed", -0.125).describe() == "-12.5 % speed", "a percent penalty")
	var ring := StatModifier.percent(&"attack", 0.5, &"ring")
	check(ring.describe(&"left_ring") == "+50 % attack (left_ring)", "describe names the source it was added with")
	check(StatModifier.plus(&"attack", 1).describe(&"potion") == "+1 attack (potion)", "even when it has none")
	var long := StatModifier.times(&"speed", 1.0 / 3.0).describe()
	check(long == "×0.333 speed", "at most 3 decimals: %s" % long)


func test_changed() -> void:
	var mod := StatModifier.plus(&"attack", 2)
	var heard := [0]
	mod.changed.connect(func() -> void: heard[0] += 1)
	mod.amount = 3
	mod.op = StatModifier.Op.MUL
	mod.stat = &"defense"
	mod.source = &"ring"
	check(heard[0] == 4, "each value emits changed: %d" % heard[0])


func test_to_dict_round_trip() -> void:
	var mod := StatModifier.times(&"food", 1.5, &"granary")
	var data := mod.to_dict()
	check(data == {"stat": "food", "op": "mul", "amount": 1.5, "source": "granary"}, "plain data: %s" % [data])
	var copy := StatModifier.from_dict(data)
	check(copy.to_dict() == data and copy != mod, "a new modifier with the same values")
	var through_json: Variant = JSON.parse_string(JSON.stringify(data))
	var parsed: Dictionary = through_json
	check(StatModifier.from_dict(parsed).to_dict() == data, "it survives JSON")
	var by_number := StatModifier.from_dict({"stat": "moves", "op": 2.0, "amount": 1})
	check(by_number.op == StatModifier.Op.SET and by_number.amount == 1.0, "op as a number, from JSON")
	var upper := StatModifier.from_dict({"stat": "attack", "op": "ADD", "amount": 2})
	check(upper.op == StatModifier.Op.ADD and upper.source == &"", "op in capitals, no source")
	var ring := StatModifier.percent(&"attack", 0.1, &"ring")
	check(ring.to_dict()["op"] == "percent", "PERCENT is saved by name")
	check(StatModifier.from_dict(ring.to_dict()).op == StatModifier.Op.PERCENT, "and read back")
	check(StatModifier.from_dict({"stat": "attack", "op": 3.0}).op == StatModifier.Op.PERCENT, "or by number")


func test_from_dict_unknown_op() -> void:
	check(StatModifier.from_dict({"stat": "attack", "op": "pow"}) == null, "an unknown op name is null")
	check(StatModifier.from_dict({"stat": "attack", "op": 7}) == null, "and so is a number out of range")
