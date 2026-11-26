extends "res://addons/dice_kit/tests/dice_test.gd"

## DiceRoll alone: reading it (tags counted on every face, the highest and lowest), rolling some dice again, mixed dice,
## the same seed giving the same roll (also against fixed lists, so an engine change that alters the sequence shows
## up), one draw per die, to_dict through JSON, that a roll cannot be changed, and the errors.

# d6, seed 12345, 10 dice. If this fails after a Godot update, the engine's RandomNumberGenerator changed its sequence:
# saved seeds and replays of older versions no longer give the same rolls.
const D6_SEED_12345: Array[int] = [3, 2, 4, 5, 1, 4, 6, 1, 5, 2]
const D20_SEED_2026: Array[int] = [20, 19, 5, 12, 15, 5, 5, 10]
# d6, seed 12345: 5 dice, then slots 4 and 1 rolled again from the same rng (slot 1 first).
const D6_REROLLED_12345: Array[int] = [3, 4, 4, 5, 6]


func test_reads() -> void:
	var die := _attack_die()
	var roll := DiceRoll.from_indices([die, die, die, die] as Array[DieData], [0, 3, 5, 0])
	check(roll.size() == 4, "four dice")
	check(roll.sum() == 1 + 0 + 2 + 1, "sum adds the values: %d" % roll.sum())
	check(roll.count(&"hit") == 2 and roll.count(&"crit") == 1 and roll.count(&"miss") == 0, "count by tag")
	check(roll.has(&"blank") and not roll.has(&"miss"), "has")
	check(roll.values() == ([1, 0, 2, 1] as Array[int]), "values in order: %s" % [roll.values()])
	check(roll.indices == ([0, 3, 5, 0] as Array[int]), "indices in order")
	check(roll.faces[2] == die.faces[5] and roll.dice[1] == die, "faces and dice")
	var empty := DiceRoll.new()
	check(empty.size() == 0 and empty.sum() == 0 and empty.count(&"hit") == 0, "an empty roll reads as nothing")
	check(roll.slots_with(&"hit") == ([0, 3] as Array[int]), "slots_with: %s" % [roll.slots_with(&"hit")])


func test_several_tags_on_a_face() -> void:
	var double := DieFace.new(0)
	double.tags = [&"hit", &"hit", &"shield"] as Array[StringName]
	var die := DieData.new()
	die.faces = [double, DieFace.new(0, &"hit"), DieFace.new(0)] as Array[DieFace]
	var roll := _from([die, die, die], [0, 1, 2])
	check(roll.count(&"hit") == 3 and roll.count(&"shield") == 1, "every appearance counts: 2 + 1 hits, 1 shield")
	check(roll.has(&"shield") and not roll.has(&"crit"), "has")
	check(roll.slots_with(&"shield") == ([0] as Array[int]), "slots_with finds the face that has it")
	check(roll.describe() == "3 hit · 1 shield", "describe counts them too: %s" % roll.describe())


func test_read_only() -> void:
	var d6 := DieData.numbered(6)
	var roll := _from([d6, d6], [0, 5])
	roll.indices.append(3)
	roll.faces.clear()
	roll.dice.append(d6)
	check(roll.size() == 2 and roll.indices == ([0, 5] as Array[int]), "what reads it gets copies")
	roll.indices = [1, 1] as Array[int]
	check(roll.values() == ([1, 6] as Array[int]) and roll.sum() == 7, "assigning is an error and changes nothing")


func test_highest_and_lowest() -> void:
	var d6 := DieData.numbered(6)
	var roll := _from([d6, d6, d6, d6], [3, 5, 0, 5])
	check(roll.highest() == ([1] as Array[int]), "the slot of the highest; a tie keeps the earlier slot")
	check(roll.highest(3) == ([1, 3, 0] as Array[int]), "the 3 highest, highest first: %s" % [roll.highest(3)])
	check(roll.highest_values(2) == ([6, 6] as Array[int]), "and their values")
	check(roll.lowest(2) == ([2, 0] as Array[int]), "the 2 lowest, lowest first: %s" % [roll.lowest(2)])
	check(roll.lowest_values() == ([1] as Array[int]), "the lowest value")
	check(roll.sum() - roll.lowest_values()[0] == 16, "drop the lowest")
	check(roll.highest(9).size() == 4 and roll.lowest(0).is_empty(), "more than it has: all; 0: none")
	check(DiceRoll.new().highest().is_empty(), "an empty roll: none")


func test_rerolled() -> void:
	var d6 := DieData.numbered(6)
	var shared := _rng(12345)
	var roll := d6.roll(5, shared)
	var again := roll.rerolled([4, 1, 4] as Array[int], shared)
	check(again.size() == 5 and roll.values() == D6_SEED_12345.slice(0, 5), "the first roll does not change")
	var kept := true
	for slot: int in [0, 2, 3]:
		kept = kept and again.indices[slot] == roll.indices[slot]
	check(kept, "the slots not named keep their faces")
	var plain := _rng(12345)
	for slot in 5:
		plain.randi_range(0, 5)
	var first := plain.randi_range(0, 5)
	var second := plain.randi_range(0, 5)
	check(again.indices[1] == first and again.indices[4] == second, "one draw per die, in slot order, a slot once")
	check(again.values() == D6_REROLLED_12345, "the fixed list: %s (got %s)" % [D6_REROLLED_12345, again.values()])
	var blanks := _attack_die().roll(6, _rng(3))
	var no_blank := blanks.rerolled(blanks.slots_with(&"blank"), _rng(4))
	check(no_blank.size() == 6 and no_blank.dice == blanks.dice, "the blanks rolled again in one line")
	var state := shared.state
	check(roll.rerolled([5] as Array[int], shared).size() == 0, "a slot out of range: an empty roll")
	check(roll.rerolled([0] as Array[int], null).size() == 0, "no rng: an empty roll")
	check(shared.state == state, "and nothing drawn")
	check(roll.rerolled([] as Array[int], shared).indices == roll.indices, "no slots: the same roll")


func test_describe() -> void:
	var d6 := DieData.numbered(6)
	var attack := _attack_die()
	check(_from([d6, d6], [2, 4]).describe() == "3 + 5 = 8", "numbers: %s" % _from([d6, d6], [2, 4]).describe())
	check(_from([d6], [3]).describe() == "4", "one die: its value")
	var mixed := _from([attack, attack, attack], [0, 3, 5]).describe()
	check(mixed == "1 + 0 + 2 = 3 · 1 blank · 1 crit · 1 hit", "values, then tags in order: %s" % mixed)
	var symbols := DieData.new()
	symbols.faces = [DieFace.new(0, &"hit"), DieFace.new(0, &"shield")] as Array[DieFace]
	check(_from([symbols, symbols], [0, 0]).describe() == "2 hit", "faces worth 0: only the tags")
	check(DiceRoll.new().describe() == "", "an empty roll: empty")


func test_of_mixed_dice() -> void:
	var d6 := DieData.numbered(6)
	var d8 := DieData.numbered(8)
	var roll := DiceRoll.of([d6, d6, d8], _rng(3))
	check(roll.size() == 3 and roll.dice == ([d6, d6, d8] as Array[DieData]), "one die of each, in order")
	check(roll.values()[2] >= 1 and roll.values()[2] <= 8, "the d8 shows a d8 face")


func test_same_seed_same_roll() -> void:
	var pool: Array[DieData] = [DieData.numbered(6), DieData.numbered(20), _attack_die(), DieData.numbered(6)]
	var all_same := true
	var rolls: Array[Array] = []
	for seed_value: int in [1, 42, 2026, 99999, -7]:
		var first := DiceRoll.of(pool, _rng(seed_value))
		var again := DiceRoll.of(pool, _rng(seed_value))
		all_same = all_same and first.indices == again.indices
		rolls.append(first.indices)
	check(all_same, "every seed gives the same roll twice")
	var differ := false
	for index in range(1, rolls.size()):
		differ = differ or rolls[index] != rolls[0]
	check(differ, "different seeds give different rolls: %s" % [rolls])


func test_fixed_sequence() -> void:
	var values := DieData.numbered(6).roll(10, _rng(12345)).values()
	check(values == D6_SEED_12345, "d6 with seed 12345 gives %s (got %s)" % [D6_SEED_12345, values])
	var d20 := load("res://addons/dice_kit/dice/d20.tres") as DieData
	values = d20.roll(8, _rng(2026)).values()
	check(values == D20_SEED_2026, "the ready d20 with seed 2026 gives %s (got %s)" % [D20_SEED_2026, values])


func test_one_draw_per_die() -> void:
	var pool: Array[DieData] = [DieData.numbered(6), DieData.numbered(8), DieData.numbered(20)]
	var roll := DiceRoll.of(pool, _rng(77))
	var plain := _rng(77)
	var expected: Array[int] = []
	for die in pool:
		expected.append(plain.randi_range(0, die.sides() - 1))
	check(roll.indices == expected, "each die is one randi_range(0, sides - 1), in order: %s" % [roll.indices])


func test_rolls_follow_the_rng() -> void:
	var d6 := DieData.numbered(6)
	var shared := _rng(9)
	var parts := d6.roll(3, shared).indices + d6.roll(2, shared).indices
	check(parts == d6.roll(5, _rng(9)).indices, "two rolls from one rng continue its sequence")


func test_to_dict_through_json() -> void:
	var pool: Array[DieData] = [DieData.numbered(6), _attack_die(), DieData.numbered(12)]
	var roll := DiceRoll.of(pool, _rng(31))
	var data := roll.to_dict()
	check(data.keys() == ["indices"], "only the indices: %s" % [data])
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(data))
	var back := DiceRoll.from_dict(pool, parsed)
	check(back.indices == roll.indices and back.faces == roll.faces, "the same roll after JSON (floats come back)")
	check(back.sum() == roll.sum() and back.dice == pool, "it reads the same")
	var logged := DiceRoll.from_indices(pool, roll.indices)
	check(logged.indices == roll.indices and logged.describe() == roll.describe(), "from_indices from a log of ints")


func test_errors() -> void:
	var d6 := DieData.numbered(6)
	var rng := _rng(1)
	check(DiceRoll.of([], rng).size() == 0, "an empty pool: an empty roll")
	check(DiceRoll.of([d6, null], rng).size() == 0, "a null die: an empty roll")
	check(DiceRoll.of([d6, DieData.new()], rng).size() == 0, "a die without faces: an empty roll")
	check(DiceRoll.of([d6], null).size() == 0, "no rng: an empty roll")
	check(DiceRoll.from_indices([d6, d6], [1]).size() == 0, "fewer indices than dice")
	check(
		DiceRoll.from_indices([d6], [6]).size() == 0 and DiceRoll.from_indices([d6], [-1]).size() == 0, "out of range"
	)
	check(DiceRoll.from_indices([d6], ["2"]).size() == 0, "an index that is not a number")
	var holes := DieData.new()
	holes.faces = [DieFace.new(1), null] as Array[DieFace]
	check(DiceRoll.from_indices([holes], [1]).size() == 0, "an empty slot cannot have come up")
	check(DiceRoll.from_indices([holes], [0]).size() == 0, "nor any face of a die that cannot roll")
	check(DiceRoll.from_indices([null], [0]).size() == 0, "a null die")
	check(DiceRoll.from_dict([d6], {}).size() == 0, "from_dict without indices")
	check(DiceRoll.from_dict([d6], {"indices": 3}).size() == 0, "indices that are not a list")
	check(DiceRoll.from_dict([d6], {"indices": [2.0]}).values() == ([3] as Array[int]), "but a JSON list is fine")


func _from(pool: Array[DieData], picked: Array) -> DiceRoll:
	return DiceRoll.from_indices(pool, picked)


# 3 hit worth 1, 2 blank worth 0, 1 crit worth 2: the example's die, built in code.
func _attack_die() -> DieData:
	var hit := DieFace.new(1, &"hit")
	var blank := DieFace.new(0, &"blank")
	var die := DieData.new()
	die.faces = [hit, hit, hit, blank, blank, DieFace.new(2, &"crit")] as Array[DieFace]
	return die


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng
