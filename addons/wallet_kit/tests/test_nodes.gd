extends "res://addons/wallet_kit/tests/wallet_test.gd"

## Wallet in a tree: the purse from the inspector, signals, live inspector changes, use_purse and warnings.


func _build() -> Wallet:
	var wallet := Wallet.new()
	wallet.start_amounts = {&"food": 2, &"gold": 1}
	wallet.limits = {&"food": 2}
	wallet.substitutes = [_rule(&"gold")]
	tree.root.add_child(wallet)
	return wallet


func _rule(key: StringName, covers: Array[StringName] = [], rate := 1) -> WalletSubstitute:
	var rule := WalletSubstitute.new()
	rule.key = key
	rule.covers = covers
	rule.rate = rate
	return rule


func test_purse_from_inspector() -> void:
	var wallet := _build()
	check(wallet.amount(&"food") == 2 and wallet.amount(&"gold") == 1, "start amounts")
	check(wallet.limit(&"food") == 2, "limits")
	check(wallet.can_pay({&"wood": 1}) and wallet.pay({&"wood": 1}), "the substitute pays")
	check(wallet.amount(&"gold") == 0, "with gold")
	check(wallet._get_configuration_warnings().is_empty(), "no warnings")
	wallet.free()


func test_signals() -> void:
	var wallet := _build()
	var heard: Array[String] = []
	wallet.changed.connect(func(key: StringName, value: int) -> void: heard.append("%s=%d" % [key, value]))
	wallet.overflowed.connect(func(key: StringName, lost: int) -> void: heard.append("%s-%d" % [key, lost]))
	var lost := wallet.add({&"food": 1, &"ore": 2})
	check(lost == ({&"food": 1} as Dictionary[StringName, int]), "add returns the loss")
	check(heard == (["food-1", "ore=2"] as Array[String]), "the wallet relays the purse: %s" % [heard])
	wallet.free()


func test_live_inspector() -> void:
	var wallet := _build()
	wallet.add({&"wood": 5})
	wallet.limits = {&"food": 2, &"wood": 3}
	check(wallet.amount(&"wood") == 3, "a new limit cuts what is there")
	wallet.limits = {}
	check(wallet.limit(&"food") == -1, "a key left out has no limit")
	wallet.substitutes = []
	check(not wallet.can_pay({&"ore": 1}), "no substitute any more")
	wallet.start_amounts = {&"ore": 4}
	check(wallet.amount(&"ore") == 4 and wallet.amount(&"wood") == 0, "new start amounts build the purse again")
	wallet.free()


func test_use_purse() -> void:
	var wallet := _build()
	var rules := Purse.new({&"wood": 3})
	wallet.use_purse(rules)
	var heard: Array[int] = []
	wallet.changed.connect(func(_key: StringName, value: int) -> void: heard.append(value))
	rules.add({&"wood": 1})
	check(wallet.amount(&"wood") == 4 and heard == ([4] as Array[int]), "the wallet shows the rules' purse")
	wallet.limits = {&"wood": 1}
	check(rules.amount(&"wood") == 4, "the inspector does not touch a purse it does not own")
	wallet.use_own_purse()
	rules.add({&"wood": 1})
	check(heard.size() == 1 and wallet.amount(&"food") == 2, "back to its own purse")
	wallet.free()


func test_substitutes_from_the_inspector() -> void:
	var wallet := _build()
	check(wallet.substitutes_for(&"wood").size() == 1, "substitutes_for")
	var two: Array[WalletSubstitute] = [_rule(&"food", [&"wood"], 2), _rule(&"gold")]
	wallet.substitutes = two
	check(wallet.purse.substitutes().size() == 2, "both reached the purse")
	var plan := wallet.payment_for({&"wood": 1, &"ore": 1})
	check(plan == ({&"food": 2, &"gold": 1} as Dictionary[StringName, int]), "in list order: %s" % [plan])
	check(wallet.amount(&"food") == 2, "applying does not rebuild the purse")
	wallet.free()


func test_a_resource_changed_live() -> void:
	var wallet := _build()
	var food := _rule(&"food", [&"wood"], 2)
	wallet.substitutes = [food]
	check(wallet.can_pay({&"wood": 1}) and not wallet.can_pay({&"wood": 2}), "2 food cover 1 wood")
	food.rate = 1
	check(wallet.can_pay({&"wood": 2}), "the new rate applies at once")
	food.covers = [&"ore"]
	check(not wallet.can_pay({&"wood": 1}) and wallet.can_pay({&"ore": 2}), "so does a new covers list")
	check(food.changed.get_connections().size() == 1, "the wallet listens once")
	wallet.substitutes = []
	check(food.changed.get_connections().is_empty(), "a resource that left the list is no longer heard")
	wallet.free()


func test_use_purse_is_not_overwritten() -> void:
	var wallet := _build()
	var rules := Purse.new({&"wood": 1})
	rules.add_substitute(&"wood", [&"ore"], 3)
	wallet.use_purse(rules)
	var gold := _rule(&"gold")
	wallet.substitutes = [gold]
	gold.rate = 4
	check(
		rules.substitutes().size() == 1 and rules.substitutes()[0]["key"] == &"wood", "the rules' purse keeps its own"
	)
	wallet.use_own_purse()
	check(
		wallet.purse.substitutes().size() == 1 and wallet.purse.substitutes()[0]["rate"] == 4, "back to the inspector"
	)
	wallet.free()


func test_warnings() -> void:
	var wallet := Wallet.new()
	wallet.start_amounts = {&"food": 5, &"ore": -1}
	wallet.limits = {&"food": 2, &"wood": -3}
	check(wallet._get_configuration_warnings().size() == 3, "above limit, negative start, negative limit")
	wallet.substitutes = [null, _rule(&""), _rule(&"gold", [&"gold"]), _rule(&"wood"), _rule(&"wood")]
	var warnings := wallet._get_configuration_warnings()
	check(warnings.size() == 3 + 4, "empty slot, no key, covers itself, a repeated rule: %s" % [warnings])
	wallet.substitutes = [_rule(&"gold", [&"wood", &"food"]), _rule(&"gold", [&"food", &"wood"])]
	check(wallet._get_configuration_warnings().size() == 3 + 1, "the same covers in another order is a repeat")
	wallet.substitutes = [_rule(&"gold", [&"wood"]), _rule(&"gold", [&"food"]), _rule(&"wood", [&"gold"], 2)]
	check(wallet._get_configuration_warnings().size() == 3, "different rules for the same key are fine")
	wallet.free()


func test_rebuilt() -> void:
	var wallet := _build()
	var count := [0]
	wallet.rebuilt.connect(func() -> void: count[0] += 1)
	var ana := Purse.new({&"wood": 1})
	var beto := Purse.new({&"wood": 5})
	wallet.use_purse(ana)
	check(count[0] == 1 and wallet.amount(&"wood") == 1, "use_purse emits rebuilt")
	wallet.use_purse(beto)
	check(count[0] == 2 and wallet.amount(&"wood") == 5, "switching players emits it again")
	wallet.use_own_purse()
	check(count[0] == 3, "use_own_purse too")
	wallet.start_amounts = {&"ore": 1}
	check(count[0] == 4, "and new start amounts")
	wallet.free()
