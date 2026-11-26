extends "res://addons/deck_kit/tests/deck_test.gd"

## CardStack alone, no tree: peeking, adding and taking, drawing and moving between stacks, max_size, the shuffle with
## a seed, refilling, errors and to_dict.

# The order seed 42 gives to cards c0..c9 (top first). If an engine update changes RandomNumberGenerator's sequence,
# this test shows it.
const SEED_42: Array[String] = ["c9", "c3", "c5", "c2", "c1", "c8", "c6", "c0", "c4", "c7"]


func _card(id: StringName, tags: Array[StringName] = []) -> CardData:
	var card := CardData.new()
	card.id = id
	card.title = String(id).capitalize()
	card.tags = tags
	return card


func _ten() -> Array[CardData]:
	var list: Array[CardData] = []
	for i in 10:
		list.append(_card(StringName("c%d" % i)))
	return list


func _ids(list: Array[CardData]) -> Array[String]:
	var ids: Array[String] = []
	for card in list:
		ids.append(String(card.id))
	return ids


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


# The listeners above capture the other stack: two stacks that listen to each other would keep each other alive.
func _unhook(stacks: Array[CardStack]) -> void:
	for stack in stacks:
		for sig: Signal in [stack.added, stack.removed, stack.shuffled]:
			for connection: Dictionary in sig.get_connections():
				var callable: Callable = connection["callable"]
				sig.disconnect(callable)


func test_peek() -> void:
	var a := _card(&"a", [&"event"])
	var b := _card(&"b")
	var stack := CardStack.new([a, b, a])
	check(stack.size() == 3 and not stack.is_empty(), "three cards, copies count")
	check(_ids(stack.cards()) == (["a", "b", "a"] as Array[String]), "cards() top first")
	check(_ids(stack.top(2)) == (["a", "b"] as Array[String]) and stack.size() == 3, "top peeks")
	check(stack.top(9).size() == 3 and stack.top(0).is_empty() and stack.top(-1).is_empty(), "top is cut to the size")
	check(stack.has(b) and not stack.has(_card(&"b")), "has looks for the same resource")
	check(stack.find_id(&"b") == b and stack.find_id(&"z") == null, "find_id")
	check(stack.count_tag(&"event") == 2 and stack.count_tag(&"none") == 0, "count_tag counts copies")
	var copy := stack.cards()
	copy.clear()
	check(stack.size() == 3, "cards() is a copy")
	check(CardStack.new().is_empty(), "an empty stack")


func test_add_remove_take_clear() -> void:
	var a := _card(&"a")
	var b := _card(&"b")
	var c := _card(&"c")
	var stack := CardStack.new([a])
	var heard: Array[String] = []
	stack.added.connect(
		func(cards: Array[CardData], from: CardStack) -> void: heard.append("+%s%s" % [_ids(cards), from])
	)
	stack.removed.connect(
		func(cards: Array[CardData], to: CardStack) -> void: heard.append("-%s%s" % [_ids(cards), to])
	)
	check(stack.add(b) and _ids(stack.cards()) == (["b", "a"] as Array[String]), "add puts it on top")
	check(stack.add(c, -1) and _ids(stack.cards())[-1] == "c", "-1 is the bottom")
	check(stack.add(c, 99) and stack.size() == 4 and _ids(stack.cards())[-1] == "c", "past the end is the bottom")
	check(stack.add(a, 1) and _ids(stack.cards()) == (["b", "a", "a", "c", "c"] as Array[String]), "at an index")
	check(stack.remove(c) and stack.size() == 4 and not stack.remove(_card(&"z")), "remove takes one copy")
	var taken := stack.take(2)
	check(_ids(taken) == (["b", "a"] as Array[String]) and stack.size() == 2, "take off the top: %s" % [_ids(taken)])
	check(stack.take(0).is_empty() and stack.take(9).size() == 2 and stack.is_empty(), "take is cut to the size")
	stack.add(a)
	stack.clear()
	check(stack.is_empty(), "clear")
	stack.clear()
	check(heard.size() == 9, "one signal per call, none for an empty clear: %s" % [heard])
	check(heard[0] == '+["b"]<null>' and heard[4] == '-["c"]<null>', "from and to are null: %s" % [heard])


func test_draw_to() -> void:
	var deck := CardStack.new(_ten())
	var hand := CardStack.new([], 5)
	var heard: Array[String] = []
	deck.removed.connect(func(cards: Array[CardData], _to: CardStack) -> void: heard.append("deck- %d" % cards.size()))
	hand.added.connect(func(cards: Array[CardData], _from: CardStack) -> void: heard.append("hand+ %d" % cards.size()))
	deck.removed.connect(func(_cards: Array[CardData], to: CardStack) -> void: check(to == hand, "removed names hand"))
	hand.added.connect(func(_cards: Array[CardData], from: CardStack) -> void: check(from == deck, "added names deck"))
	var drawn := deck.draw_to(hand, 3)
	check(_ids(drawn) == (["c0", "c1", "c2"] as Array[String]), "returned in the order drawn")
	check(_ids(hand.cards()) == (["c2", "c1", "c0"] as Array[String]), "the last drawn is on top of the hand")
	check(deck.size() == 7 and _ids(deck.top()) == (["c3"] as Array[String]), "they left the deck")
	check(heard == (["deck- 3", "hand+ 3"] as Array[String]), "removed on the source, then added: %s" % [heard])
	check(deck.draw_to(hand, 9).size() == 2 and hand.size() == 5, "a full hand takes only what fits")
	check(deck.draw_to(hand).is_empty() and deck.size() == 5, "nothing fits in a full hand")
	check(CardStack.new().draw_to(CardStack.new()).is_empty(), "an empty stack draws nothing")
	check(heard.size() == 4, "no signal when nothing moves: %s" % [heard])
	_unhook([deck, hand])


func test_move() -> void:
	var a := _card(&"a")
	var b := _card(&"b")
	var c := _card(&"c")
	var hand := CardStack.new([a, b, a])
	var discard := CardStack.new([c], 2)
	check(hand.move(a, discard) and _ids(discard.cards()) == (["a", "c"] as Array[String]), "on top of the target")
	check(_ids(hand.cards()) == (["b", "a"] as Array[String]), "the first copy left")
	check(not hand.move(b, discard) and hand.size() == 2, "the target is full")
	check(not hand.move(c, discard), "c is not in the hand")
	check(hand.move(b, hand, -1) and _ids(hand.cards()) == (["a", "b"] as Array[String]), "inside the same stack")
	var heard: Array[String] = []
	hand.removed.connect(func(_cards: Array[CardData], to: CardStack) -> void: heard.append("- %s" % (to == hand)))
	hand.added.connect(func(_cards: Array[CardData], from: CardStack) -> void: heard.append("+ %s" % (from == hand)))
	hand.move(a, hand, 1)
	check(heard == (["- true", "+ true"] as Array[String]), "a move inside emits both, naming itself: %s" % [heard])
	discard.max_size = -1
	check(hand.move(b, discard, -1) and _ids(discard.cards())[-1] == "b", "at the bottom of the target")
	_unhook([hand])


func test_copies_by_index() -> void:
	var a := _card(&"a")
	var b := _card(&"b")
	var hand := CardStack.new([a, b, a])
	var discard := CardStack.new()
	var heard: Array[String] = []
	hand.removed.connect(func(cards: Array[CardData], _to: CardStack) -> void: heard.append("-" + _ids(cards)[0]))
	check(hand.move_at(2, discard) and _ids(hand.cards()) == (["a", "b"] as Array[String]), "move_at moves that copy")
	check(hand.top()[0] == a and discard.top()[0] == a, "the other copy stayed on top")
	check(hand.move_at(0, hand, -1) and _ids(hand.cards()) == (["b", "a"] as Array[String]), "inside the same stack")
	check(hand.remove_at(1) == a and _ids(hand.cards()) == (["b"] as Array[String]), "remove_at returns the card")
	check(heard == (["-a", "-a", "-a"] as Array[String]), "removed for each: %s" % [heard])
	check(hand.remove_at(5) == null and not hand.move_at(-1, discard) and hand.size() == 1, "an index out: an error")
	check(not hand.move_at(0, null) and hand.size() == 1, "no target: an error")
	var full := CardStack.new([a], 1)
	check(not hand.move_at(0, full) and hand.size() == 1, "a full target: false, no error")
	check(hand.move_at(0, discard, -1) and _ids(discard.cards()) == (["a", "b"] as Array[String]), "to the bottom")


func test_max_size() -> void:
	var stack := CardStack.new(_ten(), 4)
	check(stack.size() == 4 and _ids(stack.top()) == (["c0"] as Array[String]), "start cards are cut at max_size")
	check(not stack.add(_card(&"x")) and stack.size() == 4, "a full stack takes no card")
	stack.max_size = 2
	check(stack.size() == 4, "lowering max_size takes no card out")
	stack.take(2)
	check(not stack.add(_card(&"x")), "2 cards: full under the new limit")
	stack.take(1)
	check(stack.add(_card(&"x")) and not stack.add(_card(&"y")), "room for one")
	stack.max_size = -1
	check(stack.add(_card(&"y")) and stack.size() == 3, "-1: no limit")


func test_shuffle_same_seed_same_order() -> void:
	var one := CardStack.new(_ten())
	var two := CardStack.new(_ten())
	var heard: Array[int] = [0]
	one.shuffled.connect(func() -> void: heard[0] += 1)
	one.shuffle(_rng(42))
	two.shuffle(_rng(42))
	check(_ids(one.cards()) == _ids(two.cards()), "the same seed, the same order")
	check(_ids(one.cards()) == SEED_42, "seed 42 order: %s" % [_ids(one.cards())])
	check(heard[0] == 1, "shuffled once")
	var other := CardStack.new(_ten())
	other.shuffle(_rng(43))
	check(_ids(other.cards()) != _ids(one.cards()), "another seed, another order")
	for seed_value: int in [1, 7, 1234, 99999]:
		var x := CardStack.new(_ten())
		var y := CardStack.new(_ten())
		x.shuffle(_rng(seed_value))
		y.shuffle(_rng(seed_value))
		check(_ids(x.cards()) == _ids(y.cards()), "seed %d twice" % seed_value)
		check(x.size() == 10 and _ids(x.cards()) != _ids(_ten()), "seed %d moved the cards" % seed_value)
	var rng := _rng(5)
	var a := CardStack.new(_ten())
	a.shuffle(rng)
	a.shuffle(rng)
	var b := CardStack.new(_ten())
	var same := _rng(5)
	b.shuffle(same)
	b.shuffle(same)
	check(_ids(a.cards()) == _ids(b.cards()), "a shared rng goes on in the same sequence")


func test_shuffle_needs_an_rng() -> void:
	var stack := CardStack.new(_ten())
	var heard: Array[int] = [0]
	stack.shuffled.connect(func() -> void: heard[0] += 1)
	stack.shuffle(null)
	check(_ids(stack.cards()) == _ids(_ten()) and heard[0] == 0, "no rng: an error and nothing changes")


func test_refill_from() -> void:
	var deck := CardStack.new([_card(&"top")])
	var discard := CardStack.new(_ten())
	var heard: Array[String] = []
	discard.removed.connect(func(_cards: Array[CardData], to: CardStack) -> void: heard.append("- %s" % (to == deck)))
	deck.added.connect(func(_cards: Array[CardData], from: CardStack) -> void: heard.append("+ %s" % (from == discard)))
	var back := deck.refill_from(discard)
	check(back.size() == 10 and discard.is_empty(), "every card came back")
	check(_ids(deck.cards())[0] == "top" and _ids(deck.cards())[1] == "c0", "under the deck, in their order")
	check(heard == (["- true", "+ true"] as Array[String]), "removed on the discard, then added: %s" % [heard])
	var shuffled := CardStack.new()
	shuffled.refill_from(CardStack.new(_ten()), _rng(42))
	check(_ids(shuffled.cards()) == SEED_42, "with an rng it shuffles: the seed 42 order")
	var small := CardStack.new([], 3)
	var pile := CardStack.new(_ten())
	check(small.refill_from(pile).size() == 3 and pile.size() == 7, "only what fits; the rest stays")
	check(_ids(pile.top()) == (["c3"] as Array[String]), "taken from the top of the other")
	_unhook([deck, discard])


func test_wrong_targets_are_errors() -> void:
	var stack := CardStack.new(_ten())
	check(stack.draw_to(null).is_empty() and stack.draw_to(stack).is_empty(), "draw_to null or itself")
	check(not stack.move(stack.top()[0], null), "move to null")
	check(stack.refill_from(null).is_empty() and stack.refill_from(stack).is_empty(), "refill_from null or itself")
	check(not stack.add(null), "add null")
	var with_null := CardStack.new([_card(&"a"), null, _card(&"b")])
	check(_ids(with_null.cards()) == (["a", "b"] as Array[String]), "a null start card is left out")
	check(stack.size() == 10, "nothing changed")


func test_to_dict_round_trip() -> void:
	var catalog := _ten()
	var stack := CardStack.new([catalog[3], catalog[1], catalog[3]], 6)
	var data := stack.to_dict()
	check(data == {"cards": ["c3", "c1", "c3"], "max_size": 6}, "plain data: %s" % [data])
	var copy := CardStack.from_dict(data, catalog)
	check(copy.to_dict() == data and copy.top()[0] == catalog[3], "the same cards, the same resources")
	var json: Dictionary = JSON.parse_string(JSON.stringify(data))
	var from_json := CardStack.from_dict(json, catalog)
	check(from_json.to_dict() == data and from_json.max_size == 6, "through JSON (max_size comes back a float)")
	var odd := CardStack.from_dict({"cards": ["c1", "nope", &"c2"]}, catalog)
	check(_ids(odd.cards()) == (["c1", "c2"] as Array[String]), "an unknown id is left out; StringName ids work")
	check(odd.max_size == -1, "no max_size: no limit")
	var heard: Array[int] = [0]
	odd.added.connect(func(_cards: Array[CardData], _from: CardStack) -> void: heard[0] += 1)
	check(heard[0] == 0, "from_dict emits nothing")
	var over := CardStack.new(_ten())
	over.max_size = 2
	check(CardStack.from_dict(over.to_dict(), catalog).size() == 10, "a save over its limit comes back whole")
