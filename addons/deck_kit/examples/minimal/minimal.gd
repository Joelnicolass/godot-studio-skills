extends Control

## A deck of 12 cards (10 different ones: Coin three times, and 3 events), a hand that holds 5 and a discard. Draw
## moves the top card of the deck to the hand; clicking a card in the hand (or picking it with the arrows and Enter)
## moves that card (by its index, so the right copy) to the discard; dragging a card to the discard does the same,
## dragging it inside the hand reorders it, and dragging it from the discard brings it back. Refill puts the discard
## back under the deck, shuffled. The seed deals again: the same seed always gives the same order. The hand shows each
## card with `card_face.tscn`.

@onready var deck: Deck = %Deck
@onready var hand: CardPile = %Hand
@onready var discard: CardPile = %Discard
@onready var hand_view: HandView = %HandView
@onready var discard_view: HandView = %DiscardView
@onready var draw_button: Button = %Draw
@onready var refill_button: Button = %Refill
@onready var seed_box: SpinBox = %Seed
@onready var counts_label: Label = %Counts
@onready var log_label: Label = %Log


func _ready() -> void:
	seed_box.value = deck.rng_seed
	for pile: CardPile in [deck, hand, discard]:
		pile.added.connect(func(_cards: Array[CardData], _from: CardPile) -> void: _refresh())
		pile.removed.connect(func(_cards: Array[CardData], _to: CardPile) -> void: _refresh())
		pile.rebuilt.connect(_refresh)
	hand.added.connect(_on_hand_added)
	hand_view.card_pressed.connect(_on_card_pressed)
	for view: HandView in [hand_view, discard_view]:
		view.card_dropped.connect(_on_card_dropped.bind(view))
	draw_button.pressed.connect(_on_draw)
	refill_button.pressed.connect(_on_refill)
	seed_box.value_changed.connect(_on_seed_changed)
	_refresh()


func _on_draw() -> void:
	if deck.draw_to(hand).is_empty():
		_note("The deck is empty: refill it" if deck.is_empty() else "The hand is full")


func _on_hand_added(cards: Array[CardData], from: CardPile) -> void:
	if from == deck:
		_note("Drew " + _titles(cards))


func _on_card_pressed(card: CardData, index: int) -> void:
	if hand.move_at(index, discard):
		_note("Discarded " + card.title)


# The discard always takes a card on top; the hand keeps it where it was dropped.
func _on_card_dropped(card: CardData, from_index: int, from: HandView, to_index: int, to: HandView) -> void:
	var at := 0 if to == discard_view else to_index
	if not from.pile.move_at(from_index, to.pile, at):
		return
	if to == discard_view:
		_note("Discarded " + card.title)
	elif from == to:
		_note("Moved " + card.title)
	else:
		_note("Took back " + card.title)


func _on_refill() -> void:
	var back := deck.refill_from(discard)
	_note("Refilled %d cards, shuffled" % back.size())


func _on_seed_changed(value: float) -> void:
	hand.clear()
	discard.clear()
	deck.rng_seed = int(value)
	deck.reset()
	_note("New deal, seed %d" % deck.rng_seed)


func _refresh() -> void:
	counts_label.text = (
		"Deck %d · Hand %d/%d · Discard %d · Events in the deck: %d"
		% [deck.size(), hand.size(), hand.max_size, discard.size(), deck.count_tag(&"event")]
	)
	draw_button.disabled = deck.is_empty() or hand.size() >= hand.max_size
	refill_button.disabled = discard.is_empty()


func _titles(cards: Array[CardData]) -> String:
	var names: PackedStringArray = []
	for card in cards:
		names.append(card.title)
	return ", ".join(names)


# The newest line on top, the last six kept.
func _note(line: String) -> void:
	var lines := (line + "\n" + log_label.text).strip_edges().split("\n")
	log_label.text = "\n".join(lines.slice(0, 6))
