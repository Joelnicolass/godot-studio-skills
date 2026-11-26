extends "res://addons/unlock_kit/tests/unlock_test.gd"

## UnlockTree and UnlockEntry in a scene tree: the graph from nested entries, requires_any, buy, signals per entry,
## live changes that keep what was unlocked, new_graph and use_graph, one graph per instance, reset, an entry with data
## of its own and the editor warnings.

const TECH_ENTRY := """@tool
extends "res://addons/unlock_kit/nodes/unlock_entry.gd"

@export var food := 2
"""


# Tree > Land (a plain Node) > Farming (start) > Irrigation > Aqueduct (+ Masonry); Tree > Masonry.
func _build() -> UnlockTree:
	var unlocks := UnlockTree.new()
	unlocks.name = "Tree"
	var land := Node.new()
	land.name = "Land"
	unlocks.add_child(land)
	var farming := _entry("Farming")
	farming.start_unlocked = true
	land.add_child(farming)
	var irrigation := _entry("Irrigation", {&"points": 2})
	farming.add_child(irrigation)
	var aqueduct := _entry("Aqueduct", {&"points": 4})
	irrigation.add_child(aqueduct)
	var masonry := _entry("Masonry", {&"points": 2})
	unlocks.add_child(masonry)
	aqueduct.requires = [masonry]
	tree.root.add_child(unlocks)
	return unlocks


func _entry(entry_name: String, cost: Dictionary[StringName, int] = {}) -> UnlockEntry:
	var entry := UnlockEntry.new()
	entry.name = entry_name
	entry.cost = cost
	return entry


func test_graph_from_nested_entries() -> void:
	var unlocks := _build()
	var ids: Array[StringName] = [&"Farming", &"Irrigation", &"Aqueduct", &"Masonry"]
	check(unlocks.graph.ids() == ids, "entries in tree order, ids from the names: %s" % [unlocks.graph.ids()])
	check(unlocks.requires(&"Farming").is_empty(), "a plain Node adds no requirement")
	check(unlocks.requires(&"Irrigation") == ([&"Farming"] as Array[StringName]), "an entry requires its parent entry")
	check(
		unlocks.requires(&"Aqueduct") == ([&"Irrigation", &"Masonry"] as Array[StringName]),
		"the parent entry, then the cross link"
	)
	check(unlocks.cost_of(&"Aqueduct") == ({&"points": 4} as Dictionary[StringName, int]), "cost")
	check(unlocks.is_unlocked(&"Farming") and unlocks.unlocked_ids().size() == 1, "start_unlocked")
	check(unlocks.available_ids() == ([&"Irrigation", &"Masonry"] as Array[StringName]), "available")
	check(unlocks.entries().size() == 4 and unlocks.entry(&"Masonry").name == "Masonry", "entries and entry")
	check(unlocks.entry(&"walls") == null, "no entry: null")
	unlocks.entry(&"Masonry").title = "Stonework"
	check(unlocks.title_of(&"Masonry") == "Stonework" and unlocks.title_of(&"Irrigation") == "Irrigation", "title_of")
	check(unlocks.title_of(&"walls") == "walls", "title_of an id without an entry is the id")
	check(unlocks._get_configuration_warnings().is_empty(), "no tree warnings")
	for entry in unlocks.entries():
		check(entry._get_configuration_warnings().is_empty(), "no warnings on %s" % entry.name)
	unlocks.free()


func test_buy_in_one_call() -> void:
	var unlocks := _build()
	var points: Array[int] = [2]
	var pay := func(cost: Dictionary) -> bool:
		var price: int = cost.get(&"points", 0)
		if points[0] < price:
			return false
		points[0] -= price
		return true
	check(unlocks.buy(&"Irrigation", pay) and points[0] == 0, "buy: pays 2 and unlocks")
	check(unlocks.why_not(&"Aqueduct") == "locked", "Aqueduct still misses Masonry")
	check(unlocks.missing(&"Aqueduct") == ([&"Masonry"] as Array[StringName]), "missing")
	check(not unlocks.buy(&"Masonry", pay) and not unlocks.is_unlocked(&"Masonry"), "cannot pay: nothing unlocked")
	check(not unlocks.unlock(&"Aqueduct"), "unlock is refused without an error")
	check(unlocks.unlock(&"Masonry"), "unlock alone takes no cost")
	unlocks.free()


func test_requires_any_from_entries() -> void:
	var unlocks := _build()
	var market := _entry("Market", {&"points": 3})
	unlocks.add_child(market)
	market.requires_any = [unlocks.entry(&"Irrigation"), unlocks.entry(&"Masonry"), unlocks.get_child(0)]
	check(
		unlocks.requires_any(&"Market") == ([&"Irrigation", &"Masonry"] as Array[StringName]),
		"requires_any from the entries, a plain Node left out: %s" % [unlocks.requires_any(&"Market")]
	)
	check(unlocks.requires(&"Market").is_empty(), "no requirement of all")
	check(unlocks.why_not(&"Market") == "locked", "none unlocked: locked")
	check(market._get_configuration_warnings().size() == 1, "the plain Node in requires_any is a warning")
	unlocks.unlock(&"Masonry")
	check(unlocks.can_unlock(&"Market"), "one of them is enough")
	check(unlocks.graph.depth(&"Market") == 2, "after its deepest one")
	unlocks.free()


func test_cost_changed_in_the_game() -> void:
	var unlocks := _build()
	var points: Array[int] = [10]
	var pay := func(cost: Dictionary) -> bool:
		var price: int = cost.get(&"points", 0)
		points[0] -= price
		return true
	unlocks.buy(&"Irrigation", pay)
	unlocks.entry(&"Masonry").cost = {&"points": 5}
	check(unlocks.is_unlocked(&"Irrigation"), "what was bought stays bought")
	check(unlocks.buy(&"Masonry", pay) and points[0] == 3, "the next buy charges the new cost (2 + 5)")
	unlocks.free()


func test_signals_per_entry() -> void:
	var unlocks := _build()
	var heard: Array[String] = []
	var irrigation := unlocks.entry(&"Irrigation")
	irrigation.unlocked.connect(func() -> void: heard.append("entry+"))
	irrigation.locked.connect(func() -> void: heard.append("entry-"))
	unlocks.unlocked.connect(func(id: StringName) -> void: heard.append("+%s" % id))
	unlocks.locked.connect(func(id: StringName) -> void: heard.append("-%s" % id))
	unlocks.availability_changed.connect(func() -> void: heard.append("available"))
	unlocks.unlock(&"Irrigation")
	check(heard == (["+Irrigation", "entry+", "available"] as Array[String]), "unlock: %s" % [heard])
	check(irrigation.is_unlocked() and irrigation.entry_id() == &"Irrigation", "the entry asks its tree")
	heard.clear()
	unlocks.lock(&"Irrigation")
	check(heard == (["-Irrigation", "entry-", "available"] as Array[String]), "lock: %s" % [heard])
	unlocks.free()


func test_live_changes_keep_unlocked() -> void:
	var unlocks := _build()
	var rebuilt: Array[int] = [0]
	unlocks.rebuilt.connect(func() -> void: rebuilt[0] += 1)
	unlocks.unlock(&"Irrigation")
	var aqueduct := unlocks.entry(&"Aqueduct")
	aqueduct.cost = {&"points": 1}
	check(unlocks.cost_of(&"Aqueduct") == ({&"points": 1} as Dictionary[StringName, int]), "a new cost applies at once")
	check(unlocks.is_unlocked(&"Irrigation") and unlocks.is_unlocked(&"Farming"), "what was unlocked stays")
	check(rebuilt[0] == 1, "rebuilt once")
	unlocks.entry(&"Masonry").id = &"stone"
	check(unlocks.requires(&"Aqueduct") == ([&"Irrigation", &"stone"] as Array[StringName]), "a new id follows")
	aqueduct.requires = []
	check(unlocks.can_unlock(&"Aqueduct"), "without the cross link it can be unlocked")
	var canals := _entry("Canals", {&"points": 1})
	aqueduct.add_child(canals)
	check(unlocks.requires(&"Canals") == ([&"Aqueduct"] as Array[StringName]), "an entry added by code")
	check(unlocks.graph.ids().size() == 5, "five entries")
	canals.get_parent().remove_child(canals)
	canals.free()
	check(not unlocks.graph.has(&"Canals"), "an entry taken out")
	var before: int = rebuilt[0]
	var farming := unlocks.entry(&"Farming")
	farming.description = "a"
	farming.title = "b"
	await tree.process_frame
	check(rebuilt[0] == before + 1, "several changes in a frame: one rebuild (%d)" % (rebuilt[0] - before))
	check(unlocks.is_unlocked(&"Irrigation"), "still unlocked")
	unlocks.move_child(unlocks.get_child(0), 1)
	check(unlocks.graph.ids()[0] == &"stone", "the Land branch moved last: Masonry comes first")
	unlocks.free()


func test_use_graph() -> void:
	var unlocks := _build()
	var rebuilt: Array[int] = [0]
	unlocks.rebuilt.connect(func() -> void: rebuilt[0] += 1)
	var rules := UnlockGraph.new()
	rules.add(&"Masonry")
	rules.add(&"Walls", [&"Masonry"])
	unlocks.use_graph(rules)
	check(rebuilt[0] == 1 and unlocks.graph == rules, "use_graph emits rebuilt")
	check(unlocks.can_unlock(&"Masonry") and not unlocks.can_unlock(&"Farming"), "the rules' graph decides")
	var heard: Array[String] = []
	unlocks.entry(&"Masonry").unlocked.connect(func() -> void: heard.append("entry+"))
	rules.unlock(&"Masonry")
	check(unlocks.is_unlocked(&"Masonry") and heard == (["entry+"] as Array[String]), "entries still hear by id")
	unlocks.entry(&"Masonry").title = "Stonework"
	check(unlocks.title_of(&"Masonry") == "Stonework", "and give titles")
	check(unlocks.graph == rules and rules.ids().size() == 2, "an entry change never touches the rules' graph")
	unlocks.reset()
	check(rules.unlocked_ids().is_empty(), "reset with the rules' graph locks everything")
	unlocks.use_own_graph()
	check(
		unlocks.graph != rules and unlocks.unlocked_ids() == ([&"Farming"] as Array[StringName]), "back, at the start"
	)
	check(rebuilt[0] >= 3, "use_own_graph emits rebuilt too")
	unlocks.free()


func test_use_graph_warns_about_ids_without_entries() -> void:
	var unlocks := _build()
	var rules := UnlockGraph.new()
	rules.add(&"Masonry")
	rules.add(&"Walls", [&"Masonry"])
	rules.add(&"Mill")
	var heard := _Warnings.new()
	OS.add_logger(heard)
	unlocks.use_graph(rules)
	OS.remove_logger(heard)
	check(heard.lines.size() == 1, "one warning: %s" % [heard.lines])
	check(heard.lines.size() == 1 and heard.lines[0].contains("Walls, Mill"), "naming the ids: %s" % [heard.lines])
	check(unlocks.title_of(&"Walls") == "Walls", "the id is the title")
	var fine := _Warnings.new()
	OS.add_logger(fine)
	unlocks.use_graph(unlocks.new_graph())
	OS.remove_logger(fine)
	check(fine.lines.is_empty(), "a graph from the entries: no warning")
	unlocks.free()


func test_new_graph_per_player() -> void:
	var unlocks := _build()
	unlocks.unlock(&"Irrigation")
	var ana := unlocks.new_graph()
	var beto := unlocks.new_graph()
	check(ana != beto and ana != unlocks.graph, "a new graph each call")
	check(ana.ids() == unlocks.graph.ids(), "the entries of the tree")
	check(ana.requires(&"Aqueduct") == ([&"Irrigation", &"Masonry"] as Array[StringName]), "with their requirements")
	check(ana.unlocked_ids() == ([&"Farming"] as Array[StringName]), "at the start, not what the tree has unlocked")
	ana.unlock(&"Masonry")
	check(not beto.is_unlocked(&"Masonry"), "each player its own")
	unlocks.use_graph(ana)
	check(unlocks.is_unlocked(&"Masonry"), "the tree shows ana's")
	unlocks.use_graph(beto)
	check(not unlocks.is_unlocked(&"Masonry"), "then beto's")
	unlocks.entry(&"Masonry").cost = {&"points": 9}
	check(
		ana.cost_of(&"Masonry") == ({&"points": 2} as Dictionary[StringName, int]), "an entry change later: untouched"
	)
	unlocks.free()


func test_reset_keeps_start() -> void:
	var unlocks := _build()
	unlocks.unlock(&"Irrigation")
	unlocks.unlock(&"Masonry")
	var count: Array[int] = [0]
	unlocks.availability_changed.connect(func() -> void: count[0] += 1)
	unlocks.reset()
	check(unlocks.unlocked_ids() == ([&"Farming"] as Array[StringName]), "back to the start_unlocked entries")
	check(count[0] == 1, "one availability_changed")
	unlocks.restore(["Farming", "Irrigation"])
	check(unlocks.is_unlocked(&"Irrigation"), "restore")
	var saved: Array = unlocks.to_dict()["unlocked"]
	check(saved == ["Farming", "Irrigation"], "to_dict")
	check(unlocks.to_dict(false) == {"unlocked": ["Farming", "Irrigation"]}, "to_dict(false): only what is unlocked")
	unlocks.free()


func test_start_unlocked_under_a_locked_entry() -> void:
	var unlocks := _build()
	var aqueduct := unlocks.entry(&"Aqueduct")
	aqueduct.start_unlocked = true
	check(unlocks.is_unlocked(&"Aqueduct") and not unlocks.is_unlocked(&"Irrigation"), "it starts unlocked anyway")
	var warnings := aqueduct._get_configuration_warnings()
	check(warnings.size() == 2, "Irrigation and Masonry do not start unlocked: %s" % [warnings])
	check(not unlocks.lock(&"Irrigation"), "its parent cannot be locked: it was never unlocked")
	unlocks.entry(&"Irrigation").start_unlocked = true
	unlocks.entry(&"Masonry").start_unlocked = true
	check(aqueduct._get_configuration_warnings().is_empty(), "every requirement starts unlocked: fine")
	var market := _entry("Market")
	market.start_unlocked = true
	unlocks.add_child(market)
	market.requires_any = [unlocks.entry(&"Farming"), unlocks.entry(&"Irrigation")]
	check(market._get_configuration_warnings().is_empty(), "one of requires_any starts unlocked: fine")
	unlocks.entry(&"Farming").start_unlocked = false
	unlocks.entry(&"Irrigation").start_unlocked = false
	check(market._get_configuration_warnings().size() == 1, "none of requires_any starts unlocked")
	unlocks.free()


func test_tree_leaving_does_not_rebuild() -> void:
	var unlocks := _build()
	unlocks.unlock(&"Irrigation")
	await tree.process_frame
	var rebuilt: Array[int] = [0]
	unlocks.rebuilt.connect(func() -> void: rebuilt[0] += 1)
	tree.root.remove_child(unlocks)
	await tree.process_frame
	await tree.process_frame
	check(rebuilt[0] == 0, "the whole tree left with its entries: no rebuild")
	tree.root.add_child(unlocks)
	check(unlocks.is_unlocked(&"Irrigation") and unlocks.graph.ids().size() == 4, "back in: the same state")
	var entry := unlocks.entry(&"Masonry")
	entry.get_parent().remove_child(entry)
	check(not unlocks.graph.has(&"Masonry"), "one entry leaving: rebuilt")
	entry.free()
	unlocks.free()


func test_entry_with_data_of_its_own() -> void:
	var unlocks := _build()
	var script := GDScript.new()
	script.source_code = TECH_ENTRY
	check(script.reload() == OK, "a script that extends UnlockEntry")
	var granary := Node.new()
	granary.set_script(script)
	granary.name = "Granary"
	unlocks.entry(&"Farming").add_child(granary)
	check(granary is UnlockEntry, "it is an entry")
	check(unlocks.requires(&"Granary") == ([&"Farming"] as Array[StringName]), "it requires its parent entry")
	var found := unlocks.entry(&"Granary")
	var food: int = found.get(&"food")
	check(found == granary and food == 2, "the rules read its own field")
	unlocks.free()


func test_one_graph_per_instance() -> void:
	var source := _build()
	for node in _descendants(source):
		node.owner = source
	var scene := PackedScene.new()
	check(scene.pack(source) == OK, "packed")
	source.free()
	var ana := scene.instantiate() as UnlockTree
	var beto := scene.instantiate() as UnlockTree
	tree.root.add_child(ana)
	tree.root.add_child(beto)
	check(ana.entry(&"Aqueduct").requires.size() == 1, "the cross link survives packing")
	ana.unlock(&"Irrigation")
	check(ana.is_unlocked(&"Irrigation") and not beto.is_unlocked(&"Irrigation"), "each instance owns its graph")
	check(ana.graph != beto.graph, "two graphs")
	ana.free()
	beto.free()


func test_inner_tree_is_its_own() -> void:
	var unlocks := _build()
	var inner := UnlockTree.new()
	inner.add_child(_entry("Secret"))
	unlocks.entry(&"Masonry").add_child(inner)
	check(not unlocks.graph.has(&"Secret") and inner.graph.has(&"Secret"), "an entry belongs to its nearest tree")
	check(inner.requires(&"Secret").is_empty(), "and requires nothing of the outer tree")
	unlocks.free()


func test_warnings() -> void:
	var lonely := _entry("Lonely")
	tree.root.add_child(lonely)
	check(lonely._get_configuration_warnings().size() == 1, "an entry outside a tree")
	var empty := UnlockTree.new()
	tree.root.add_child(empty)
	check(empty._get_configuration_warnings().size() == 1, "a tree without entries")
	var unlocks := _build()
	var farming := unlocks.entry(&"Farming")
	var masonry := unlocks.entry(&"Masonry")
	masonry.requires = [null, lonely, unlocks.get_child(0)]
	masonry.requires_any = [null]
	masonry.cost = {&"points": -1}
	var warnings := masonry._get_configuration_warnings()
	check(warnings.size() == 5, "two empty slots, one outside the tree, a plain Node, a negative cost: %s" % [warnings])
	check(unlocks.requires(&"Masonry") == ([&"Lonely"] as Array[StringName]), "only entries become requirements")
	check(unlocks.cost_of(&"Masonry").is_empty(), "the negative amount is left out of the graph")
	check(unlocks._get_configuration_warnings().size() == 1, "the tree lists the requirement that is not an entry")
	masonry.requires = []
	masonry.requires_any = []
	masonry.cost = {}
	farming.start_unlocked = false
	farming.requires = [unlocks.entry(&"Aqueduct")]
	for id: StringName in [&"Farming", &"Irrigation", &"Aqueduct"]:
		var found := unlocks.entry(id)._get_configuration_warnings()
		check(found.size() == 1 and found[0].contains("circle"), "%s is in the circle: %s" % [id, found])
	check(masonry._get_configuration_warnings().is_empty(), "Masonry is not")
	check(unlocks._get_configuration_warnings().size() == 1, "the tree lists the circle")
	farming.requires = []
	var twin := _entry("Twin")
	twin.id = &"Masonry"
	unlocks.add_child(twin)
	check(twin._get_configuration_warnings().size() == 1, "a repeated id: on the one left out")
	check(masonry._get_configuration_warnings().is_empty(), "the first one counts, with no warning")
	check(unlocks.graph.ids().size() == 4, "the first one wins")
	lonely.free()
	empty.free()
	unlocks.free()


func _descendants(node: Node) -> Array[Node]:
	var list: Array[Node] = []
	for child in node.get_children():
		list.append(child)
		list.append_array(_descendants(child))
	return list


# Catches the warnings Godot prints while it is added (push_warning).
class _Warnings:
	extends Logger
	var lines: Array[String] = []

	func _log_error(
		_function: String,
		_file: String,
		_line: int,
		code: String,
		rationale: String,
		_editor_notify: bool,
		error_type: int,
		_script_backtraces: Array[ScriptBacktrace],
	) -> void:
		if error_type == ERROR_TYPE_WARNING:
			lines.append(code + rationale)
