extends "res://addons/deck_kit/tests/deck_test.gd"

## CardPile and Deck in a tree: the stack from the inspector, signals that name the other pile, live inspector changes,
## use_stack, showing, warnings, and the deck's rng_seed, rng, start shuffle, reset and a save that goes on the same.

const FixtureMatch := preload("res://addons/deck_kit/tests/fixture_match.gd")


func _card(id: StringName) -> CardData:
	var card := CardData.new()
	card.id = id
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


func _pile(start: Array[CardData] = [], max_size := -1) -> CardPile:
	var pile := CardPile.new()
	pile.start_cards = start
	pile.max_size = max_size
	tree.root.add_child(pile)
	return pile


func _deck(seed_value: int) -> Deck:
	var deck := Deck.new()
	deck.start_cards = _ten()
	deck.rng_seed = seed_value
	tree.root.add_child(deck)
	return deck


func test_stack_from_inspector() -> void:
	var cards := _ten()
	var pile := _pile(cards, 12)
	check(pile.size() == 10 and pile.top()[0] == cards[0], "start cards, top first")
	check(pile.stack.max_size == 12, "max_size reaches the stack")
	check(pile.face_up and pile._get_configuration_warnings().is_empty(), "face up, no warnings")
	check(pile.find_id(&"c4") == cards[4] and pile.has(cards[9]) and pile.count_tag(&"x") == 0, "the forwards")
	check(pile.add(_card(&"x"), -1) and pile.size() == 11 and pile.remove(cards[0]), "add and remove")
	check(pile.take(2).size() == 2 and pile.size() == 8, "take")
	pile.clear()
	check(pile.is_empty() and pile.cards().is_empty(), "clear")
	pile.free()


func test_signals_name_the_other_pile() -> void:
	var deck := _pile(_ten())
	var hand := _pile()
	var heard: Array[String] = []
	hand.added.connect(
		func(cards: Array[CardData], from: CardPile) -> void: heard.append("hand+%d %s" % [cards.size(), from == deck])
	)
	deck.removed.connect(
		func(cards: Array[CardData], to: CardPile) -> void: heard.append("deck-%d %s" % [cards.size(), to == hand])
	)
	hand.removed.connect(func(_cards: Array[CardData], to: CardPile) -> void: heard.append("hand- %s" % [to]))
	deck.draw_to(hand, 2)
	check(heard == (["deck-2 true", "hand+2 true"] as Array[String]), "draw_to names both piles: %s" % [heard])
	heard.clear()
	deck.stack.draw_to(hand.stack)
	check(heard == (["deck-1 true", "hand+1 true"] as Array[String]), "so does the rules' stack call: %s" % [heard])
	heard.clear()
	hand.take()
	check(heard == (["hand- <null>"] as Array[String]), "taken out: to is null: %s" % [heard])
	heard.clear()
	var loose := CardStack.new()
	hand.stack.draw_to(loose)
	check(heard == (["hand- <null>"] as Array[String]), "a stack no pile shows is null: %s" % [heard])
	deck.free()
	hand.free()


func test_move_and_refill() -> void:
	var cards := _ten()
	var hand := _pile(cards.slice(0, 3), 5)
	var discard := _pile()
	var heard: Array[String] = []
	discard.added.connect(
		func(_cards: Array[CardData], from: CardPile) -> void: heard.append("from hand %s" % (from == hand))
	)
	check(hand.move(cards[1], discard) and discard.top()[0] == cards[1], "move to another pile")
	check(heard == (["from hand true"] as Array[String]), "named: %s" % [heard])
	check(not hand.move(cards[9], discard), "a card that is not there")
	check(not hand.move(cards[0], null) and hand.draw_to(null).is_empty(), "no pile is an error")
	var back := hand.refill_from(discard)
	check(back == ([cards[1]] as Array[CardData]) and _ids(hand.cards())[-1] == "c1", "refill_from: under the pile")
	check(hand.refill_from(null).is_empty(), "refill from no pile is an error")
	hand.shuffle()
	check(hand.size() == 3, "a plain pile cannot shuffle without an rng: an error and nothing changes")
	hand.free()
	discard.free()


func test_live_inspector() -> void:
	var pile := _pile(_ten(), 4)
	check(pile.size() == 4, "start cards cut at max_size")
	pile.max_size = 6
	check(
		pile.add(_card(&"x")) and pile.add(_card(&"y")) and not pile.add(_card(&"z")), "a new max_size applies at once"
	)
	var count: Array[int] = [0]
	pile.rebuilt.connect(func() -> void: count[0] += 1)
	pile.start_cards = [_card(&"solo")]
	check(count[0] == 1 and _ids(pile.cards()) == (["solo"] as Array[String]), "new start cards build the stack again")
	var flips: Array[bool] = []
	pile.flipped.connect(func(face_up: bool) -> void: flips.append(face_up))
	pile.face_up = false
	pile.face_up = false
	pile.face_up = true
	check(flips == ([false, true] as Array[bool]), "flipped only when it changes: %s" % [flips])
	pile.free()


func test_use_stack() -> void:
	var pile := _pile(_ten())
	var other := _pile()
	var rules := CardStack.new([_card(&"r0"), _card(&"r1")])
	var count: Array[int] = [0]
	pile.rebuilt.connect(func() -> void: count[0] += 1)
	pile.use_stack(rules)
	check(count[0] == 1 and pile.size() == 2 and pile.stack == rules, "use_stack shows the rules' stack")
	var heard: Array[String] = []
	pile.added.connect(func(cards: Array[CardData], _from: CardPile) -> void: heard.append(_ids(cards)[0]))
	rules.add(_card(&"r2"))
	check(heard == (["r2"] as Array[String]), "the pile relays the rules' stack")
	pile.max_size = 1
	pile.start_cards = [_card(&"ignored")]
	check(rules.max_size == -1 and rules.size() == 3 and count[0] == 1, "the inspector never touches the rules' stack")
	var named: Array[bool] = []
	other.added.connect(func(_cards: Array[CardData], from: CardPile) -> void: named.append(from == pile))
	rules.draw_to(other.stack)
	check(named == ([true] as Array[bool]), "the rules' stack is named as the pile that shows it")
	pile.use_own_stack()
	check(count[0] == 2 and _ids(pile.cards()) == (["ignored"] as Array[String]), "back to its own stack")
	rules.draw_to(other.stack)
	check(named == ([true, false] as Array[bool]), "a stack it stopped showing is no longer named")
	check(heard.size() == 1, "nor relayed")
	pile.use_stack(null)
	check(pile.size() == 1, "use_stack(null) is an error and changes nothing")
	pile.free()
	other.free()


func test_a_freed_pile_is_not_named() -> void:
	var gone := _pile(_ten())
	var hand := _pile()
	var stack := gone.stack
	gone.free()
	var named: Array[String] = []
	hand.added.connect(func(_cards: Array[CardData], from: CardPile) -> void: named.append(str(from)))
	stack.draw_to(hand.stack)
	check(named == (["<null>"] as Array[String]), "a freed pile resolves to null: %s" % [named])
	hand.free()


func test_warnings() -> void:
	var pile := CardPile.new()
	var a := _card(&"a")
	pile.start_cards = [a, null, _card(&""), a, _card(&"a")]
	var warnings := pile._get_configuration_warnings()
	check(warnings.size() == 3, "an empty slot, no id, another card with the same id: %s" % [warnings])
	pile.max_size = 3
	check(pile._get_configuration_warnings().size() == 4, "and more start cards than max_size")
	check(pile.size() == 3, "only what fits, without the empty slot")
	pile.free()


func test_deck_same_seed_same_order() -> void:
	var one := _deck(7)
	var two := _deck(7)
	check(_ids(one.cards()) == _ids(_ten()), "in the inspector order until the scene is ready")
	await tree.process_frame
	check(one.size() == 10 and _ids(one.cards()) != _ids(_ten()), "shuffled once the scene is ready")
	check(_ids(one.cards()) == _ids(two.cards()), "the same seed, the same order")
	var first := _ids(one.cards())
	one.reset()
	check(_ids(one.cards()) == first, "reset deals the same order again")
	var three := _deck(8)
	await tree.process_frame
	check(_ids(three.cards()) != first, "another seed, another order")
	three.rng_seed = 7
	three.reset()
	check(_ids(three.cards()) == first, "a new rng_seed and reset: the order of that seed")
	one.free()
	two.free()
	three.free()


func test_deck_seed_zero_is_random_each_start() -> void:
	var one := _deck(0)
	var two := _deck(0)
	check(one.rng.seed != two.rng.seed, "two decks at 0, two seeds")
	one.free()
	two.free()


func test_deck_rng_and_refill() -> void:
	var deck := _deck(3)
	await tree.process_frame
	var discard := _pile()
	deck.draw_to(discard, 4)
	var match_rng := RandomNumberGenerator.new()
	match_rng.seed = 99
	deck.rng = match_rng
	var twin := RandomNumberGenerator.new()
	twin.seed = 99
	var expected := CardStack.new(deck.cards())
	expected.refill_from(CardStack.new(discard.cards()), twin)
	deck.refill_from(discard)
	check(deck.size() == 10 and discard.is_empty(), "refill_from(pile) brings the discard back")
	check(_ids(deck.cards()) == _ids(expected.cards()), "shuffled with the match's rng")
	expected.shuffle(twin)
	deck.shuffle()
	check(_ids(deck.cards()) == _ids(expected.cards()), "shuffle() uses it too")
	deck.free()
	discard.free()


func test_rng_seed_never_touches_an_assigned_rng() -> void:
	var deck := _deck(3)
	await tree.process_frame
	var own := deck.rng
	deck.rng_seed = 4
	check(deck.rng != own and deck.rng.seed == 4, "a new rng_seed builds the own rng again")
	var match_rng := RandomNumberGenerator.new()
	match_rng.seed = 99
	deck.rng = match_rng
	deck.rng_seed = 5
	check(deck.rng == match_rng and match_rng.seed == 99, "but never replaces or reseeds an assigned one")
	deck.reset()
	check(deck.rng == match_rng and deck.size() == 10, "neither does reset")
	deck.rng = null
	check(deck.rng != match_rng and deck.rng.seed == 5, "null: back to its own, from rng_seed")
	deck.free()


func test_start_shuffle_waits_for_the_parent() -> void:
	for opening_hand: int in [0, 3]:
		var parent := FixtureMatch.new()
		var deck := Deck.new()
		deck.start_cards = _ten()
		deck.rng_seed = 7
		var hand := CardPile.new()
		parent.add_child(deck)
		parent.add_child(hand)
		parent.deck = deck
		parent.hand = hand
		parent.match_seed = 42
		parent.opening_hand = opening_hand
		var shuffles: Array[int] = [0]
		deck.shuffled.connect(func() -> void: shuffles[0] += 1)
		tree.root.add_child(parent)
		await tree.process_frame
		var twin := RandomNumberGenerator.new()
		twin.seed = 42
		var expected := CardStack.new(_ten())
		expected.shuffle(twin)
		var order := _ids(expected.cards())
		check(_ids(parent.opening) == order.slice(0, opening_hand), "drawn in the parent's _ready: shuffled first")
		check(_ids(deck.cards()) == order.slice(opening_hand), "shuffled with the rng the parent gave, no reset")
		check(shuffles[0] == 1, "once: %d" % shuffles[0])
		parent.free()


func test_hand_hears_the_rules_drawing() -> void:
	var deck := _deck(2)
	var hand := _pile()
	await tree.process_frame
	var heard: Array[String] = []
	hand.added.connect(
		func(cards: Array[CardData], from: CardPile) -> void:
			heard.append("%d from deck %s" % [cards.size(), from == deck])
	)
	deck.stack.draw_to(hand.stack, 2)
	check(heard == (["2 from deck true"] as Array[String]), "the rules draw on the stacks: hand.added names the deck")
	check(CardPile.showing(deck.stack) == deck and CardPile.showing(hand.stack) == hand, "showing")
	check(CardPile.showing(CardStack.new()) == null and CardPile.showing(null) == null, "a stack no pile shows: null")
	deck.free()
	hand.free()


func test_showing_is_cleaned() -> void:
	var before := CardPile._shown_by.size()
	var pile := _pile(_ten())
	var first := pile.stack
	check(CardPile._shown_by.size() == before + 1, "one entry per shown stack")
	var other := _pile()
	other.use_stack(first)
	check(CardPile.showing(first) == other, "the last pile that started showing it")
	pile.use_own_stack()
	check(CardPile.showing(first) == other, "the other pile still shows it")
	other.free()
	check(CardPile.showing(first) == null, "a freed pile takes itself out")
	pile.free()
	check(CardPile._shown_by.size() == before, "nothing left behind: %d" % CardPile._shown_by.size())


func test_save_load_then_refill_same_order() -> void:
	var catalog := _ten()
	var deck := Deck.new()
	deck.start_cards = catalog
	deck.rng_seed = 11
	tree.root.add_child(deck)
	var discard := _pile()
	await tree.process_frame
	deck.draw_to(discard, 6)
	deck.shuffle()
	var saved_seed := deck.rng.seed
	var saved_state := deck.rng.state
	var deck_data: Dictionary = JSON.parse_string(JSON.stringify(deck.to_dict()))
	var discard_data: Dictionary = JSON.parse_string(JSON.stringify(discard.to_dict()))
	deck.refill_from(discard)
	var original := _ids(deck.cards())
	var loaded := Deck.new()
	tree.root.add_child(loaded)
	var loaded_discard := _pile()
	loaded.use_stack(CardStack.from_dict(deck_data, catalog))
	loaded_discard.use_stack(CardStack.from_dict(discard_data, catalog))
	loaded.rng.seed = saved_seed
	loaded.rng.state = saved_state
	await tree.process_frame
	loaded.refill_from(loaded_discard)
	check(_ids(loaded.cards()) == original, "restored rng seed and state: the refill shuffles the same")
	deck.free()
	discard.free()
	loaded.free()
	loaded_discard.free()


func test_shuffle_at_start_off_and_reset() -> void:
	var cards := _ten()
	var deck := Deck.new()
	deck.start_cards = cards
	deck.shuffle_at_start = false
	tree.root.add_child(deck)
	await tree.process_frame
	check(_ids(deck.cards()) == _ids(cards), "shuffle_at_start off: the inspector order")
	var hand := _pile()
	var heard: Array[String] = []
	deck.removed.connect(func(_cards: Array[CardData], to: CardPile) -> void: heard.append("removed %s" % (to == hand)))
	hand.added.connect(func(_cards: Array[CardData], from: CardPile) -> void: heard.append("added %s" % (from == deck)))
	deck.draw_to(hand, 2)
	check(heard == (["removed true", "added true"] as Array[String]), "removed, then added: %s" % [heard])
	deck.reset()
	check(_ids(deck.cards()) == _ids(cards), "reset without shuffle_at_start: the inspector order")
	deck.free()
	hand.free()
