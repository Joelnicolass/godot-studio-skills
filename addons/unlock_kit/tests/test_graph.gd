extends "res://addons/unlock_kit/tests/unlock_test.gd"

## UnlockGraph alone, no tree: entries, the all-of and one-of rules, why_not, unlock, buy and lock, signals, depth,
## restore, problems and to_dict.


# farming > irrigation > aqueduct (+ masonry), farming > pottery, masonry; market needs pottery or masonry.
func _tree() -> UnlockGraph:
	var graph := UnlockGraph.new()
	graph.add(&"farming")
	graph.add(&"irrigation", [&"farming"], {&"points": 2})
	graph.add(&"aqueduct", [&"irrigation", &"masonry"], {&"points": 4, &"stone": 1})
	graph.add(&"pottery", [&"farming"], {&"points": 1})
	graph.add(&"masonry", [], {&"points": 2})
	graph.add(&"market", [], {&"points": 3}, [&"pottery", &"masonry"])
	return graph


func test_entries() -> void:
	var graph := _tree()
	check(graph.has(&"aqueduct") and not graph.has(&"walls"), "has")
	var ids: Array[StringName] = [&"farming", &"irrigation", &"aqueduct", &"pottery", &"masonry", &"market"]
	check(graph.ids() == ids, "ids in the order added: %s" % [graph.ids()])
	check(graph.requires(&"aqueduct") == ([&"irrigation", &"masonry"] as Array[StringName]), "requires")
	check(graph.requires(&"walls").is_empty(), "requires of an unknown id is empty")
	check(graph.requires_any(&"market") == ([&"pottery", &"masonry"] as Array[StringName]), "requires_any")
	check(graph.requires_any(&"aqueduct").is_empty() and graph.requires(&"market").is_empty(), "kept apart")
	check(graph.cost_of(&"irrigation") == ({&"points": 2} as Dictionary[StringName, int]), "cost_of")
	check(graph.cost_of(&"farming").is_empty() and graph.cost_of(&"walls").is_empty(), "free and unknown: {}")
	var copy := graph.cost_of(&"irrigation")
	copy[&"points"] = 99
	check(graph.cost_of(&"irrigation")[&"points"] == 2, "cost_of is a copy")


func test_add_errors() -> void:
	var graph := _tree()
	check(not graph.add(&""), "an empty id is an error")
	check(not graph.add(&"farming"), "a repeated id is an error")
	check(graph.ids().size() == 6, "nothing was added")
	check(graph.add(&"walls", ["masonry", &"masonry", ""], {"points": 3, &"gold": -1}), "String ids and keys work")
	check(graph.requires(&"walls") == ([&"masonry"] as Array[StringName]), "repeats and empty ids are left out")
	check(graph.cost_of(&"walls") == ({&"points": 3} as Dictionary[StringName, int]), "a negative amount is left out")


func test_can_unlock_and_why_not() -> void:
	var graph := _tree()
	check(graph.can_unlock(&"farming") and graph.why_not(&"farming") == "", "a root can be unlocked")
	check(not graph.can_unlock(&"irrigation") and graph.why_not(&"irrigation") == "locked", "a requirement is missing")
	check(graph.missing(&"aqueduct") == ([&"irrigation", &"masonry"] as Array[StringName]), "missing, in order")
	check(graph.why_not(&"walls") == "unknown" and not graph.can_unlock(&"walls"), "unknown")
	check(graph.unlock(&"farming"), "unlock a root")
	check(graph.why_not(&"farming") == "already_unlocked", "already_unlocked")
	check(graph.unlock(&"irrigation"), "its requirement is unlocked now")
	check(graph.missing(&"aqueduct") == ([&"masonry"] as Array[StringName]), "all of them are needed")
	check(not graph.unlock(&"aqueduct"), "one missing: no")
	check(graph.unlock(&"masonry") and graph.unlock(&"aqueduct"), "with both: yes")
	check(graph.missing(&"aqueduct").is_empty(), "nothing missing")


func test_requires_any() -> void:
	var graph := _tree()
	check(graph.why_not(&"market") == "locked", "none of them: locked")
	check(graph.missing(&"market") == ([&"pottery", &"masonry"] as Array[StringName]), "missing lists them all")
	check(graph.unlock(&"masonry"), "one of them")
	check(graph.can_unlock(&"market") and graph.missing(&"market").is_empty(), "one is enough")
	check(graph.available_ids().has(&"market"), "available")
	graph.unlock(&"farming")
	graph.unlock(&"pottery")
	graph.unlock(&"market")
	check(graph.lock(&"masonry"), "pottery still holds market up: masonry can go")
	check(not graph.lock(&"pottery"), "now pottery is the only one: it stays")
	check(graph.is_unlocked(&"pottery") and graph.is_unlocked(&"market"), "nothing changed")
	var both := UnlockGraph.new()
	both.add(&"a")
	both.add(&"b")
	both.add(&"c", [&"a"], {}, [&"b"])
	both.unlock(&"b")
	check(both.why_not(&"c") == "locked" and both.missing(&"c") == ([&"a"] as Array[StringName]), "all-of still counts")
	both.unlock(&"a")
	check(both.can_unlock(&"c"), "with both rules met")


func test_buy() -> void:
	var graph := _tree()
	var points: Array[int] = [3]
	var asked: Array[Dictionary] = []
	var pay := func(cost: Dictionary) -> bool:
		asked.append(cost)
		var price: int = cost.get(&"points", 0)
		if points[0] < price:
			return false
		points[0] -= price
		return true
	check(not graph.buy(&"irrigation", pay) and asked.is_empty(), "cannot be unlocked: pay is not called")
	check(graph.buy(&"farming", pay) and asked.size() == 1 and asked[0].is_empty(), "free: pay gets {}")
	check(graph.buy(&"irrigation", pay) and points[0] == 1, "pays 2 and unlocks")
	var price: int = asked[1].get(&"points", 0)
	check(asked[1].size() == 1 and price == 2, "pay gets the cost: %s" % [asked[1]])
	check(not graph.buy(&"masonry", pay) and not graph.is_unlocked(&"masonry"), "pay said no: nothing unlocked")
	check(points[0] == 1, "and nothing charged")
	check(not graph.buy(&"pottery", func(_cost: Dictionary) -> Variant: return null), "not a bool: no")
	check(not graph.is_unlocked(&"pottery"), "still locked")


func test_unlock_signals() -> void:
	var graph := _tree()
	var heard: Array[String] = []
	graph.unlocked.connect(func(id: StringName) -> void: heard.append("+%s" % id))
	graph.locked.connect(func(id: StringName) -> void: heard.append("-%s" % id))
	graph.availability_changed.connect(func() -> void: heard.append("available"))
	check(not graph.unlock(&"irrigation") and heard.is_empty(), "a failed unlock emits nothing")
	graph.unlock(&"farming")
	check(heard == (["+farming", "available"] as Array[String]), "unlocked, then availability_changed: %s" % [heard])
	check(graph.unlocked_ids() == ([&"farming"] as Array[StringName]), "unlocked_ids")
	heard.clear()
	check(graph.lock(&"farming"), "lock")
	check(heard == (["-farming", "available"] as Array[String]), "locked, then availability_changed: %s" % [heard])
	check(not graph.is_unlocked(&"farming"), "locked again")


func test_lock_rules() -> void:
	var graph := _tree()
	graph.unlock(&"farming")
	graph.unlock(&"irrigation")
	check(not graph.lock(&"pottery"), "not unlocked: false")
	check(not graph.lock(&"farming"), "an unlocked entry requires it: false")
	check(graph.is_unlocked(&"farming"), "nothing changed")
	check(graph.lock(&"irrigation") and graph.lock(&"farming"), "undo from the top down")
	check(graph.unlocked_ids().is_empty(), "all locked")


func test_unlock_order_and_available() -> void:
	var graph := _tree()
	check(graph.available_ids() == ([&"farming", &"masonry"] as Array[StringName]), "the roots at the start")
	graph.unlock(&"masonry")
	graph.unlock(&"farming")
	graph.unlock(&"pottery")
	check(
		graph.unlocked_ids() == ([&"masonry", &"farming", &"pottery"] as Array[StringName]),
		"unlocked_ids in the order unlocked: %s" % [graph.unlocked_ids()]
	)
	check(graph.available_ids() == ([&"irrigation", &"market"] as Array[StringName]), "available, in the order added")


func test_availability_changed_once_per_call() -> void:
	var graph := UnlockGraph.new()
	var count: Array[int] = [0]
	graph.availability_changed.connect(func() -> void: count[0] += 1)
	graph.add(&"a")
	check(count[0] == 1, "adding an entry that can be unlocked changes it")
	graph.add(&"b", [&"a"])
	check(count[0] == 1, "adding one that cannot does not")
	graph.unlock(&"a")
	check(count[0] == 2, "one per unlock")
	graph.restore([&"a", &"b"])
	check(count[0] == 3, "one per restore")
	graph.restore([])
	check(count[0] == 4, "restore([]) too")


func test_depth() -> void:
	var graph := _tree()
	check(graph.depth(&"farming") == 0 and graph.depth(&"masonry") == 0, "roots: 0")
	check(graph.depth(&"irrigation") == 1 and graph.depth(&"pottery") == 1, "one step: 1")
	check(graph.depth(&"aqueduct") == 2, "the longest chain: 2")
	check(graph.depth(&"market") == 2, "requires_any counts: after pottery")
	check(graph.depth(&"walls") == 0, "unknown: 0")
	graph.add(&"ghost", [&"nothing"])
	check(graph.depth(&"ghost") == 1, "an unknown requirement counts as 0")
	graph.add(&"late", [&"aqueduct"])
	check(graph.depth(&"late") == 3, "an entry added later")


func test_requirement_added_later() -> void:
	var graph := UnlockGraph.new()
	graph.add(&"aqueduct", [&"irrigation"])
	graph.add(&"market", [], {}, [&"pottery"])
	check(graph.problems().size() == 2, "unknown requirements are problems: %s" % [graph.problems()])
	check(graph.why_not(&"aqueduct") == "locked", "and they lock the entry")
	graph.add(&"irrigation")
	graph.add(&"pottery")
	check(graph.problems().is_empty(), "added later: fine")
	check(graph.unlock(&"irrigation") and graph.unlock(&"aqueduct"), "it plays")
	check(graph.unlock(&"pottery") and graph.unlock(&"market"), "both kinds")


func test_restore() -> void:
	var graph := _tree()
	var heard: Array[StringName] = []
	graph.unlocked.connect(func(id: StringName) -> void: heard.append(id))
	graph.locked.connect(func(id: StringName) -> void: heard.append(id))
	graph.unlock(&"masonry")
	heard.clear()
	graph.restore([&"farming", "irrigation", &"walls", &"farming"])
	check(heard.is_empty(), "restore emits no unlocked or locked")
	check(
		graph.unlocked_ids() == ([&"farming", &"irrigation"] as Array[StringName]),
		"exactly these, unknown skipped: %s" % [graph.unlocked_ids()]
	)
	check(not graph.is_unlocked(&"masonry"), "what was unlocked before is gone")
	graph.restore([&"aqueduct"])
	check(graph.is_unlocked(&"aqueduct"), "restore does not check the order rule")
	graph.restore([])
	check(graph.unlocked_ids().is_empty() and graph.can_unlock(&"farming"), "restore([]) locks everything")


func test_problems() -> void:
	var graph := UnlockGraph.new()
	check(graph.problems().is_empty(), "empty: fine")
	graph.add(&"a", [&"c"])
	graph.add(&"b", [&"a"])
	graph.add(&"c", [&"b"])
	graph.add(&"d", [&"d"])
	graph.add(&"e", [&"missing"])
	graph.add(&"f", [], {}, [&"g", &"lost"])
	graph.add(&"g", [&"f"])
	var found := graph.problems()
	check(found.size() == 5, "two circles, a self link and two unknown requirements: %s" % [found])
	check(found.has("d requires itself."), "requires itself")
	check(found.has("e requires missing, which is not an entry."), "unknown requirement")
	check(found.has("f requires lost, which is not an entry."), "unknown requirement of requires_any")
	check(found.has("a, b, c require each other in a circle: remove one of those links."), "the circle, once")
	check(found.has("f, g require each other in a circle: remove one of those links."), "also through requires_any")
	check(not graph.can_unlock(&"a") and not graph.can_unlock(&"d"), "nothing in a cycle can be unlocked")
	check(graph.depth(&"a") >= 1, "depth survives a cycle")


func test_to_dict_and_back() -> void:
	var graph := _tree()
	graph.unlock(&"masonry")
	graph.unlock(&"farming")
	var data := graph.to_dict()
	var unlocked_out: Array = data["unlocked"]
	var entries_out: Array = data["entries"]
	check(unlocked_out == ["masonry", "farming"] and entries_out.size() == 6, "plain data: %s" % [data])
	var aqueduct: Dictionary = entries_out[2]
	var expected := {
		"id": "aqueduct", "requires": ["irrigation", "masonry"], "requires_any": [], "cost": {"points": 4, "stone": 1}
	}
	check(aqueduct == expected, "an entry: %s" % [aqueduct])
	var market: Dictionary = entries_out[5]
	var any_out: Array = market["requires_any"]
	check(any_out == ["pottery", "masonry"], "requires_any is saved")
	var copy := UnlockGraph.from_dict(data)
	check(copy.to_dict() == data, "from_dict gives the same graph")
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(data))
	var through_json := UnlockGraph.from_dict(parsed)
	check(through_json.to_dict() == data, "also after JSON (amounts come back as floats)")
	check(through_json.cost_of(&"aqueduct")[&"stone"] == 1, "and are whole numbers again")
	check(through_json.can_unlock(&"market") and through_json.unlock(&"market"), "it plays on, both rules too")
	check(UnlockGraph.from_dict({}).ids().is_empty(), "an empty dictionary is an empty graph")
	var old := {"entries": [{"id": "a"}, {"id": "b", "requires": ["a"]}], "unlocked": ["a"]}
	check(UnlockGraph.from_dict(old).can_unlock(&"b"), "keys that are missing read as empty")


func test_to_dict_without_entries() -> void:
	var graph := _tree()
	graph.unlock(&"farming")
	graph.unlock(&"pottery")
	var state := graph.to_dict(false)
	check(state == {"unlocked": ["farming", "pottery"]}, "only what is unlocked: %s" % [state])
	var other := _tree()
	var unlocked_in: Array = state["unlocked"]
	other.restore(unlocked_in)
	check(other.unlocked_ids() == graph.unlocked_ids(), "restore on a graph with the same entries")
