# <img src="icons/deck_kit.svg" width="32" height="32" alt=""> DeckKit

Cards for deckbuilders, solitaires, card or board games and event decks. It answers "which cards are where": the deck, the hand, the discard, the table. It has two levels:

- **`CardStack`**: a pile of cards in order, as plain data (`RefCounted`, no nodes, no scene). It draws, moves between piles, shuffles with your `RandomNumberGenerator`, refills the deck from the discard and saves with `to_dict`. Your game's rules use it directly, and it tests headless.
- **For the scene**:
  - `CardData` (Resource): one card, with an `id`, a title, a text, art and tags. One `.tres` per card.
  - `CardPile` (Node): builds or shows a `CardStack` with the cards from the inspector. A hand, a discard, the table.
  - `Deck` (a `CardPile`): the pile you draw from. It has its own generator with a seed (or uses your match's) and shuffles itself when the game starts.
  - `HandView` (Control, optional): shows a pile in a row or a fan, in the editor too. It draws each card, or makes an instance of your scene per card (`card_scene`). It plays with the mouse, the keyboard or a gamepad, and cards can be dragged between views (`drag_cards`).

DeckKit has **no** game rules, costs, turns, network or autoload. What a card does, when it is drawn and how many are drawn is up to your game. It also has no:

- **State per copy:** the copies of a card are the same `CardData`. An upgraded, turned or counted card is another `CardData` (with its own `id`) or data of your game next to the pile.
- **Face per card:** `face_up` belongs to the whole pile. A solitaire with face-up and face-down cards in the same column uses two piles (the hidden and the shown ones) or keeps that count in the game.

## Install

```bash
./install.sh --addon /path/to/godot-project deck_kit
```

Enable the **DeckKit** plugin (types `CardPile`, `Deck` and `HandView` in Create Node; `CardData` in New Resource).

## In 3 steps

1. Make your cards: in the FileSystem, New Resource › `CardData`, with `id`, `title`, `text`, `art` and `tags`. One file per card (`strike_card.tres`). For copies, drag the same card several times.
2. Add a `Deck` with the cards in `start_cards` (the first one ends on top), `face_up` off and an `rng_seed`. Add a `CardPile` for the hand (`max_size` 5) and another for the discard. A `HandView` shows the pile in its `pile`, in the editor too: point it at the deck and you see its cards without running the game.
3. Play. Draw from the deck to the hand, discard the card that is clicked (by its index, so the copy you touched goes) and put the discard back into the deck, shuffled:

```gdscript
@onready var deck: Deck = %Deck
@onready var hand: CardPile = %Hand
@onready var discard: CardPile = %Discard
@onready var hand_view: HandView = %HandView


func _ready() -> void:
	hand_view.card_pressed.connect(func(_card: CardData, index: int) -> void: hand.move_at(index, discard))


func draw_one() -> void:
	if deck.is_empty():
		deck.refill_from(discard)
	deck.draw_to(hand)
```

## Minimal example

`examples/minimal/minimal.tscn` (F6): a deck of 12 cards (10 different ones: Coin three times, and 3 with the tag `event`), a hand of 5 and a discard. **Draw** draws the top card to the hand; clicking a card in the hand (or picking it with the arrows and Enter) discards that card, even when another one is the same; dragging it to the discard does too, dragging it inside the hand moves it and dragging it from the discard brings it back. **Refill** puts the discard under the deck and shuffles it. **Seed** deals again with that seed: the same seed always gives the same order. The hand shows each card with the `card_face.tscn` scene, and the cards slide to their place. The counts say how many cards each pile has and how many events are left in the deck, and the log says what happened. In the editor, `DeckView` shows the deck's top face; raise its `spread` to see all 12.

```
Minimal                  # minimal.gd: counts, buttons and log
├── Box
│   ├── Counts, Buttons  # Draw, Refill, Seed
│   ├── Table
│   │   ├── DeckView     # HandView of the deck (spread 3: a stack of backs), keyboard off
│   │   └── %DiscardView # HandView of the discard, drag_cards
│   ├── %HandView        # HandView of the hand: card_scene = card_face.tscn, a 12° fan, drag_cards
│   └── Log
├── %Deck                # 12 CardData from cards/, rng_seed 1, face_up off
├── %Hand                # CardPile, max_size 5
└── %Discard             # CardPile
```

## How it works

- **The top is index 0.** `cards()` and `top()` go from the top down. `add(card)` puts it on top; `add(card, -1)`, at the bottom.
- **Copies:** the same `CardData` may be in a pile several times, and they are told apart by index. `move_at(index, to)` and `remove_at(index)` use that very card. `move(card, to)` and `remove(card)` are shortcuts that take the first copy from the top: they do when there are no copies or it does not matter which one goes. The `HandView` gives the index of the card that is clicked.
- **Moving:**
  - `draw_to(pile, n)` takes up to `n` cards off the top and puts each one on top of `pile`, so the last one drawn ends on top (in a `HandView`, on the right). It returns the cards in the order they left.
  - `move_at(index, to, to_index)` moves any card. `to` may be the same pile: that is how a card goes to the bottom.
  - `refill_from(other, rng)` puts every card of `other` underneath, in their order, and with an `rng` shuffles the pile.
- **Limit:** `max_size` (-1 = no limit). When not all of them fit, what fits moves and the rest stays where it was. Lowering the limit in the game takes no card out: it only stops more coming in. In the editor, the `CardPile` builds the pile again with the ones that fit.
- **Signals:** they all come from the `CardStack`. A move emits `removed(cards, to)` on the source pile and then `added(cards, from)` on the target. `to` and `from` are null when the cards come from nowhere or are taken out (`add`, `remove`, `take`, `clear`). A `CardPile` names the other side as the `CardPile` that shows that pile (`CardPile.showing(stack)`), also when your rules made the move on the `CardStack`. To know what was drawn, listen to `added` on the hand.
- **Shuffling:** `shuffle(rng)` always asks for a `RandomNumberGenerator` of yours (Fisher–Yates with `rng.randi_range`). Same seed, same order. The kit never uses the global random calls (`randi()`, `randomize()`, `Array.shuffle()`, `pick_random()`), and a test guards it.
- **The `Deck`:**
  - Its `rng` comes from `rng_seed`. With `rng_seed` 0 each start uses a seed of its own, a different one for each deck.
  - To use the match's generator, assign it: `deck.rng = match_rng`. From then on `rng_seed` and `reset()` leave it alone; `deck.rng = null` goes back to its own.
  - It shuffles itself when the game starts (`shuffle_at_start`) once the scene is ready, at the end of that frame. That way a parent's `_ready` can give it `rng` first, with no `reset()`. If the parent draws in its `_ready`, the deck shuffles right before that first `draw_to`. In the editor it stays in the inspector order.
  - `deck.shuffle()` and `deck.refill_from(discard)` use its `rng` when you pass none, so a refill always shuffles.
  - `reset()` goes back to the start cards and shuffles with its own generator from the beginning. The other piles are not touched: empty them yourself.
  - `face_up` starts on like in any pile: turn it off in the deck's inspector.
- **Errors:** drawing or moving to null or to the same pile (except `move_at`), an index outside the pile, shuffling without an `rng`, adding a null card: an error and nothing changes. Moving to a full pile, or a card that is not there, returns `false` with no error: it is normal play.
- **Saving:** `to_dict()` gives `{"cards": [ids, from the top down], "max_size": n}`, ready for JSON. `CardStack.from_dict(data, catalog)` finds each id in your list of cards. An id that is not there is an error and is skipped. Every card that is saved needs its `id`. For the deck to shuffle after loading the way it would have in the saved match, also save `deck.rng.seed` and `deck.rng.state`, and when loading set them in that order (the seed first, then the state).

## Cards with data of their own

A card that carries the game's numbers extends `CardData` with typed fields, never with a loose `Dictionary`. This event card gives food and lasts a few turns:

```gdscript
class_name EventCard
extends CardData

## Food the event gives (negative: it takes food).
@export var food := 0
## Turns the event lasts.
@export_range(1, 10) var turns := 1
```

The rules ask for the type and read the fields. Each event that reaches the hand from the deck adds its food, whether the node or your rules drew it:

```gdscript
func _ready() -> void:
	hand.added.connect(_on_hand_added)


func _on_hand_added(cards: Array[CardData], from: CardPile) -> void:
	if from != deck:
		return
	for card in cards:
		var event := card as EventCard
		if event != null:
			food += event.food
```

The inspector shows the new fields, and `CardPile`, `Deck` and `HandView` treat them like any `CardData`. To show them in the hand, a `card_scene` of your own.

## The card's design: `card_scene`

Without `card_scene`, the `HandView` draws each card (title, art or text, tags) in its colors. For a frame, a cost in a corner or the fields of your card type, make a scene and put it in `card_scene`. This card shows its title and its text:

```gdscript
@tool
extends PanelContainer

## The card to show. HandView sets it.
var card: CardData:
	set(value):
		card = value
		if is_node_ready():
			_show()

@onready var _title: Label = %Title
@onready var _text: Label = %Text


func _ready() -> void:
	_show()


func _show() -> void:
	if card != null:
		_title.text = card.title
		_text.text = card.text
```

- The root is a `Control` and its script declares `var card: CardData`. The `HandView` makes one per card, sets `card`, sizes it to `card_size`, and places and turns it. With `@tool`, it shows in the editor.
- The `HandView` handles the mouse: the scene gets no clicks (it is left at `MOUSE_FILTER_IGNORE`), and `card_pressed` and `card_hovered` work the same.
- A face-down pile does not show the scene: the `HandView` draws the back (`back`).
- The example uses `examples/minimal/card_face.tscn`.

## Keyboard, gamepad and dragging

- **Keyboard and gamepad:** with `keyboard` (on by default), the `HandView` takes focus (`focus_mode` All). `ui_left` and `ui_right` (arrows, the gamepad's d-pad) pick a card, which lifts as with the mouse and emits `card_hovered(card, index)`; `ui_accept` (Enter, Space, the A button) emits `card_pressed(card, index)`. At an end the arrow goes on, so focus moves to the control next to it.
- **Click:** `card_pressed` comes when the button is released on the same card it was pressed on, like a `Button`. That way a drag is not a click.
- **Dragging:** with `drag_cards` on in both views, a card drags to another view (or to another place in the same one, to reorder). The view it lands on emits `card_dropped(card, from_index, from, to_index)`. The kit moves nothing: your game decides. A view with `drag_cards` off neither starts drags nor takes drops.

Each card that lands on this view moves from the view it came from to the place it landed:

```gdscript
@onready var table_view: HandView = %TableView


func _ready() -> void:
	table_view.card_dropped.connect(_on_card_dropped)


func _on_card_dropped(_card: CardData, from_index: int, from: HandView, to_index: int) -> void:
	from.pile.move_at(from_index, table_view.pile, to_index)
```

- `to_index` already counts the card as gone when both views show the same pile, so `move_at` leaves it where it landed when reordering too.
- While dragging, the card as the view draws it, or an instance of `card_scene`, follows the pointer (`drag_preview(index)`).
- A node of your own that takes cards (a board cell) checks `data is HandView.CardDrag` in its `_can_drop_data`: it carries `card`, `index` and `from`.

## API

### `CardData` (Resource)

| Member | What it does |
| --- | --- |
| `id: StringName` | How `to_dict` and `from_dict` find it. Unique in your game |
| `title: String` | The name on the card (empty: views show the `id`) |
| `text: String` | What the card says. Without `art`, the `HandView` draws it in its place |
| `art: Texture2D` | The picture |
| `tags: Array[StringName]` | Kinds of card (`event`, `attack`) |
| `has_tag(tag) -> bool` | Whether it has that tag |

### `CardStack` (RefCounted)

| Member | What it does |
| --- | --- |
| `CardStack.new(start = [], max_size = -1)` | A pile with `start` (from the top down) and a limit |
| `max_size` | The limit (-1 = no limit) |
| `cards()`, `size()`, `is_empty()`, `has(card)` | What is there. `cards()` is a copy |
| `top(n = 1)`, `find_id(id)`, `count_tag(tag)` | Looking without taking: the top ones, one by id, how many with a tag |
| `add(card, index = 0) -> bool` | Adds from nowhere (`-1` = the bottom). `false` when it is full |
| `remove_at(index) -> CardData`, `remove(card) -> bool` | Takes one card out to nowhere: the one at that index, or the first copy |
| `take(n = 1)`, `clear()` | Takes the top ones, or all of them, out to nowhere |
| `draw_to(pile, n = 1) -> Array[CardData]` | Draws up to `n` from the top to `pile` |
| `move_at(index, to, to_index = 0) -> bool`, `move(card, to, index = 0) -> bool` | Moves one card to another pile (or inside the same one): the one at that index, or the first copy |
| `shuffle(rng)` | Shuffles with your generator |
| `refill_from(other, rng = null) -> Array[CardData]` | Every card of `other` underneath; with `rng`, shuffles |
| `to_dict()` / `CardStack.from_dict(data, catalog)` | Plain data to save, send over the network or compare |
| signals `added(cards, from)`, `removed(cards, to)`, `shuffled` | Past tense: it already happened |

### `CardPile` (Node)

- **Inspector:** `start_cards` (from the top down), `max_size` and `face_up`. Changing `start_cards` builds the pile again; changing `face_up` emits `flipped`. It never touches a `use_stack` pile.
- **Editor warnings:** an empty slot in `start_cards`, a card without an `id`, two different cards with the same `id` and more cards than `max_size`.
- **Pile:** `stack` is the `CardStack` it shows. `use_stack(stack)` shows your rules' one and `use_own_stack()` goes back to the inspector's. `CardPile.showing(stack)` says which pile shows it (the last one that started showing it; null when none does).
- **Methods:** the same as `CardStack` (`cards`, `size`, `is_empty`, `top`, `has`, `find_id`, `count_tag`, `add`, `remove_at`, `remove`, `take`, `clear`, `to_dict`), with another `CardPile` where the other pile goes: `draw_to(pile, n)`, `move_at(index, to, to_index)`, `move(card, to, index)`, `refill_from(other, rng)`. `shuffle(rng)` needs a generator (the `Deck` uses its own).
- **Signals:** `added(cards, from)`, `removed(cards, to)` and `shuffled`, with the other side as a `CardPile` (null when none shows it); `rebuilt` when the node starts showing another pile (when it arrives, read every card again), and `flipped(face_up)`.
- **Saving:** `to_dict()`, and to load, `pile.use_stack(CardStack.from_dict(data, catalog))`.

### `Deck` (extends `CardPile`)

| Member | What it does |
| --- | --- |
| `rng_seed` | The seed of its own generator. 0: a seed of its own each start. Changing it rebuilds only its own |
| `shuffle_at_start` | Shuffle when the game starts (once the scene is ready) and on `reset()` |
| `rng` | The generator it uses. Assign the match's to share it; `null` goes back to its own |
| `draw_to(pile, n = 1)` | As on `CardPile`; when the start shuffle has not happened yet, it happens first |
| `shuffle(rng = null)`, `refill_from(pile, rng = null)` | Without `rng`, they use the deck's |
| `reset()` | The start cards again, shuffled when `shuffle_at_start` |

### `HandView` (Control)

- **Inspector:** `pile` and `card_scene`; in Layout, `card_size`, `spread` (from one left edge to the next; it shrinks so the row fits the width), `fan_degrees` (0 = a straight row), `hover_lift` and `settle_time` (how long a card takes to slide to its place; 0 = it jumps); in Input, `keyboard` and `drag_cards`; in Look, `back` (the back; empty, a plain back in `back_color`), `faces_in_editor`, `card_color`, `back_color`, `border_color`, `text_color` and `font_size`.
- **How it shows:** the bottom of the pile on the left and the top on the right, so the last card drawn to a hand is on the right. Without `card_scene`, each card is a rounded panel with the title, the art (or the text when it has no art) and the tags; with `card_scene`, an instance of your scene. A face-down pile shows backs; in the editor, with `faces_in_editor`, it shows the faces so you can check the cards. When the pile changes, each card slides to its place (with copies, the one that stays is the one that was nearest); the card under the pointer lifts.
- **Signals:** `card_pressed(card, index)` (left click, or `ui_accept`), `card_hovered(card, index)` (the pointer or the arrows; null and -1 when it leaves) and `card_dropped(card, from_index, from, to_index)` (a dragged card landed on this view). `index` is the pile's (0 = the top): pass it to `move_at`.
- **Methods:** `card_index_at(position) -> int` (-1 when there is no card), `card_at(position) -> CardData` (the one on top when they overlap), `card_rect(index) -> Rect2` (where the card goes, before the fan's turn and the hover), `drop_index(position, drag = null) -> int` (where a card would land) and `drag_preview(index) -> Control` (what follows the pointer while dragging).
- **`HandView.CardDrag`:** what a drag carries: `card`, `index` and `from` (the view it left).
- **Editor warnings:** no `pile`; a `card_scene` whose root is not a `Control` or does not declare `card`.

## You want → you write

| You want | Write |
|---|---|
| To draw 5 when the turn starts | `deck.draw_to(hand, 5)` |
| To draw, refilling the deck when it is empty | `if deck.is_empty(): deck.refill_from(discard)` and then `deck.draw_to(hand)` |
| To discard the clicked card | `hand_view.card_pressed.connect(func(_card, index): hand.move_at(index, discard))` |
| To discard by dragging | `drag_cards` on both views and `discard_view.card_dropped.connect(func(_card, i, from, _to): from.pile.move_at(i, discard, 0))` |
| To reorder the hand by dragging | `drag_cards` on its view and `hand_view.card_dropped.connect(func(_card, i, from, to): from.pile.move_at(i, hand, to))` |
| To play with the keyboard or a gamepad | Nothing: `keyboard` comes on (arrows, Enter, the d-pad and A) |
| To drop cards on a node of your own | `func _can_drop_data(_at, data): return data is HandView.CardDrag` |
| To discard the whole hand | `hand.draw_to(discard, hand.size())` |
| To send the top card to the bottom of the deck | `deck.move_at(0, deck, -1)` |
| To look at the top 3 without drawing | `deck.top(3)` |
| To know what was drawn | `hand.added.connect(func(cards, from): if from == deck: ...)` |
| To know whether events are left in the deck | `deck.count_tag(&"event")` |
| A hand of 7 | `max_size` 7 on the hand's `CardPile` |
| Three copies of a card | The same `CardData` three times in `start_cards` |
| Always the same order (tests, a daily challenge) | An `rng_seed` other than 0 on the `Deck` |
| The match's generator | `deck.rng = match_rng` (the parent's `_ready` is enough) |
| To save and go on with the same sequence | Save `deck.rng.seed` and `deck.rng.state`; when loading, set them in that order |
| To deal again | `hand.clear()`, `discard.clear()` and `deck.reset()` |
| The rival's hand face down | `face_up` off on their `CardPile` |
| Data of your own on the cards | `class_name EventCard extends CardData` with typed `@export`s |
| Another card design (a frame, the cost on top) | A scene with `var card: CardData` in the `HandView`'s `card_scene` |
| Cards that jump instead of sliding | `settle_time` 0 on the `HandView` |
| A hand per player in your rules | A `CardStack` per player and `hand.use_stack(player.hand)` |
| To save and load | `pile.to_dict()` and `pile.use_stack(CardStack.from_dict(data, all_cards))` |

## Tips

- **Rules use `CardStack`, not the node.** Keep each player's piles in your match state and show them with `pile.use_stack(player.hand)`. The signals come from the `CardStack` and the nodes name them with the `CardPile` that shows each pile, so an animation knows where a card comes from.
- **One generator per match** makes a replay or the network give the same thing: assign it to each `Deck` (`deck.rng = match_rng`) or pass it to each `shuffle(rng)`.
- **With copies, use indices.** `move_at(index, …)` and `remove_at(index)`; `move(card, …)` takes the first copy from the top.
- **"Any of" or a condition of your own** to draw or play is a game rule: check it before calling `draw_to` or `move_at`.
- **Over the network**, the server shuffles and draws, and sends the `to_dict()` of the piles each player may see (or the seed, if everyone may see everything).
- **For `to_dict` to save a card**, each different `CardData` has its own `id`; copies share theirs.

## Tests

```bash
godot --headless --path deckkit_lab --script res://addons/deck_kit/tests/deck_test_runner.gd
```

It prints `DECKKIT TESTS PASS (n)`. The tests cover:

- The pile alone: looking, adding and taking out, copies by index (`move_at`, `remove_at`), drawing to another pile (order and signals), moving (inside the same one too), the limit, shuffling (same seed, same order, against a fixed order for seed 42), refilling, errors and `to_dict` (through JSON too).
- The nodes: the pile from the inspector, the signals that name the other pile (also when your rules draw), `showing` and that it is cleaned, live changes, `use_stack`, the warnings and the `Deck` (`rng_seed`, seed 0, an assigned `rng` nothing touches, the start shuffle after the parent's `_ready`, `refill_from`, `reset`, and saving, loading and refilling with the same shuffle).
- The `HandView`: where each card goes, the `spread` that shrinks, the fan, click (press and release) and hover with the index (with copies), the keyboard, dragging between two views through the viewport, `drop_index` when reordering, the preview, `card_scene`, cards that slide, that it listens only to the cards it shows and does not remake the panels every frame.
- The example played with its buttons, clicks and drags (also on one of two copies, and to the discard and back), and the same seed twice.
- That the addon names no other kit and uses no global randomness.

In the real editor, the lab has a separate check: see `deckkit_lab/README.md`.
