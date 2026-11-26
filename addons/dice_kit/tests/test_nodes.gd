extends "res://addons/dice_kit/tests/dice_test.gd"

## DiceRoller in a tree: count, rolled and last_roll, extra dice, rng_seed against an assigned rng, dice_changed, the
## Roll button, errors and warnings.


func _build(seed_value := 0, sides := 6) -> DiceRoller:
	var roller := DiceRoller.new()
	roller.die = DieData.numbered(sides)
	roller.count = 3
	roller.rng_seed = seed_value
	tree.root.add_child(roller)
	return roller


func test_roll_uses_count() -> void:
	var roller := _build(4)
	var heard: Array[DiceRoll] = []
	roller.rolled.connect(func(roll: DiceRoll) -> void: heard.append(roll))
	var roll := roller.roll()
	check(roll.size() == 3, "count dice when not told: %d" % roll.size())
	check(heard == ([roll] as Array[DiceRoll]) and roller.last_roll == roll, "rolled carries it; last_roll keeps it")
	check(roller.roll(5).size() == 5 and heard.size() == 2, "roll(n) rolls n")
	roller.free()


func test_ready_die() -> void:
	var roller := _build(8)
	roller.die = load("res://addons/dice_kit/dice/d20.tres") as DieData
	var ok := true
	for value in roller.roll(30).values():
		ok = ok and value >= 1 and value <= 20
	check(ok and roller._get_configuration_warnings().is_empty(), "a ready d20 from the inspector rolls 1 to 20")
	roller.free()


func test_extra_dice() -> void:
	var roller := _build(6)
	var d8 := DieData.numbered(8)
	var d4 := DieData.numbered(4)
	roller.count = 2
	roller.extra_dice = [d8, d4] as Array[DieData]
	check(roller.pool() == ([roller.die, roller.die, d8, d4] as Array[DieData]), "count of die, then the extras")
	var roll := roller.roll()
	check(roll.size() == 4 and roll.dice[2] == d8 and roll.dice[3] == d4, "2d6 + 1d8 + 1d4 in one roll")
	var plain := RandomNumberGenerator.new()
	plain.seed = 6
	var expected := DiceRoll.of(roller.pool(), plain)
	check(roll.indices == expected.indices, "the same as DiceRoll.of(pool(), rng)")
	check(roller.roll(0).size() == 2, "roll(0): only the extras")
	roller.die = null
	check(roller.roll().dice == ([d8, d4] as Array[DieData]), "no die: only the extras")
	check(roller._get_configuration_warnings().is_empty(), "and no warning for it")
	roller.free()


func test_seed_repeats() -> void:
	var first := _build(7)
	var second := _build(7)
	var same := true
	for turn in 4:
		same = same and first.roll().indices == second.roll().indices
	check(same, "the same rng_seed gives the same rolls in the same order")
	first.rng_seed = 7
	var again := _build(7)
	check(first.roll().indices == again.roll().indices, "setting rng_seed starts the own rng again")
	first.free()
	second.free()
	again.free()


func test_seed_zero_is_fresh() -> void:
	var first := _build(0)
	var second := _build(0)
	var kept := first.rng
	check(kept.seed != second.rng.seed, "rng_seed 0: each roller gets its own random seed, even made together")
	check(first.roll(8).indices != second.roll(8).indices, "so they roll differently")
	first.roll()
	check(first.rng == kept, "and keeps its rng")
	first.free()
	second.free()


func test_assigned_rng() -> void:
	var match_rng := RandomNumberGenerator.new()
	match_rng.seed = 21
	var attack := _build(3)
	var defense := _build(4)
	attack.rng = match_rng
	defense.rng = match_rng
	var drawn := attack.roll(2).indices + defense.roll(2).indices + attack.roll(1).indices
	var plain := RandomNumberGenerator.new()
	plain.seed = 21
	check(drawn == DieData.numbered(6).roll(5, plain).indices, "two rollers share the match's rng, in turn")
	var state := match_rng.state
	attack.rng_seed = 99
	check(attack.rng == match_rng and match_rng.state == state, "a new rng_seed never touches an assigned rng")
	attack.rng = null
	var own := RandomNumberGenerator.new()
	own.seed = 99
	check(attack.rng != match_rng and attack.roll(4).indices == DieData.numbered(6).roll(4, own).indices, "null: own")
	attack.free()
	defense.free()


func test_dice_changed() -> void:
	var roller := _build(1)
	var heard := [0]
	roller.dice_changed.connect(func() -> void: heard[0] += 1)
	roller.count = 4
	check(heard[0] == 1, "count")
	roller.die = DieData.numbered(8)
	check(heard[0] == 2, "die")
	var d4 := DieData.numbered(4)
	roller.extra_dice = [d4] as Array[DieData]
	check(heard[0] == 3, "extra_dice")
	roller.die.faces[0].value = 10
	d4.faces[1].tag = &"hit"
	check(heard[0] == 5, "a face edited inside the die or an extra")
	var old := roller.die
	roller.die = null
	old.faces[0].value = 11
	check(heard[0] == 6 and old.changed.get_connections().is_empty(), "a die it no longer has is not heard")
	roller.free()


func test_errors() -> void:
	var roller := DiceRoller.new()
	tree.root.add_child(roller)
	var heard := [0]
	roller.rolled.connect(func(_roll: DiceRoll) -> void: heard[0] += 1)
	check(roller.roll().size() == 0, "no die: an empty roll")
	roller.die = DieData.new()
	check(roller.roll().size() == 0, "a die without faces: an empty roll")
	roller.die = DieData.numbered(6)
	var state := roller.rng.state
	check(roller.roll(0).size() == 0 and roller.roll(-2).size() == 0, "n = 0 with no extras, or under -1")
	roller.extra_dice = [null] as Array[DieData]
	check(roller.roll().size() == 0, "an empty extra slot: an empty roll")
	check(heard[0] == 0 and roller.last_roll == null, "no signal and no last_roll for a failed roll")
	check(roller.rng.state == state, "and nothing drawn")
	roller.free()


func test_try_it_button() -> void:
	var roller := _build(3)
	check(str(roller.get(&"last_result")) == "(press Roll)", "before the first roll")
	var button: Callable = roller.roll_button
	button.call()
	check(roller.last_roll != null and roller.last_roll.size() == 3, "the Roll button rolls count dice")
	check(
		roller.get(&"last_result") == roller.last_roll.describe(),
		"last_result shows it: %s" % roller.get(&"last_result")
	)
	var names: Array[String] = []
	var usage := 0
	for info in roller.get_property_list():
		names.append(str(info["name"]))
		if info["name"] == "last_result":
			usage = info["usage"]
	check(names.find("last_result") > names.find("roll_button"), "last_result comes after the Roll button")
	check(usage & PROPERTY_USAGE_READ_ONLY and not usage & PROPERTY_USAGE_STORAGE, "read only, never saved")
	roller.free()


func test_warnings() -> void:
	var roller := DiceRoller.new()
	check(roller._get_configuration_warnings().size() == 1, "no die")
	roller.die = DieData.new()
	check(roller._get_configuration_warnings().size() == 1, "a die without faces")
	roller.die.faces = [DieFace.new(1), null] as Array[DieFace]
	var warnings := roller._get_configuration_warnings()
	check(warnings.size() == 1 and warnings[0].contains("cannot roll"), "an empty slot: %s" % [warnings])
	roller.die.faces = [DieFace.new(1), DieFace.new(2)] as Array[DieFace]
	check(roller._get_configuration_warnings().is_empty(), "a good die: no warnings")
	roller.extra_dice = [null, DieData.new(), DieData.numbered(4)] as Array[DieData]
	warnings = roller._get_configuration_warnings()
	check(warnings.size() == 2 and warnings[0].contains("slot 0"), "an empty extra slot, an extra without faces")
	roller.free()
