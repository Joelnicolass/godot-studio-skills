---
description: "Cards (DeckKit addon): a CardData per card, a Deck with a seed or the match's rng, CardPiles for the hand and the discard, drawing, moving by index (copies), shuffling with your RandomNumberGenerator, refilling, a fanned HandView with a scene per card and saving with to_dict."
---

Add **cards** to the **game's Godot project** with the DeckKit addon:
- a `CardData` (`.tres`) per card, or a subclass with the game's numbers;
- a `Deck` with the cards in `start_cards` and its `rng_seed` (or the match's `rng`);
- a `CardPile` per pile: the hand (with `max_size`), the discard, the table (or a `CardStack` per pile in the rules, shown with `use_stack`);
- a `HandView` that shows the hand (drawn or with a `card_scene` of your own) and reports `card_pressed(card, index)`.

Then the person sees the cards in the inspector and in the editor; the agent builds and explains.

This is **not** the cards' rules: the kit knows which card is where, and the game decides what each one does, when it is drawn and what it costs. **Not** turns, costs or the network: the game connects.

Load: `godot-deck-kit`, `godot-composition-first`.

If `addons/deck_kit/` is missing:

```bash
./install.sh --addon /ABS/GODOT_ROOT deck_kit
```

Enable **DeckKit**. If `godot-studio-workflow` is loaded: orchestrator → tree (this chat if it is 1–3 files; otherwise `studio-tech-lead`) → OK → `studio-developer`. No extra subagent.

## 1. Scope

If missing, ask in one batch:

1. Which cards exist (how many different ones and how many copies of each) and what data each carries (title, text, art, tags, the game's numbers).
2. Which piles exist: the deck, each player's hand, the discard, the table. How many cards fit in the hand.
3. When cards are drawn and how many, what happens when the deck runs out (refill from the discard, lose) and whether a full hand discards.
4. Whether the order must repeat (a fixed seed, a replay, the network) and whether the match already has a `RandomNumberGenerator`.
5. How they look and how they are played: a hand in a row or a fan, the card's design (a scene of its own?), a face-down deck, the rival's hand hidden; click, keyboard or gamepad, and whether cards are dragged (to which views). Whether the game saves or is networked.

## 2. Plan

Show the file tree before touching the game (`[+]` new, `[~]` changed, `[-]` deleted), for example:

```
[~] project.godot                        # DeckKit plugin
[+] cards/strike_card.tres               # CardData: id, title, text, art, tags (one per card)
[+] cards/event_card.gd                  # class_name EventCard extends CardData: @export var food
[+] cards/storm_card.tres                # EventCard
[+] table/table.tscn                     # Deck (start_cards, rng_seed), Hand (CardPile, max_size 5), Discard
[+] table/table.gd                       # draw_to, refill_from, card_pressed → move_at(index) to the discard
[+] cards/card_face.tscn                 # card_scene: a Control root with card_face.gd (@tool, var card: CardData)
[~] ui/hud.tscn                          # HandView with pile = Hand and card_scene
[~] docs/tuning.md                       # hand size, rng_seed
```

Start from `addons/deck_kit/examples/minimal/minimal.tscn` (drawing, discarding with a click, refilling, the seed).

## 3. Implement

Follow [godot-deck-kit](../skills/godot-deck-kit/SKILL.md) and `addons/deck_kit/README.md`.

- One `.tres` per card in a game folder, each with its `id`. The game's numbers in a `CardData` subclass with typed `@export`s.
- `start_cards`, `max_size` and `face_up` in each pile's inspector; `rng_seed` and `shuffle_at_start` on the `Deck`.
- The rules move with `draw_to`, `move_at` (by index: with copies, the right card) and `refill_from`, and shuffle with `shuffle(rng)`. With the match's generator: `deck.rng = match_rng` in the parent's `_ready` (the deck shuffles when that frame ends).
- What was drawn is heard with `added` on the hand (`from == deck`), whether the node or the rules drew.
- The card's design: a scene in `card_scene` with `var card: CardData`; `settle_time` so they slide.
- Dragging: `drag_cards` on the views that give and take, and on each `card_dropped` → `from.pile.move_at(from_index, to.pile, to_index)`. The keyboard and the gamepad already work (`keyboard`).
- With a `CardStack` per player in the rules: `hand.use_stack(player.hand)`, and the view listens to `rebuilt`.
- Save with `to_dict()` and load with `use_stack(CardStack.from_dict(data, all_cards))`; to go on with the same shuffle, `deck.rng.seed` and `deck.rng.state`. Over the network, the server shuffles and draws.
- Tell the person how to see it: the cards are dragged into `start_cards`, the `HandView` draws them in the editor, and the node warns about an empty slot, a card without an `id` or more cards than the limit.

## 4. Done when

- The piles show no warnings and the person saw the cards in the inspector and in the editor.
- F6: drawing respects the hand's limit; clicking a card moves that one (even with copies); refilling brings the discard back shuffled; the same seed gives the same order.
- No one uses `randi()`, `Array.shuffle()` or `pick_random()` for the cards.
- No card rules, costs, turns or network inside `addons/deck_kit`.
