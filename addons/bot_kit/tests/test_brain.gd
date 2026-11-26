extends "res://addons/bot_kit/tests/bot_test.gd"

## Picking by score with no body: BotBrainCore.best (the rule Bot3D's modes use too) and the BotBrain node with its
## BotOption children and the game's `options`.


func _choices(scores: Dictionary) -> Array[BotChoice]:
	var out: Array[BotChoice] = []
	for id: StringName in scores:
		out.append(BotChoice.new(id, float(scores[id])))
	return out


func _ids(choices: Array[BotChoice]) -> Array[StringName]:
	var out: Array[StringName] = []
	for each in choices:
		out.append(each.id)
	return out


func _brain(scores: Dictionary) -> BotBrain:
	var brain := BotBrain.new()
	root.add_child(brain)
	for id: StringName in scores:
		var option := BotOption.new()
		option.name = String(id)
		option.score = float(scores[id])
		brain.add_child(option)
	return brain


func _option(brain: BotBrain, id: StringName) -> BotOption:
	return brain.get_node(NodePath(String(id))) as BotOption


# --- BotBrainCore ----------------------------------------------------------------------------------------------------


func test_core_the_highest_above_zero_wins() -> void:
	check(BotBrainCore.best(_choices({&"a": 1.0, &"b": 3.0, &"c": 2.0})).id == &"b", "the highest wins")
	check(BotBrainCore.best(_choices({&"a": 0.0, &"b": -2.0})) == null, "0 or less is out: nothing left, null")
	var none: Array[BotChoice] = []
	check(BotBrainCore.best(none) == null, "no choices: null")
	var some := _choices({&"a": -5.0, &"b": 0.5})
	some.insert(0, null)
	check(BotBrainCore.best(some).id == &"b", "a null choice and a negative one are skipped")
	check(
		BotBrainCore.best(_choices({&"a": 2.0, &"b": 2.0, &"c": 1.0})).id == &"a", "between equal new ones, the first"
	)
	var nan := _choices({&"a": NAN, &"b": 0.1})
	check(BotBrainCore.best(nan).id == &"b", "a score that is not a number is out")


func test_core_what_it_does_stays_until_beaten() -> void:
	var tie := _choices({&"a": 2.0, &"b": 2.0})
	check(BotBrainCore.best(tie, &"b").id == &"b", "a tie keeps what it does")
	check(BotBrainCore.best(_choices({&"a": 2.0, &"b": 1.5}), &"b").id == &"a", "a higher one takes over")
	check(BotBrainCore.best(_choices({&"a": 2.0, &"b": 3.0}), &"b").id == &"b", "it stays while it is the highest")
	check(BotBrainCore.best(_choices({&"a": 0.5, &"b": 0.0}), &"b").id == &"a", "what it does, at 0, is out")
	check(BotBrainCore.best(_choices({&"a": 0.0, &"b": 0.0}), &"b") == null, "nothing above 0: null, even its own")
	check(BotBrainCore.best(_choices({&"a": 1.0}), &"gone").id == &"a", "what it did is gone: the best")
	check(BotBrainCore.best(tie, &"").id == &"a", "empty: it does nothing yet, the first of a tie")
	var same := tie[1]
	check(BotBrainCore.best(tie, &"b") == same, "it returns the choice itself, with its payload")


func test_core_noise_is_drawn_from_the_rng() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var state := rng.state
	BotBrainCore.best(_choices({&"a": 1.0, &"b": 2.0}), &"", rng)
	check(rng.state == state, "no noise: nothing drawn (a Bot3D plays the same)")
	BotBrainCore.best(_choices({&"a": 1.0, &"b": 2.0}), &"", rng, 0.2)
	var other := RandomNumberGenerator.new()
	other.seed = 11
	other.randf_range(-0.2, 0.2)
	other.randf_range(-0.2, 0.2)
	check(rng.state == other.state, "one number per choice, in order")
	var first: Array[StringName] = []
	var again: Array[StringName] = []
	var close := _choices({&"a": 1.0, &"b": 1.1, &"c": 0.9})
	for pass_rng: Array[StringName] in [first, again]:
		var seeded := RandomNumberGenerator.new()
		seeded.seed = 99
		for i in 300:
			pass_rng.append(BotBrainCore.best(close, &"", seeded, 0.3).id)
	check(first == again, "the same seed picks the same way")
	check(first.count(&"a") > 0 and first.count(&"c") > 0, "noise picks a worse one now and then")
	check(first.count(&"b") > first.count(&"a") and first.count(&"b") > first.count(&"c"), "and the best most often")
	check(close[0].score == 1.0 and close[1].score == 1.1, "the scores are never changed")
	var steady := RandomNumberGenerator.new()
	var far := _choices({&"a": 1.0, &"b": 3.0})
	var only_b := true
	for i in 200:
		only_b = only_b and BotBrainCore.best(far, &"", steady, 0.3).id == &"b"
	check(only_b, "noise 0.3 never lifts 1 over 3")
	var negative := _choices({&"a": -1.0})
	var never := true
	for i in 300:
		never = never and BotBrainCore.best(negative, &"", steady, 5.0) == null
	check(never, "noise above 1 counts as 1: a score below 0 stays out")
	# Prints an error on purpose: noise needs an rng.
	check(BotBrainCore.best(close, &"", null, 0.3).id == &"b", "noise with no rng: an error, and no noise")


# --- BotBrain --------------------------------------------------------------------------------------------------------


func test_brain_picks_among_its_options_and_the_games() -> void:
	var brain := _brain({&"Gather": 2.0, &"Rest": 1.0, &"Off": 9.0})
	_option(brain, &"Off").enabled = false
	_option(brain, &"Rest").id = &"sleep"
	var given: Array[BotChoice] = []
	brain.chose.connect(func(choice: BotChoice) -> void: given.append(choice))
	var chosen := brain.think()
	check(chosen != null and chosen.id == &"Gather", "the option that wants it most")
	check(chosen.payload == _option(brain, &"Gather"), "an option's payload is the option node")
	check(
		_ids(brain.last_choices) == [&"Gather", &"sleep"],
		"it weighed the enabled ones, by id (%s)" % [brain.last_choices]
	)
	check(given.size() == 1 and given[0] == chosen and brain.current == chosen, "chose, once, and current")
	brain.options = func(_context: Variant) -> Array[BotChoice]: return [BotChoice.new(&"Trade", 3.0, {"with": 2})]
	chosen = brain.think()
	check(chosen.id == &"Trade" and chosen.payload["with"] == 2, "a choice from the game's options, with its payload")
	check(_ids(brain.last_choices) == [&"Gather", &"sleep", &"Trade"], "children first, then options")
	brain.options = func(_context: Variant) -> Array: return [BotChoice.new(&"Loose", 5.0), "not a choice"]
	check(brain.think().id == &"Loose", "an untyped array from options works; what is not a BotChoice is skipped")
	check(given.size() == 3, "chose on every think")


func test_brain_thinks_about_its_parent_unless_told() -> void:
	var holder := Node.new()
	root.add_child(holder)
	var brain := BotBrain.new()
	holder.add_child(brain)
	var seen: Array = []
	brain.options = func(context: Variant) -> Array[BotChoice]:
		seen.append(context)
		return [BotChoice.new(&"Go", 1.0)]
	brain.think()
	var match_state := {"turn": 3}
	brain.think(match_state)
	check(seen.size() == 2 and seen[0] == holder, "no context: its parent")
	check(seen[1] == match_state, "or what the game passed")


func test_brain_keeps_what_it_chose_until_beaten() -> void:
	var brain := _brain({&"A": 2.0, &"B": 1.0})
	check(brain.think().id == &"A", "A")
	_option(brain, &"B").score = 2.0
	check(brain.think().id == &"A", "a tie keeps A")
	_option(brain, &"B").score = 3.0
	check(brain.think().id == &"B", "B scores higher: B")
	_option(brain, &"A").score = 3.0
	check(brain.think().id == &"B", "a tie keeps B")
	brain.current = null
	check(brain.think().id == &"A", "forgotten: the first of a tie")
	var count := [0]
	brain.chose.connect(func(_choice: BotChoice) -> void: count[0] += 1)
	_option(brain, &"A").score = 0.0
	_option(brain, &"B").score = -1.0
	check(brain.think() == null and brain.current == null, "nothing above 0: null, and nothing current")
	check(count[0] == 0, "and no chose")


func test_brain_noise_follows_its_seed_or_the_games_rng() -> void:
	var picks: Array = []
	for each_seed in [5, 5, 6]:
		var brain := _brain({&"A": 1.0, &"B": 1.05, &"C": 0.95})
		brain.noise = 0.4
		brain.rng_seed = each_seed
		var ids: Array[StringName] = []
		for i in 60:
			brain.current = null
			ids.append(brain.think().id)
		picks.append(ids)
		brain.free()
	check(picks[0] == picks[1], "the same rng_seed picks the same way")
	check(picks[0] != picks[2], "another seed, another way")
	var game_rng := RandomNumberGenerator.new()
	game_rng.seed = 3
	var brain := _brain({&"A": 1.0, &"B": 1.05})
	brain.noise = 0.4
	brain.rng = game_rng
	var state := game_rng.state
	brain.think()
	check(game_rng.state != state, "an assigned rng gives the noise")
	brain.rng_seed = 8
	check(brain.rng == game_rng, "changing rng_seed leaves an assigned rng alone")
	brain.rng = null
	check(brain.rng != game_rng and brain.rng.seed == 8, "null: back to its own, from rng_seed")
	var one := BotBrain.new()
	var two := BotBrain.new()
	check(one.rng.seed != two.rng.seed, "rng_seed 0: each brain its own seed")
	one.free()
	two.free()


func test_brain_auto_think() -> void:
	var brain := _brain({&"A": 1.0})
	var count := [0]
	brain.chose.connect(func(_choice: BotChoice) -> void: count[0] += 1)
	brain.think_s = 0.1
	await tree.create_timer(0.3).timeout
	check(count[0] == 0, "off: only when the game calls think")
	brain.auto_think = true
	await tree.process_frame
	await tree.process_frame
	check(count[0] == 1, "on: it thinks right away")
	await tree.create_timer(0.55).timeout
	check(count[0] >= 5 and count[0] <= 8, "then every think_s (%d thinks in about 0.55 s)" % count[0])
	brain.auto_think = false
	var stopped: int = count[0]
	await tree.create_timer(0.3).timeout
	check(count[0] == stopped, "off again: it stops")


func test_warnings() -> void:
	var lonely := BotBrain.new()
	root.add_child(lonely)
	check(lonely._get_configuration_warnings().size() == 1, "no BotOption: a warning (it only has options)")
	var brain := _brain({&"A": 1.0, &"B": 1.0})
	check(brain._get_configuration_warnings().is_empty(), "two options: no warning")
	_option(brain, &"B").id = &"A"
	var warnings := brain._get_configuration_warnings()
	check(warnings.size() == 1 and warnings[0].contains("A"), "two options both A: a warning")
	var stray := BotOption.new()
	root.add_child(stray)
	check(stray._get_configuration_warnings().size() == 1, "an option outside a brain: a warning")
	check(_option(brain, &"A")._get_configuration_warnings().is_empty(), "inside one: none")
