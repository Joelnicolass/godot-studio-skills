extends "res://addons/stat_kit/tests/stat_test.gd"

## StatBlock in a tree: the sheet from the inspector, the read-only values in the inspector, live changes, limits, a
## rebuild that keeps what code did, signals, use_sheet, rebuilt and warnings.


func _build() -> StatBlock:
	var block := StatBlock.new()
	block.base_values = {&"attack": 5.0, &"defense": 4.0}
	block.start_modifiers = [StatModifier.plus(&"attack", 2, &"sword")]
	tree.root.add_child(block)
	return block


# The read-only values the inspector lists, as "name=value".
func _inspector_values(block: StatBlock) -> Array[String]:
	var shown: Array[String] = []
	for info in block.get_property_list():
		var name: String = info["name"]
		if name.begins_with("value_"):
			shown.append("%s=%s" % [name, String.num(float(block.get(name)), 3).trim_suffix(".0")])
	return shown


func test_sheet_from_inspector() -> void:
	var block := _build()
	check(block.value(&"attack") == 7.0 and block.base(&"attack") == 5.0, "base + start modifier")
	check(block.values() == ({&"attack": 7.0, &"defense": 4.0} as Dictionary[StringName, float]), "values")
	check(block.modifiers(&"attack").size() == 1 and block.modifiers(&"defense").is_empty(), "modifiers")
	check(block._get_configuration_warnings().is_empty(), "no warnings")
	block.free()


func test_values_in_the_inspector() -> void:
	var block := _build()
	check(_inspector_values(block) == (["value_attack=7", "value_defense=4"] as Array[String]), "the final values")
	var group_found := false
	for info in block.get_property_list():
		var name: String = info["name"]
		var usage: int = info["usage"]
		if name == "Values":
			group_found = usage & PROPERTY_USAGE_GROUP != 0 and info["hint_string"] == "value_"
		if name.begins_with("value_"):
			check(usage & PROPERTY_USAGE_READ_ONLY != 0, "%s is read only" % name)
			check(usage & PROPERTY_USAGE_STORAGE == 0, "%s is not saved in the scene" % name)
			check(usage & PROPERTY_USAGE_EDITOR != 0, "%s shows in the inspector" % name)
	check(group_found, "under a Values group")
	check(block.get(&"value_luck") == null, "a stat it does not have is not a property")
	block.free()


func test_inspector_follows_live_changes() -> void:
	var block := _build()
	var listed := [0]
	block.property_list_changed.connect(func() -> void: listed[0] += 1)
	var sword: StatModifier = block.start_modifiers[0]
	sword.amount = 3
	check(block.value(&"attack") == 8.0, "a value inside a start modifier applies at once")
	check(_inspector_values(block)[0] == "value_attack=8", "and the inspector reads it")
	check(listed[0] == 0, "a new value does not rebuild the inspector (it reads values again by itself)")
	block.base_values = {&"attack": 1.0, &"defense": 4.0, &"moves": 3.0}
	check(block.value(&"attack") == 4.0 and block.value(&"moves") == 3.0, "new base values build the sheet again")
	check(listed[0] == 1 and _inspector_values(block).size() == 3, "a new stat rebuilds the inspector list")
	block.start_modifiers = [sword, StatModifier.times(&"defense", 1.5, &"shield")]
	check(block.value(&"defense") == 6.0, "a new start modifier applies at once")
	block.add(StatModifier.plus(&"luck", 1))
	check(listed[0] == 2 and _inspector_values(block).has("value_luck=1"), "a stat added in code shows too")
	block.free()


func test_an_empty_start_modifier_gets_its_stat() -> void:
	var block := StatBlock.new()
	block.base_values = {&"attack": 5.0}
	var fresh := StatModifier.new()
	block.start_modifiers = [fresh, null]
	tree.root.add_child(block)
	check(block.modifiers().is_empty() and block._get_configuration_warnings().size() == 2, "skipped, with warnings")
	fresh.stat = &"attack"
	fresh.amount = 2
	check(block.value(&"attack") == 7.0, "once it has a stat, it is in the sheet")
	check(block._get_configuration_warnings().size() == 1, "only the empty slot is left to warn about")
	fresh.stat = &""
	check(block.value(&"attack") == 5.0 and block.modifiers().is_empty(), "and it leaves when it loses it")
	block.free()


func test_signals() -> void:
	var block := _build()
	var heard: Array[String] = []
	block.stat_changed.connect(
		func(stat: StringName, now: float) -> void: heard.append("%s=%s" % [stat, String.num(now, 3).trim_suffix(".0")])
	)
	var blessing := StatModifier.plus(&"defense", 2, &"blessing")
	block.add(blessing)
	block.add(StatModifier.times(&"attack", 2, &"blessing"))
	check(heard == (["defense=6", "attack=14"] as Array[String]), "the block relays the sheet: %s" % [heard])
	check(block.remove_source(&"blessing") == 2, "remove_source takes both")
	check(heard.slice(2) == (["attack=7", "defense=4"] as Array[String]), "and says so once per stat: %s" % [heard])
	block.add(blessing)
	check(block.remove(blessing) and not block.remove(blessing), "remove")
	block.set_base(&"defense", 10)
	check(block.value(&"defense") == 10.0 and block.base_values[&"defense"] == 4.0, "set_base leaves the inspector")
	block.free()


func test_use_sheet() -> void:
	var block := _build()
	var rules := StatSheet.new({&"attack": 1})
	block.use_sheet(rules)
	check(block.sheet == rules and block.value(&"attack") == 1.0, "the block shows the rules' sheet")
	var heard: Array[float] = []
	block.stat_changed.connect(func(_stat: StringName, now: float) -> void: heard.append(now))
	rules.add(StatModifier.plus(&"attack", 2))
	check(heard == ([3.0] as Array[float]), "and relays it")
	check(_inspector_values(block) == (["value_attack=3"] as Array[String]), "the inspector lists the rules' values")
	block.base_values = {&"attack": 50.0}
	block.start_modifiers = []
	check(rules.value(&"attack") == 3.0 and rules.modifiers().size() == 1, "the inspector never touches it")
	block.use_own_sheet()
	rules.add(StatModifier.plus(&"attack", 2))
	check(heard.size() == 1 and block.value(&"attack") == 50.0, "back to its own sheet")
	block.free()


func test_rebuilt() -> void:
	var block := _build()
	var count := [0]
	block.rebuilt.connect(func() -> void: count[0] += 1)
	block.use_sheet(StatSheet.new({&"attack": 1}))
	check(count[0] == 1, "use_sheet emits rebuilt")
	block.use_sheet(StatSheet.new({&"attack": 2}))
	check(count[0] == 2 and block.value(&"attack") == 2.0, "switching characters emits it again")
	block.use_own_sheet()
	check(count[0] == 3, "use_own_sheet too")
	block.base_values = {&"attack": 3.0}
	block.start_modifiers = []
	check(count[0] == 5, "and new base values or start modifiers")
	block.free()


func test_limits_from_the_inspector() -> void:
	var block := _build()
	block.max_values = {&"attack": 6.0}
	block.min_values = {&"defense": 5.0}
	check(block.value(&"attack") == 6.0 and block.value(&"defense") == 5.0, "max and min clamp the final value")
	check(block.sheet.limits(&"attack") == Vector2(-INF, 6), "the sheet has the limits")
	check(_inspector_values(block) == (["value_attack=6", "value_defense=5"] as Array[String]), "Values shows them")
	block.max_values = {}
	check(block.value(&"attack") == 7.0, "taking the limit away")
	block.free()


func test_rebuild_keeps_what_code_did() -> void:
	var block := _build()
	var sword: StatModifier = block.start_modifiers[0]
	var potion := StatModifier.plus(&"attack", 10, &"potion")
	var ring := StatModifier.percent(&"attack", 0.5, &"ring")
	block.add(potion)
	block.add(ring, &"left_ring")
	block.set_base(&"defense", 9)
	block.sheet.set_limits(&"defense", -INF, 20)
	check(block.value(&"attack") == 25.5, "(5 + 2 + 10) × 1.5")
	block.base_values = {&"attack": 1.0, &"defense": 4.0, &"moves": 3.0}
	check(block.modifiers() == ([sword, potion, ring] as Array[StatModifier]), "new base values keep every add")
	check(block.sources() == ([&"sword", &"potion", &"left_ring"] as Array[StringName]), "with their sources")
	check(block.value(&"attack") == 19.5 and block.value(&"moves") == 3.0, "and the new base applies: (1 + 12) × 1.5")
	check(block.base(&"defense") == 9.0, "a base set with set_base stays")
	check(block.sheet.limits(&"defense") == Vector2(-INF, 20), "and so does a limit set in code")
	check(block.remove(sword), "take the start sword off in code")
	var shield := StatModifier.times(&"defense", 2, &"shield")
	block.start_modifiers = [sword, shield]
	check(block.modifiers() == ([shield, potion, ring] as Array[StatModifier]), "a start modifier taken off stays off")
	check(block.value(&"defense") == 18.0, "the new start modifier is in: 9 × 2")
	block.max_values = {&"attack": 10.0}
	check(block.value(&"attack") == 10.0 and block.modifiers().size() == 3, "new limits keep them too")
	block.use_own_sheet()
	check(
		block.modifiers() == ([sword, shield] as Array[StatModifier]), "use_own_sheet starts again from the inspector"
	)
	check(block.base(&"defense") == 4.0 and block.value(&"attack") == 3.0, "with the inspector's bases: 1 + 2")
	block.free()


func test_a_live_edit_keeps_what_code_did() -> void:
	var block := _build()
	var fresh := StatModifier.new()
	block.start_modifiers = [block.start_modifiers[0], fresh]
	block.add(StatModifier.plus(&"attack", 10, &"potion"))
	fresh.stat = &"defense"
	fresh.amount = 1
	check(block.value(&"defense") == 5.0, "the empty start modifier got its stat and went in")
	check(block.sources().has(&"potion") and block.value(&"attack") == 17.0, "the potion added in code is still on")
	block.free()


func test_warnings() -> void:
	var block := StatBlock.new()
	block.base_values = {&"attack": 5.0, &"": 1.0}
	block.start_modifiers = [
		null,
		StatModifier.new(),
		StatModifier.plus(&"moves", 1, &"boots"),
		StatModifier.fixed(&"moves", 2, &"mud"),
		StatModifier.plus(&"attack", 2, &"sword"),
	]
	var warnings := block._get_configuration_warnings()
	check(warnings.size() == 4, "empty key, empty slot, no stat, moves with no base said once: %s" % [warnings])
	check(warnings[3].contains("moves"), "the stat with no base is named")
	check(block.value(&"moves") == 2.0 and block.value(&"attack") == 7.0, "a stat with no base still works")
	block.base_values = {&"attack": 5.0, &"moves": 1.0}
	block.start_modifiers = [StatModifier.times(&"attack", 0, &"curse"), StatModifier.times(&"attack", 2, &"rage")]
	warnings = block._get_configuration_warnings()
	check(warnings.size() == 1 and warnings[0].contains("by 0"), "a MUL of 0 warns: %s" % [warnings])
	block.start_modifiers = []
	block.min_values = {&"moves": 3.0, &"": 1.0}
	block.max_values = {&"moves": 2.0, &"luck": 4.0}
	warnings = block._get_configuration_warnings()
	check(warnings.size() == 3, "an empty limit key, a minimum above the maximum, luck with no base: %s" % [warnings])
	check(block.value(&"moves") == 1.0, "a minimum above the maximum is not applied")
	block.free()
