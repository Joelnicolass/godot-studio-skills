@tool
@icon("res://addons/deck_kit/icons/deck.svg")
class_name Deck
extends CardPile

## A pile you draw from. It has its own `RandomNumberGenerator`, seeded from `rng_seed`, or uses your match's (`rng`).
## When the game starts it shuffles itself (`shuffle_at_start`) once the scene is ready, so a parent's `_ready` can
## give it `rng` first. `shuffle()` and `refill_from(pile)` use `rng` when none is passed, and `reset()` deals the
## start cards again. Set `face_up` off in the inspector so views draw its backs.

# Hands out the seeds of decks left at rng_seed 0. Two fresh RandomNumberGenerators made in the same microsecond start
# with the same seed, so every deck takes its own number from this one.
static var _seeds := RandomNumberGenerator.new()

## The seed of the deck's own `rng`: the same seed gives the same order. 0: a seed of its own each start. Changing it
## starts the own `rng` again; an `rng` you assigned is never touched.
@export var rng_seed := 0:
	set(value):
		rng_seed = value
		if _own_rng:
			_rng = null
## Shuffle the start cards when the game starts (once the scene is ready) and on `reset()`. Off: they stay in the
## inspector order.
@export var shuffle_at_start := true

## Where every shuffle of this deck gets its numbers when none is passed. Built from `rng_seed` the first time it is
## needed. Assign your match's to share it (`rng_seed` and `reset()` then leave it alone); null goes back to the deck's
## own. To save and go on with the same sequence, keep `rng.seed` and `rng.state` and set them back in that order.
var rng: RandomNumberGenerator:
	get:
		if _rng == null:
			_rng = RandomNumberGenerator.new()
			_rng.seed = rng_seed if rng_seed != 0 else (_seeds.randi() << 32) | _seeds.randi()
		return _rng
	set(value):
		_rng = value
		_own_rng = value == null

var _rng: RandomNumberGenerator
var _own_rng := true
var _start_shuffle_pending := false


func _ready() -> void:
	if Engine.is_editor_hint() or not shuffle_at_start:
		return
	_start_shuffle_pending = true
	_shuffle_at_start.call_deferred()


## Draws up to `n` cards from the top onto `pile` and returns them in the order drawn. When the start shuffle has not
## happened yet (a draw in a parent's `_ready`), it happens first.
func draw_to(pile: CardPile, n := 1) -> Array[CardData]:
	_shuffle_at_start()
	return super(pile, n)


## Shuffles the deck with `rng` (the deck's own `rng` when none is passed). It replaces a start shuffle still to come.
func shuffle(with_rng: RandomNumberGenerator = null) -> void:
	_start_shuffle_pending = false
	super(with_rng)


## Deals the start cards again: back to the deck's own stack (`rebuilt`), the own `rng` built again from `rng_seed`,
## and shuffled when `shuffle_at_start`. Other piles keep their cards: clear them yourself.
func reset() -> void:
	if _own_rng:
		_rng = null
	use_own_stack()
	_start_shuffle_pending = false
	if shuffle_at_start:
		shuffle()


func _rng_or_own(value: RandomNumberGenerator) -> RandomNumberGenerator:
	return value if value != null else rng


# The start shuffle, once: deferred from `_ready`, or earlier when the deck draws first. Never on a stack of the rules.
func _shuffle_at_start() -> void:
	if not _start_shuffle_pending:
		return
	_start_shuffle_pending = false
	if _own:
		shuffle()
