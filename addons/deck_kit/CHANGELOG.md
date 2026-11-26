# DeckKit changes

## 0.1.0

First version:

- `CardData`: a card as a resource (`id`, `title`, `text`, `art`, `tags`, `has_tag`). A game extends it with typed fields.
- `CardStack`: a pile of cards as plain data, with index 0 on top and copies of the same card told apart by index. Looking (`top`, `find_id`, `count_tag`), adding and taking out (`add`, `remove_at`, `remove`, `take`, `clear`), `draw_to`, `move_at` and its shortcut `move` (inside the same pile too), a `max_size` limit that moves only what fits, `shuffle(rng)` with your generator, `refill_from` and `to_dict` / `from_dict` with a catalog. Signals `added`, `removed` and `shuffled`: they all come from here.
- `CardPile`: builds the pile from the inspector or shows your rules' one (`use_stack`). Its signals name the other pile as the `CardPile` that shows it (`CardPile.showing(stack)`), also when your rules move. `face_up` and the `flipped` signal. Editor warnings.
- `Deck`: a `CardPile` with its own generator (`rng_seed`; 0 = a seed of its own) or your match's (`rng`), which is never touched once assigned. It shuffles itself at start once the scene is ready (so a parent's `_ready` gives it `rng` first), refills shuffling and starts over with `reset()`.
- `HandView`: shows a pile in a row or a fan, in the editor too, drawn or with a scene per card (`card_scene`). Cards slide to their place (`settle_time`). Mouse (a click is press and release on the same card), keyboard and gamepad (`keyboard`: it takes focus, `ui_left` / `ui_right` pick, `ui_accept` presses) and dragging between views with Godot's API (`drag_cards`; the view it lands on emits `card_dropped` and the game moves the card). `card_pressed(card, index)`, `card_hovered(card, index)`, `card_dropped(card, from_index, from, to_index)`, `card_index_at`, `card_at`, `card_rect`, `drop_index`, `drag_preview` and `HandView.CardDrag`.
- Example `examples/minimal` (a deck of 12 cards with three copies of Coin, a hand of 5 with `card_face.tscn`, a discard by click or by dragging, a seed), the kit's own tests (also that no global randomness is used) and `deckkit_lab/` with a check in the real editor.
