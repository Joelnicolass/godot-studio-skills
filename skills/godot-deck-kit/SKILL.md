---
name: godot-deck-kit
description: >-
  Cards in a Godot 4 game with the DeckKit addon: which cards are where (the
  deck, the hand, the discard, the table). Each card is a `CardData` resource
  (id, title, text, art, tags) that the game extends with typed fields; a
  plain-data `CardStack` with index 0 on top draws, moves between piles,
  shuffles with your `RandomNumberGenerator` (same seed, same order), refills
  the deck from the discard and saves with `to_dict`; copies of a card are
  told apart by index (`move_at`). `CardPile` and `Deck` nodes (with
  `rng_seed` or the match's `rng`) for the editor and a `HandView` that shows
  a hand in a fan, drawn or with a scene per card (`card_scene`), in the
  editor too, with mouse, keyboard, gamepad and dragging between views. Use when the user wants a deck, a hand, drawing cards, a
  discard, shuffling, a deckbuilder, a solitaire, a card game, an event deck
  or /add-deck. Not the cards' rules, costs, turns or the network.
---

# Godot — cards, decks and hands (DeckKit)

Addon `addons/deck_kit/` in the **game's** project. Reference: `addons/deck_kit/README.md`.

If the addon is missing:

```bash
./install.sh --addon /path/to/godot-project deck_kit
```

Enable the **DeckKit** plugin (types `CardPile`, `Deck` and `HandView` in Create Node; `CardData` in New Resource). Scoped request: `/add-deck`. Composition: [godot-composition-first](../godot-composition-first/SKILL.md).

## Rules

- **Two levels.** The game's rules keep one `CardStack` per pile (the deck, each player's hand, the discard): plain data, tests headless. `CardPile` and `Deck` are the nodes that build it from the inspector's cards or show your rules' one (`use_stack`).
- **A card is a `CardData`.** One `.tres` per card (`strike_card.tres`), with its `id`. The game's numbers go in a subclass with typed `@export`s (`class_name EventCard extends CardData`), never in a `Dictionary`.
- **The top is index 0.** `draw_to` puts each card on top of the other pile: the last one drawn ends on top, and in a `HandView`, on the right.
- **Copies are told apart by index.** The same `CardData` may be there several times: `move_at(index, to)` and `remove_at(index)` move that very one; `move(card)` takes the first copy from the top. `HandView.card_pressed(card, index)` gives the index of the one clicked.
- **Everything moves through the kit.** `draw_to`, `move_at` and `refill_from`, never taking from an array by hand: that way the `removed` / `added` signals always arrive, from the `CardStack`, with the other pile named (`CardPile.showing(stack)`). What was drawn is heard with `added` on the hand.
- **Randomness belongs to the game.** `shuffle(rng)` asks for a `RandomNumberGenerator`. The `Deck` has its own with `rng_seed`; to share the match's, `deck.rng = match_rng` (the parent's `_ready` is enough: the deck shuffles when that frame ends). No `randi()`, `randomize()`, `Array.shuffle()` or `pick_random()`: same seed, same order.
- **Limits:** `max_size` (-1 = no limit). A full pile takes only what fits; it is not an error.
- **Editor first.** Cards are dragged into `start_cards`, the `HandView` shows them in the editor (with `faces_in_editor`, a face-down deck's too) and the node warns about an empty slot, a card without an `id`, two cards with the same `id` and more cards than the limit.
- **The card's design is a scene.** `HandView.card_scene`: a `Control` root with `var card: CardData` (and `@tool` to see it in the editor). The `HandView` places it, slides it (`settle_time`) and handles the mouse. Without a scene, it draws a simple panel.
- **The view listens.** `added`, `removed`, `shuffled`, `rebuilt` and `flipped`; the `HandView` already does it on its own. `card_pressed` and `card_hovered` (with the index) to play with the mouse, the keyboard or a gamepad (`keyboard`, on: arrows and `ui_accept`).
- **Dragging belongs to the game.** With `drag_cards` on both views, the view a card lands on emits `card_dropped(card, from_index, from, to_index)` and the game moves it: `from.pile.move_at(from_index, to.pile, to_index)`. The kit moves nothing by itself.
- **Saving.** `to_dict()` saves ids; `CardStack.from_dict(data, catalog)` finds them in the game's list of cards. To go on with the same shuffle, save `deck.rng.seed` and `deck.rng.state` and set them in that order when loading.
- **It has no** state per copy (an upgraded card is another `CardData`) nor face per card (`face_up` belongs to the pile).
- **No kit depends on another.** DeckKit has no card rules, costs, turns, network or autoload: the game connects.

## Tree

```
Table (Node)
├── Deck (Deck)              # start_cards = [cards/*.tres], rng_seed, face_up off
├── Hand (CardPile)          # max_size 5
├── Discard (CardPile)
└── Hud (Control)
    ├── HandView (HandView)  # pile = Hand, card_scene; card_pressed → hand.move_at(index, discard)
    └── Draw (Button)        # deck.draw_to(hand)
```

Start from `addons/deck_kit/examples/minimal/minimal.tscn`.

## With other kits

The game writes the glue; the addon names no one.

- **TurnKit:** in the draw phase, `turns.phase_started.connect(func(phase): if phase == &"draw": deck.draw_to(hand, 2))`.
- **WalletKit:** a card that costs is a subclass (`class_name PlayCard extends CardData` with `@export var cost: Dictionary[StringName, int]`); when it is played, with `card` typed as `PlayCard`: `if wallet.pay(card.cost): hand.move_at(index, discard)`, with the `index` from `card_pressed`.
- **CommandKit:** `do_play(seat, index)` moves the card with `hand.move_at(index, discard)` and `undo_play(seat, index)` gives it back with `discard.move_at(0, hand, index)`. Drawing and shuffling are not undone. The match's `rng` lives in the game state and is assigned to the `Deck`, so a replay draws the same.

## What goes where

| Kit | Game |
|---|---|
| Which cards are in each pile and in what order | What each card does and when it is played |
| Drawing, moving, refilling, the limit | How many are drawn, when to refill, what happens with a full hand |
| Shuffling with an `rng` | The `rng` and its seed, in the match state |
| `CardData` with id, title, text, art and tags | The subclasses with the game's numbers |
| `HandView`, `card_scene`, `settle_time`, `card_pressed`, `card_hovered`, `card_dropped` | The card's design, sounds, the table, what happens when a card lands on another view |
| `to_dict` / `from_dict` | Where it is saved and what each player sees over the network |

## Done when

- The `Deck` and the `CardPile`s show no warnings and the `HandView` shows the cards in the editor.
- F6: drawing fills the hand up to its limit, clicking discards that copy, refilling shuffles, and the same seed gives the same order.
- No one calls `randi()`, `Array.shuffle()` or `pick_random()` for the cards.
- `godot --headless --path deckkit_lab --script res://addons/deck_kit/tests/deck_test_runner.gd` gives `DECKKIT TESTS PASS` (in the kit repo).

## Anti-patterns

- A card's rules (damage, cost, effect) inside the kit: they go in the game, or in a `CardData` subclass as data.
- A `Dictionary` of data on the card instead of typed `@export`s on a subclass.
- An `Array` of cards of your own next to the `CardStack`: the signals do not arrive and the view never finds out.
- `move(card, …)` with the `CardData` of a click when there are copies: the first copy goes, not the clicked one. Use `move_at(index, …)`.
- Calling `deck.reset()` only so it uses the match's `rng`: assigning it in the parent's `_ready` is enough.
- `Array.shuffle()`, or a `RandomNumberGenerator.new()` without a seed on each shuffle: the order does not repeat.
- A pile per player created from the node: the rules keep it and the node shows it with `use_stack`.
- Saving cards by title or by path: they are saved by `id`, and each different card has its own.
