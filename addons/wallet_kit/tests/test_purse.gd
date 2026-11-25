extends "res://addons/wallet_kit/tests/wallet_test.gd"

## Purse alone, no tree: amounts, limits and what they cut, paying, the wildcard, errors and to_dict.


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


func test_wildcard() -> void:
	var purse := Purse.new({&"wood": 1, &"gold": 2}, {}, &"gold")
	check(purse.can_pay({&"wood": 2, &"ore": 1}), "gold covers 1 wood and 1 ore")
	var plan := purse.payment_for({&"wood": 2, &"ore": 1})
	check(plan == ({&"wood": 1, &"gold": 2} as Dictionary[StringName, int]), "payment_for: %s" % [plan])
	check(not purse.can_pay({&"wood": 2, &"ore": 2}), "but not 3 missing with 2 gold")
	check(purse.payment_for({&"ore": 5}).is_empty(), "payment_for is empty when it cannot be paid")
	check(not purse.can_pay({&"wood": 1, &"gold": 2, &"ore": 1}), "gold asked for itself counts first")
	check(purse.pay({&"wood": 2, &"ore": 1}), "pays with the wildcard")
	check(purse.amount(&"wood") == 0 and purse.amount(&"gold") == 0, "it took wood first, then gold")


func test_wildcard_covers() -> void:
	var purse := Purse.new({&"gold": 5}, {}, &"gold")
	purse.wildcard_covers = [&"food", &"wood"]
	check(purse.can_pay({&"wood": 2}), "covers wood")
	check(not purse.can_pay({&"culture": 1}), "but not a key out of its list")
	check(not purse.covers(&"gold"), "never itself")
	var plain := Purse.new({&"wood": 1})
	check(not plain.can_pay({&"wood": 2}), "no wildcard: nothing covers")


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
	var purse := Purse.new({&"food": 2, &"gold": 1}, {&"food": 2, &"gold": 7}, &"gold")
	purse.wildcard_covers = [&"food"]
	purse.add({&"wood": 3})
	var copy := Purse.from_dict(purse.to_dict())
	check(copy.to_dict() == purse.to_dict(), "from_dict(to_dict()) is the same purse")
	check(copy.can_pay({&"food": 3}) and not copy.can_pay({&"wood": 4}), "the wildcard and its list came back")
	var same_order := Purse.new({&"gold": 1, &"food": 2}, {&"gold": 7, &"food": 2}, &"gold")
	same_order.wildcard_covers = [&"food"]
	same_order.add({&"wood": 3})
	check(same_order.to_dict() == purse.to_dict(), "the order things were added does not matter")
