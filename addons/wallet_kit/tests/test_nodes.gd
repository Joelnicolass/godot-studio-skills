extends "res://addons/wallet_kit/tests/wallet_test.gd"

## Wallet in a tree: the purse from the inspector, signals, live inspector changes, use_purse and warnings.


func _build() -> Wallet:
	var wallet := Wallet.new()
	wallet.start_amounts = {&"food": 2, &"gold": 1}
	wallet.limits = {&"food": 2}
	wallet.wildcard = &"gold"
	tree.root.add_child(wallet)
	return wallet


func test_purse_from_inspector() -> void:
	var wallet := _build()
	check(wallet.amount(&"food") == 2 and wallet.amount(&"gold") == 1, "start amounts")
	check(wallet.limit(&"food") == 2, "limits")
	check(wallet.can_pay({&"wood": 1}) and wallet.pay({&"wood": 1}), "the wildcard pays")
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
	wallet.wildcard = &""
	check(not wallet.can_pay({&"ore": 1}), "no wildcard any more")
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


func test_warnings() -> void:
	var wallet := Wallet.new()
	wallet.start_amounts = {&"food": 5, &"ore": -1}
	wallet.limits = {&"food": 2, &"wood": -3}
	wallet.wildcard_covers = [&"food"]
	var warnings := wallet._get_configuration_warnings()
	check(warnings.size() == 4, "above limit, negative start, negative limit, covers without wildcard: %s" % [warnings])
	wallet.wildcard = &"gold"
	wallet.wildcard_covers = [&"gold"]
	check(wallet._get_configuration_warnings().size() == 4, "a wildcard covering itself warns")
	wallet.free()
