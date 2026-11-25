extends "res://addons/wallet_kit/tests/wallet_test.gd"

## Purse alone, no tree: amounts, limits and what they cut, paying, the substitutes, errors and to_dict.


func test_start_and_limits() -> void:
	var purse := Purse.new({&"food": 5, &"wood": 1}, {&"food": 2})
	check(purse.amount(&"food") == 2, "start amounts are cut at the limit: %d" % purse.amount(&"food"))
	check(purse.amount(&"ore") == 0, "a key never added is 0")
	check(purse.limit(&"wood") == -1 and not purse.has_limit(&"wood"), "no limit: -1")
	check(purse.keys() == ([&"food", &"wood"] as Array[StringName]), "keys sorted: %s" % [purse.keys()])


func test_add_reports_what_is_lost() -> void:
	var purse := Purse.new({&"food": 1}, {&"food": 2, &"wood": 7})
	var lost_heard: Array[String] = []
	purse.overflowed.connect(func(key: StringName, lost: int) -> void: lost_heard.append("%s %d" % [key, lost]))
	var changes: Array[String] = []
	purse.changed.connect(func(key: StringName, value: int) -> void: changes.append("%s %d" % [key, value]))
	var lost := purse.add({&"food": 3, &"wood": 2, &"ore": 0})
	check(lost == ({&"food": 2} as Dictionary[StringName, int]), "add returns what did not fit: %s" % [lost])
	check(purse.amount(&"food") == 2 and purse.amount(&"wood") == 2, "the rest is in")
	check(lost_heard == (["food 2"] as Array[String]), "overflowed once: %s" % [lost_heard])
	check(changes == (["food 2", "wood 2"] as Array[String]), "changed per key, sorted: %s" % [changes])
	check(purse.add({"wood": 1}).is_empty() and purse.amount(&"wood") == 3, "String keys work too")
	var again := purse.add({&"food": 1})
	check(again == ({&"food": 1} as Dictionary[StringName, int]), "full: all of it is lost")
	check(changes.size() == 3, "no changed when the amount stays the same")


func test_pay() -> void:
	var purse := Purse.new({&"wood": 2, &"ore": 1})
	check(purse.can_pay({&"wood": 2, &"ore": 1}), "can pay what it has")
	check(not purse.pay({&"wood": 3}), "cannot pay more")
	check(purse.amount(&"wood") == 2 and purse.amount(&"ore") == 1, "a failed pay changes nothing")
	check(purse.pay({&"wood": 1, &"ore": 1}), "pays")
	check(purse.amount(&"wood") == 1 and purse.amount(&"ore") == 0, "and takes it")
	check(purse.can_pay({}) and purse.pay({}), "an empty cost is free")


func test_substitute_one_to_one() -> void:
	var purse := Purse.new({&"wood": 1, &"gold": 2})
	purse.add_substitute(&"gold")
	check(purse.can_pay({&"wood": 2, &"ore": 1}), "gold covers 1 wood and 1 ore")
	var plan := purse.payment_for({&"wood": 2, &"ore": 1})
	check(plan == ({&"gold": 2, &"wood": 1} as Dictionary[StringName, int]), "payment_for: %s" % [plan])
	check(not purse.can_pay({&"wood": 2, &"ore": 2}), "but not 3 missing with 2 gold")
	check(purse.payment_for({&"ore": 5}).is_empty(), "payment_for is empty when it cannot be paid")
	check(purse.payment_for({}).is_empty() and purse.can_pay({}), "a free cost is empty and payable")
	check(purse.pay({&"wood": 2, &"ore": 1}), "pays with the substitute")
	check(purse.amount(&"wood") == 0 and purse.amount(&"gold") == 0, "it took wood first, then gold")
	var plain := Purse.new({&"wood": 1})
	check(not plain.can_pay({&"wood": 2}), "no substitute: nothing covers")


func test_substitute_covers_list() -> void:
	var purse := Purse.new({&"gold": 5})
	purse.add_substitute(&"gold", [&"food", &"wood"])
	check(purse.can_pay({&"wood": 2}), "covers wood")
	check(not purse.can_pay({&"culture": 1}), "but not a key out of its list")
	check(
		purse.substitutes_for(&"wood").size() == 1 and purse.substitutes_for(&"culture").is_empty(), "substitutes_for"
	)
	check(purse.substitutes_for(&"gold").is_empty(), "a substitute never covers its own key")
	check(not purse.can_pay({&"gold": 6}), "asking gold more than there is: nothing covers gold with gold")


func test_substitute_rate() -> void:
	var purse := Purse.new({&"wood": 3})
	purse.add_substitute(&"wood", [&"gold"], 2)
	check(purse.can_pay({&"gold": 1}), "2 wood cover 1 gold")
	check(purse.payment_for({&"gold": 1}) == ({&"wood": 2} as Dictionary[StringName, int]), "it takes 2 wood")
	check(not purse.can_pay({&"gold": 2}), "3 wood cover 1 gold, not 1.5")
	purse.set_amount(&"wood", 4)
	check(purse.can_pay({&"gold": 2}), "4 wood cover 2 gold")
	check(purse.pay({&"gold": 2}) and purse.amount(&"wood") == 0, "paid with all 4")


func test_substitute_own_stock_first() -> void:
	# The cost asks wood directly: gold, a substitute for wood, must not spend what the cost asks of it.
	var purse := Purse.new({&"wood": 1, &"gold": 3})
	purse.add_substitute(&"gold")
	check(not purse.can_pay({&"gold": 3, &"wood": 3}), "gold 3 is asked directly, 2 wood missing, 0 gold left")
	check(purse.can_pay({&"gold": 2, &"wood": 2}), "gold 2 asked, 1 wood missing, 1 gold left")
	check(
		purse.payment_for({&"gold": 2, &"wood": 2}) == ({&"gold": 3, &"wood": 1} as Dictionary[StringName, int]),
		"one entry per key"
	)


func test_substitute_list_order() -> void:
	var purse := Purse.new({&"gold": 5, &"silver": 5})
	purse.add_substitute(&"silver")
	purse.add_substitute(&"gold")
	var plan := purse.payment_for({&"wood": 3})
	check(plan == ({&"silver": 3} as Dictionary[StringName, int]), "the first substitute pays first: %s" % [plan])
	purse.set_amount(&"silver", 2)
	plan = purse.payment_for({&"wood": 3})
	check(plan == ({&"gold": 1, &"silver": 2} as Dictionary[StringName, int]), "then the second: %s" % [plan])
	check(
		purse.pay({&"wood": 3}) and purse.amount(&"silver") == 0 and purse.amount(&"gold") == 4, "and pay does the same"
	)


func test_substitute_same_key_two_rates() -> void:
	var purse := Purse.new({&"gold": 5})
	purse.add_substitute(&"gold", [&"ore"], 1)
	purse.add_substitute(&"gold", [&"culture"], 3)
	check(purse.payment_for({&"ore": 2}) == ({&"gold": 2} as Dictionary[StringName, int]), "gold covers ore at 1")
	check(purse.payment_for({&"culture": 1}) == ({&"gold": 3} as Dictionary[StringName, int]), "and culture at 3")
	check(purse.can_pay({&"ore": 2, &"culture": 1}), "2 + 3 = 5 gold")
	check(not purse.can_pay({&"ore": 3, &"culture": 1}), "they share the same stock: 3 + 3 = 6 is too much")


func test_substitute_covers_a_substitute_key() -> void:
	var purse := Purse.new({&"wood": 4})
	purse.add_substitute(&"gold")
	purse.add_substitute(&"wood", [&"gold"], 2)
	check(
		purse.payment_for({&"gold": 2}) == ({&"wood": 4} as Dictionary[StringName, int]), "wood covers the missing gold"
	)
	check(purse.pay({&"gold": 2}) and purse.amount(&"wood") == 0, "paid")
	var chain := Purse.new({&"food": 4})
	chain.add_substitute(&"wood", [&"gold"], 2)
	chain.add_substitute(&"food", [&"wood"], 1)
	check(not chain.can_pay({&"gold": 1}), "no chains: wood that is not in the purse cannot be made out of food")


func test_substitute_not_enough_changes_nothing() -> void:
	var purse := Purse.new({&"wood": 1, &"gold": 1})
	purse.add_substitute(&"gold")
	var heard := [0]
	purse.changed.connect(func(_key: StringName, _value: int) -> void: heard[0] += 1)
	var before := purse.amounts()
	check(not purse.pay({&"wood": 2, &"ore": 1}), "2 missing with 1 gold")
	check(purse.amounts() == before and heard[0] == 0, "the same amounts and no signal")


func test_payment_for_is_what_pay_takes() -> void:
	var costs: Array[Dictionary] = [{&"wood": 3, &"ore": 1}, {&"gold": 2, &"food": 4}, {&"culture": 2, &"wood": 1}]
	for cost in costs:
		var purse := Purse.new({&"wood": 1, &"gold": 2, &"food": 5, &"ore": 0, &"culture": 1})
		purse.add_substitute(&"food", [&"wood"], 2)
		purse.add_substitute(&"gold", [&"ore", &"culture"])
		var plan := purse.payment_for(cost)
		check(plan == purse.payment_for(cost), "stable between calls")
		var before := purse.amounts()
		var paid := purse.pay(cost)
		check(paid != plan.is_empty(), "payable when there is a plan: %s" % [cost])
		if paid:
			for key in before:
				check(before[key] - purse.amount(key) == int(plan.get(key, 0)), "%s: pay took what the plan said" % key)
	var one := Purse.new({&"gold": 2})
	one.add_substitute(&"gold")
	check(str(one.payment_for({&"wood": 1, &"ore": 1})) == str(one.payment_for({&"ore": 1, &"wood": 1})), "same order")


func test_substitute_errors() -> void:
	var purse := Purse.new()
	purse.add_substitute(&"gold", [], 0)
	purse.add_substitute(&"")
	purse.add_substitute(&"gold", [&"gold"])
	check(purse.substitutes().is_empty(), "rate 0, an empty key and a self cover add nothing")
	purse.add_substitute(&"gold", [&"ore"], 2)
	var list := purse.substitutes()
	check(list.size() == 1 and list[0]["key"] == &"gold" and list[0]["rate"] == 2, "a valid one is kept: %s" % [list])
	list[0]["rate"] = 9
	check(purse.substitutes()[0]["rate"] == 2, "substitutes() is a copy")
	purse.clear_substitutes()
	check(purse.substitutes().is_empty(), "clear_substitutes")


func test_negative_is_an_error() -> void:
	var purse := Purse.new({&"wood": 3})
	check(purse.add({&"wood": -1, &"ore": 2}).is_empty(), "a negative gain adds nothing")
	check(purse.amount(&"ore") == 0 and purse.amount(&"wood") == 3, "not even the other keys")
	check(not purse.pay({&"wood": -1}) and not purse.can_pay({&"wood": -1}), "a negative cost is not paid")
	check(purse.set_amount(&"wood", -2) == 0 and purse.amount(&"wood") == 3, "set_amount refuses negatives")


func test_set_limit() -> void:
	var purse := Purse.new({&"wood": 6})
	check(purse.set_limit(&"wood", 4) == 2 and purse.amount(&"wood") == 4, "a lower limit cuts and returns it")
	check(purse.set_limit(&"wood", -1) == 0 and not purse.has_limit(&"wood"), "negative: no limit")
	check(purse.set_amount(&"wood", 9) == 0 and purse.amount(&"wood") == 9, "and no cut")


func test_to_dict_round_trip() -> void:
	var purse := Purse.new({&"food": 2, &"gold": 1}, {&"food": 2, &"gold": 7})
	purse.add_substitute(&"gold", [&"food"], 1)
	purse.add_substitute(&"wood", [], 2)
	purse.add({&"wood": 3})
	var copy := Purse.from_dict(purse.to_dict())
	check(copy.to_dict() == purse.to_dict(), "from_dict(to_dict()) is the same purse")
	check(copy.can_pay({&"food": 3}) and not copy.can_pay({&"food": 5}), "the substitutes came back")
	check(copy.substitutes() == purse.substitutes(), "in the same order")
	var same_order := Purse.new({&"gold": 1, &"food": 2}, {&"gold": 7, &"food": 2})
	same_order.add_substitute(&"gold", [&"food"], 1)
	same_order.add_substitute(&"wood", [], 2)
	same_order.add({&"wood": 3})
	check(same_order.to_dict() == purse.to_dict(), "the order things were added does not matter")


func test_from_dict_old_wildcard_format() -> void:
	var old := {"amounts": {&"gold": 2}, "limits": {}, "wildcard": &"gold", "wildcard_covers": [&"wood"]}
	var purse := Purse.from_dict(old)
	check(purse.can_pay({&"wood": 2}) and not purse.can_pay({&"ore": 1}), "a 0.2 wildcard with a list")
	check(purse.substitutes() == purse.substitutes_for(&"wood"), "it is one substitute")
	check(purse.substitutes()[0]["rate"] == 1, "at rate 1")
	var any := Purse.from_dict({"amounts": {&"gold": 1}, "wildcard": "gold"})
	check(any.can_pay({&"ore": 1}), "a 0.2 wildcard with no list covers everything")
	var self_only := Purse.from_dict({"amounts": {&"gold": 1}, "wildcard": "gold", "wildcard_covers": ["gold"]})
	check(self_only.substitutes().is_empty(), "a list holding only the wildcard covered nothing")
	check(Purse.from_dict({"amounts": {&"gold": 1}}).substitutes().is_empty(), "no wildcard, no substitute")


func test_limits_and_overflow_with_substitutes() -> void:
	var purse := Purse.new({&"gold": 1}, {&"gold": 2})
	purse.add_substitute(&"gold")
	var lost_heard: Array[int] = []
	purse.overflowed.connect(func(_key: StringName, lost: int) -> void: lost_heard.append(lost))
	check(purse.add({&"gold": 4}) == ({&"gold": 3} as Dictionary[StringName, int]), "the limit still cuts")
	check(purse.pay({&"wood": 2}) and purse.amount(&"gold") == 0, "and paying with the substitute is allowed")
	check(lost_heard == ([3] as Array[int]), "overflowed once")
