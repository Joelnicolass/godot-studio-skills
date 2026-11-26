extends "res://addons/stat_kit/tests/stat_test.gd"

## StatSheet alone, no tree: bases, the ADD → PERCENT → MUL → SET order, limits, stacking, sources given when adding,
## remove and remove_source, stat_changed only on real changes, modifiers that change after they were added, errors
## and to_dict.


# Records every stat_changed of `sheet` as "stat=value".
func _listen(sheet: StatSheet) -> Array[String]:
	var heard: Array[String] = []
	sheet.stat_changed.connect(
		func(stat: StringName, now: float) -> void: heard.append("%s=%s" % [stat, String.num(now, 3).trim_suffix(".0")])
	)
	return heard


func test_bases() -> void:
	var sheet := StatSheet.new({&"defense": 4, "attack": 5})
	check(sheet.base(&"attack") == 5.0 and sheet.value(&"attack") == 5.0, "a base is the value with no modifier")
	check(sheet.base(&"luck") == 0.0 and sheet.value(&"luck") == 0.0, "a stat it never heard of is 0")
	check(sheet.stats() == ([&"attack", &"defense"] as Array[StringName]), "stats sorted: %s" % [sheet.stats()])
	sheet.set_base(&"moves", 3)
	check(sheet.value(&"moves") == 3.0 and sheet.stats().size() == 3, "set_base adds a stat")
	var copy := sheet.bases()
	copy[&"attack"] = 99.0
	check(sheet.base(&"attack") == 5.0, "bases() is a copy")


func test_add_then_mul_then_set() -> void:
	var sheet := StatSheet.new({&"attack": 5})
	var double := StatModifier.times(&"attack", 2, &"rage")
	sheet.add(double)
	sheet.add(StatModifier.plus(&"attack", 2, &"sword"))
	sheet.add(StatModifier.plus(&"attack", 1, &"ring"))
	check(sheet.value(&"attack") == 16.0, "(5 + 2 + 1) × 2 = 16, the MUL added first: %s" % sheet.value(&"attack"))
	sheet.add(StatModifier.times(&"attack", 0.5, &"curse"))
	check(sheet.value(&"attack") == 8.0, "every MUL multiplies: (5 + 3) × 2 × 0.5")
	var swamp := StatModifier.fixed(&"attack", 1, &"swamp")
	sheet.add(swamp)
	check(sheet.value(&"attack") == 1.0, "a SET wins over the base, the ADDs and the MULs")
	var bog := StatModifier.fixed(&"attack", 4, &"bog")
	sheet.add(bog)
	check(sheet.value(&"attack") == 4.0, "the last SET added wins")
	sheet.add(StatModifier.plus(&"attack", 10, &"potion"))
	check(sheet.value(&"attack") == 4.0, "an ADD after the SET still loses to it")
	check(sheet.remove(bog) and sheet.value(&"attack") == 1.0, "without the last SET, the one before wins")
	check(sheet.remove(swamp) and sheet.value(&"attack") == 18.0, "without SETs, (5 + 13) × 2 × 0.5")


func test_percent_adds_up() -> void:
	var sheet := StatSheet.new({&"attack": 5})
	sheet.add(StatModifier.percent(&"attack", 0.5, &"left_ring"))
	sheet.add(StatModifier.percent(&"attack", 0.5, &"right_ring"))
	check(sheet.value(&"attack") == 10.0, "+50 % and +50 % add up: 5 × (1 + 1) = 10, not 5 × 2.25")
	sheet.add(StatModifier.plus(&"attack", 2, &"sword"))
	check(sheet.value(&"attack") == 14.0, "the ADDs come first: (5 + 2) × 2")
	sheet.add(StatModifier.times(&"attack", 1.5, &"rage"))
	check(sheet.value(&"attack") == 21.0, "then the MULs: (5 + 2) × (1 + 1) × 1.5")
	sheet.add(StatModifier.percent(&"attack", -0.5, &"curse"))
	check(sheet.value(&"attack") == 15.75, "a negative PERCENT is a penalty: 7 × 1.5 × 1.5")
	sheet.add(StatModifier.fixed(&"attack", 3, &"swamp"))
	check(sheet.value(&"attack") == 3.0, "a SET still wins over all of it")


func test_limits() -> void:
	var sheet := StatSheet.new({&"moves": 3, &"defense": 8})
	var heard := _listen(sheet)
	sheet.set_limits(&"moves", 1)
	check(sheet.limits(&"moves") == Vector2(1, INF), "a minimum only: %s" % sheet.limits(&"moves"))
	check(heard.is_empty(), "a limit the value is already inside changes nothing")
	sheet.add(StatModifier.plus(&"moves", -5, &"mud"))
	check(sheet.value(&"moves") == 1.0 and heard == (["moves=1"] as Array[String]), "the value stops at the minimum")
	sheet.add(StatModifier.fixed(&"moves", 0, &"swamp"))
	check(sheet.value(&"moves") == 1.0, "a SET is kept inside the limits too")
	sheet.set_limits(&"defense", -INF, 10)
	sheet.add(StatModifier.times(&"defense", 2, &"shield"))
	check(sheet.value(&"defense") == 10.0 and sheet.limits(&"defense") == Vector2(-INF, 10), "a maximum only")
	sheet.clear_limits(&"defense")
	check(
		sheet.value(&"defense") == 16.0 and heard.slice(1) == (["defense=10", "defense=16"] as Array[String]), "cleared"
	)
	check(sheet.limits(&"defense") == Vector2(-INF, INF), "no limits: -INF and INF")
	sheet.set_limits(&"luck", 2, 5)
	check(sheet.stats().has(&"luck") and sheet.value(&"luck") == 2.0, "a stat with only limits counts, from 0 up to 2")
	sheet.set_limits(&"moves", 4, 2)
	sheet.set_limits(&"", 0, 1)
	check(sheet.limits(&"moves") == Vector2(1, INF), "a minimum above the maximum is an error and changes nothing")


func test_source_given_when_adding() -> void:
	var sheet := StatSheet.new({&"attack": 5})
	var ring := StatModifier.percent(&"attack", 0.5, &"ring")
	sheet.add(ring, &"left_ring")
	sheet.add(ring, &"right_ring")
	check(sheet.value(&"attack") == 10.0, "one resource, two rings")
	check(sheet.sources() == ([&"left_ring", &"right_ring"] as Array[StringName]), "each counts as its own source")
	var lines := sheet.describe(&"attack")
	check(lines == PackedStringArray(["+50 % attack (left_ring)", "+50 % attack (right_ring)"]), "describe: %s" % lines)
	check(sheet.remove_source(&"ring") == 0, "the resource's own source is not the one that counts")
	check(sheet.remove_source(&"left_ring") == 1 and sheet.sources() == ([&"right_ring"] as Array[StringName]), "left")
	check(sheet.value(&"attack") == 7.5, "the right ring stays")
	check(not sheet.remove(ring, &"left_ring") and sheet.remove(ring, &"right_ring"), "remove with a source")
	var boots: Array[StatModifier] = [StatModifier.plus(&"moves", 1), StatModifier.plus(&"defense", 1, &"leather")]
	var heard := _listen(sheet)
	sheet.add_all(boots, &"boots")
	check(sheet.sources() == ([&"boots", &"boots"] as Array[StringName]), "add_all gives them all one source")
	check(heard == (["defense=1", "moves=1"] as Array[String]), "one signal per stat, sorted: %s" % [heard])
	sheet.add(StatModifier.plus(&"luck", 1, &"clover"))
	check(sheet.sources(&"luck") == ([&"clover"] as Array[StringName]), "with no source given, its own counts")
	check(sheet.remove_source(&"boots") == 2 and sheet.modifiers().size() == 1, "and remove_source takes the item")


func test_remove_source_with_no_source() -> void:
	var sheet := StatSheet.new({&"attack": 5})
	sheet.add(StatModifier.plus(&"attack", 1))
	sheet.add(StatModifier.plus(&"attack", 2, &"sword"))
	sheet.add(StatModifier.plus(&"attack", 3), &"potion")
	check(sheet.remove_source(&"") == 1, 'remove_source(&"") takes the modifiers with no source at all')
	check(sheet.sources() == ([&"sword", &"potion"] as Array[StringName]), "the others stay")


func test_stacking() -> void:
	var sheet := StatSheet.new({&"attack": 5})
	var sword := StatModifier.plus(&"attack", 2, &"sword")
	sheet.add(sword)
	sheet.add(sword)
	check(sheet.value(&"attack") == 9.0 and sheet.modifiers(&"attack").size() == 2, "the same modifier twice stacks")
	check(sheet.remove(sword) and sheet.value(&"attack") == 7.0, "remove takes one occurrence")
	check(sheet.remove(sword) and not sheet.remove(sword), "then the other, then there is none")
	check(sheet.value(&"attack") == 5.0, "back to the base")


func test_remove_a_loaded_copy() -> void:
	var first := StatModifier.plus(&"attack", 1, &"ring")
	var second := StatModifier.plus(&"attack", 1, &"ring")
	var sheet := StatSheet.new({&"attack": 5})
	sheet.add(first)
	check(not sheet.remove(second), "an equal modifier that was never added is not the one in the sheet")
	sheet.add(second)
	sheet.remove(second)
	check(sheet.modifiers() == ([first] as Array[StatModifier]), "remove takes the instance itself")
	check(not sheet.remove(null), "remove(null) is false")
	var saved := StatSheet.new({&"attack": 5})
	var sword := StatModifier.plus(&"attack", 2, &"sword")
	saved.add(sword)
	saved.add(sword, &"spare_sword")
	var loaded := StatSheet.from_dict(saved.to_dict())
	check(not loaded.remove(StatModifier.plus(&"attack", 2, &"axe")), "a loaded copy: another source is another one")
	check(not loaded.remove(StatModifier.times(&"attack", 2, &"sword")), "and so is another op")
	check(loaded.remove(sword) and loaded.sources() == ([&"spare_sword"] as Array[StringName]), "the copy counts")
	check(loaded.remove(sword, &"spare_sword") and loaded.modifiers().is_empty(), "with the source it was given too")


func test_remove_source() -> void:
	var sheet := StatSheet.new({&"attack": 5, &"defense": 4, &"moves": 3})
	var sword := StatModifier.plus(&"attack", 2, &"sword")
	sheet.add(sword)
	sheet.add(StatModifier.plus(&"moves", 1, &"blessing"))
	sheet.add(StatModifier.plus(&"defense", 2, &"blessing"))
	sheet.add(StatModifier.times(&"attack", 2, &"blessing"))
	check(sheet.value(&"attack") == 14.0 and sheet.value(&"defense") == 6.0, "blessed")
	var heard := _listen(sheet)
	check(sheet.remove_source(&"blessing") == 3, "remove_source returns how many it took")
	check(sheet.modifiers() == ([sword] as Array[StatModifier]), "every modifier of the source left, the rest stays")
	check(heard == (["attack=7", "defense=4", "moves=3"] as Array[String]), "one signal per stat, sorted: %s" % [heard])
	check(sheet.remove_source(&"blessing") == 0 and heard.size() == 3, "a second time takes nothing and says nothing")


func test_modifiers_list() -> void:
	var sheet := StatSheet.new()
	var a := StatModifier.plus(&"attack", 1)
	var b := StatModifier.plus(&"defense", 1)
	var c := StatModifier.times(&"attack", 2)
	sheet.add(a)
	sheet.add(b)
	sheet.add(c)
	check(sheet.modifiers() == ([a, b, c] as Array[StatModifier]), "all, in the order added")
	check(sheet.modifiers(&"attack") == ([a, c] as Array[StatModifier]), "those of one stat")
	var list := sheet.modifiers()
	list.clear()
	check(sheet.modifiers().size() == 3, "a copy of the list")


func test_values_and_stats() -> void:
	var sheet := StatSheet.new({&"moves": 3})
	sheet.add(StatModifier.plus(&"attack", 2, &"sword"))
	check(sheet.stats() == ([&"attack", &"moves"] as Array[StringName]), "a stat with only a modifier counts")
	check(sheet.value(&"attack") == 2.0, "it starts from 0")
	var all := sheet.values()
	check(all == ({&"attack": 2.0, &"moves": 3.0} as Dictionary[StringName, float]), "values: %s" % [all])
	check(all.keys() == [&"attack", &"moves"], "sorted by stat")


func test_stat_changed_only_on_real_change() -> void:
	var sheet := StatSheet.new({&"attack": 5, &"moves": 3})
	var heard := _listen(sheet)
	sheet.set_base(&"attack", 5)
	sheet.add(StatModifier.plus(&"attack", 0))
	sheet.add(StatModifier.times(&"attack", 1))
	check(heard.is_empty(), "the same base, +0 and ×1 change nothing: %s" % [heard])
	sheet.add(StatModifier.plus(&"attack", 2))
	check(heard == (["attack=7"] as Array[String]), "a real change: %s" % [heard])
	sheet.add(StatModifier.fixed(&"moves", 1))
	sheet.set_base(&"moves", 9)
	sheet.add(StatModifier.plus(&"moves", 4))
	check(heard == (["attack=7", "moves=1"] as Array[String]), "under a SET, the base and an ADD change nothing")
	var luck := StatModifier.plus(&"luck", 2)
	sheet.add(luck)
	sheet.remove(luck)
	check(heard.slice(2) == (["luck=2", "luck=0"] as Array[String]), "a stat with no base goes back to 0")
	check(not sheet.stats().has(&"luck"), "and leaves stats()")


func test_a_modifier_changed_after_it_was_added() -> void:
	var sheet := StatSheet.new({&"attack": 5, &"defense": 4})
	var sword := StatModifier.plus(&"attack", 2, &"sword")
	sheet.add(sword)
	sheet.add(sword)
	var heard := _listen(sheet)
	sword.amount = 3
	check(sheet.value(&"attack") == 11.0 and heard == (["attack=11"] as Array[String]), "a new amount applies at once")
	sword.stat = &"defense"
	check(sheet.value(&"attack") == 5.0 and sheet.value(&"defense") == 10.0, "a new stat moves the bonus")
	check(heard.slice(1) == (["attack=5", "defense=10"] as Array[String]), "both say so: %s" % [heard])
	check(sword.changed.get_connections().size() == 1, "the sheet listens once, even to a modifier added twice")
	sheet.remove(sword)
	check(sword.changed.get_connections().size() == 1, "still listening while one occurrence is left")
	sheet.remove(sword)
	check(sword.changed.get_connections().is_empty(), "a modifier that left the sheet is no longer heard")
	var before := heard.size()
	sword.amount = 50
	check(sheet.value(&"defense") == 4.0 and heard.size() == before, "and changing it does nothing")


func test_shared_modifier() -> void:
	var ana := StatSheet.new({&"attack": 5})
	var beto := StatSheet.new({&"attack": 1})
	var banner := StatModifier.times(&"attack", 2, &"banner")
	ana.add(banner)
	beto.add(banner)
	banner.amount = 3
	check(ana.value(&"attack") == 15.0 and beto.value(&"attack") == 3.0, "one resource in two sheets updates both")
	ana.remove_source(&"banner")
	check(ana.value(&"attack") == 5.0 and beto.value(&"attack") == 3.0, "each sheet keeps its own list")


func test_clear_modifiers() -> void:
	var sheet := StatSheet.new({&"attack": 5})
	var sword := StatModifier.plus(&"attack", 2, &"sword")
	sheet.add(sword)
	sheet.add(StatModifier.plus(&"luck", 1))
	var heard := _listen(sheet)
	sheet.clear_modifiers()
	check(sheet.modifiers().is_empty() and sheet.value(&"attack") == 5.0, "the bases stay")
	check(heard == (["attack=5", "luck=0"] as Array[String]), "every stat that changed says so: %s" % [heard])
	check(sword.changed.get_connections().is_empty(), "and no modifier is heard any more")


func test_errors() -> void:
	var sheet := StatSheet.new({&"attack": 5, &"": 2})
	check(sheet.stats() == ([&"attack"] as Array[StringName]), "an empty stat in the bases is skipped")
	var heard := _listen(sheet)
	sheet.add(null)
	sheet.add(StatModifier.plus(&"", 2))
	sheet.set_base(&"", 3)
	check(sheet.modifiers().is_empty() and sheet.stats().size() == 1, "null and empty stats add nothing")
	check(heard.is_empty(), "and say nothing")


func test_to_dict_round_trip() -> void:
	var sheet := StatSheet.new({&"moves": 3, &"attack": 5})
	sheet.add(StatModifier.plus(&"attack", 2, &"sword"))
	sheet.add(StatModifier.fixed(&"moves", 2, &"mud"))
	sheet.add(StatModifier.fixed(&"moves", 1, &"swamp"))
	var data := sheet.to_dict()
	check(data["bases"] == {"attack": 5.0, "moves": 3.0}, "bases as plain data: %s" % [data["bases"]])
	check(data["limits"] == {}, "no limits, none saved")
	var saved: Array = data["modifiers"]
	check(saved.size() == 3 and saved[0] == {"stat": "attack", "op": "add", "amount": 2.0, "source": "sword"}, "mods")
	var copy := StatSheet.from_dict(data)
	check(copy.to_dict() == data and copy.values() == sheet.values(), "from_dict(to_dict()) is the same sheet")
	check(copy.value(&"moves") == 1.0, "in the same order: the last SET still wins")
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(data))
	check(StatSheet.from_dict(parsed).to_dict() == data, "it survives JSON")
	check(copy.remove_source(&"sword") == 1 and copy.value(&"attack") == 5.0, "remove_source works on the copy")
	check(copy.remove(StatModifier.fixed(&"moves", 1, &"swamp")) and copy.value(&"moves") == 2.0, "and remove")


func test_from_dict_skips_what_it_cannot_read() -> void:
	var data := {
		"bases": {"attack": 5}, "modifiers": [7, {"stat": "attack", "op": "pow"}, {"stat": "attack", "amount": 1}]
	}
	var sheet := StatSheet.from_dict(data)
	check(sheet.modifiers().size() == 1 and sheet.value(&"attack") == 6.0, "only the readable modifier came back")
	check(StatSheet.from_dict({}).stats().is_empty(), "an empty dict is an empty sheet")


func test_to_dict_keeps_limits_percent_and_given_sources() -> void:
	var sheet := StatSheet.new({&"attack": 5, &"moves": 3})
	sheet.set_limits(&"moves", 1)
	sheet.set_limits(&"attack", 0, 12)
	var ring := StatModifier.percent(&"attack", 0.5, &"ring")
	sheet.add(ring, &"left_ring")
	sheet.add(ring, &"right_ring")
	sheet.add(StatModifier.plus(&"moves", -9, &"mud"))
	var data := sheet.to_dict()
	check(
		data["limits"] == {"attack": {"min": 0.0, "max": 12.0}, "moves": {"min": 1.0}}, "limits: %s" % [data["limits"]]
	)
	var saved: Array = data["modifiers"]
	check(saved[0]["source"] == "left_ring" and saved[1]["source"] == "right_ring", "the source each counted as")
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(data))
	var copy := StatSheet.from_dict(parsed)
	check(copy.to_dict() == data and copy.values() == sheet.values(), "through JSON: %s" % [copy.values()])
	check(copy.value(&"attack") == 10.0 and copy.value(&"moves") == 1.0, "the limits and the percent came back")
	check(copy.remove_source(&"left_ring") == 1 and copy.value(&"attack") == 7.5, "and the sources")
	var bad := StatSheet.from_dict({"bases": {"moves": 3}, "limits": {"moves": 5, "luck": {"max": 2}}})
	check(bad.limits(&"luck") == Vector2(-INF, 2) and bad.limits(&"moves") == Vector2(-INF, INF), "a bad limit skipped")
