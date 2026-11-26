extends Node

## A parent that gives its Deck the match's rng in its own `_ready`, the way a game does, and may draw an opening hand
## there too. Used by test_nodes; not a test file.

var deck: Deck
var hand: CardPile
var match_seed := 1
var opening_hand := 0
var opening: Array[CardData] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = match_seed
	deck.rng = rng
	if opening_hand > 0:
		opening = deck.draw_to(hand, opening_hand)
