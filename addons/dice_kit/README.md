# <img src="icons/dice_kit.svg" width="32" height="32" alt=""> DiceKit

Dice for wargames, roguelikes, board games or RPGs: with any faces (numbers, icons, one or more symbols), rolled with your `RandomNumberGenerator`. The roll tells you the sum, how many times each symbol came up, the highest and lowest dice, and rolls again the ones you pick. It has two levels:

- **`DieData`** (Resource) and **`DiceRoll`** (RefCounted): the die and the roll as plain data, no nodes, no scene. Your game's rules roll with their own rng, and they test headless.
- **`DiceRoller`** (Node): rolls the inspector's dice (mixed too: 2d6 + 1d8) with its seed and reports with `rolled`. **`DiceTray3D`** (Node3D, optional) shows the roll in 3D: the dice tumble and land with the face that came up on top.

DiceKit has **no** game rules (what a `hit` means, how much damage a crit does), physics, network or autoload. No part of the kit uses Godot's global randomness: every number comes from an rng you give it, so the same seed gives the same rolls.

## Install

```bash
./install.sh --addon /path/to/godot-project dice_kit
```

Enable the **DiceKit** plugin (types `DiceRoller` and `DiceTray3D` in Create Node; `DieData` and `DieFace` in New Resource).

## In 3 steps

1. Add a `DiceRoller` and drag a die into `die`: a ready one from `addons/dice_kit/dice/` (`d4.tres`, `d6.tres`, `d8.tres`, `d10.tres`, `d12.tres`, `d20.tres`) or your own (New Resource → `DieData`, with one `DieFace` per face: `value`, `tags`, `icon`). Copy the `.tres` from `dice/` into your game before editing it: reinstalling the kit writes over that folder.
2. Set `count` (how many dice) and press **Roll** in the inspector: `last_result` shows what came up ("3 + 5 = 8 · 1 sword"), without running the game.
3. Roll from your code. An attack rolls as many dice as the attacker has and counts the hits:

```gdscript
@onready var roller: DiceRoller = %Roller


func attack(dice: int) -> int:
	var roll := roller.roll(dice)
	print("Rolled %s" % roll.describe())
	return roll.count(&"hit")
```

`roll.sum()` adds up the values; `roll.count(&"hit")` counts how many times that symbol came up.

## Minimal example

`examples/minimal/minimal.tscn` (F6, 3D): a die of its own, `attack_die.tres`, with 3 `hit` faces (worth 1, with an icon), 2 `blank` (worth 0) and 1 `crit` (worth 2, with an icon); each face has one symbol in `tags`. **Roll 1**, **Roll 2** and **Roll 3** roll that many; the dice tumble and, when they land, the label says the sum and the hits. Type a seed in **Seed** (0: random) and the same rolls come back in the same order.

```
Minimal          # minimal.gd: connects the buttons and reads the roll on settled
├── Camera, Sun, Environment, Table
├── %Roller      # DiceRoller: die = attack_die.tres, count = 3, rng_seed = 0
├── %Tray        # DiceTray3D: roller = %Roller
└── Ui           # Roll 1 / 2 / 3, %Seed, %Result
```

## How it rolls

- **Faces:** `DieData.faces` is the list, in order. They are all equally likely. A face that should come up more often goes in the list twice (the same resource works: editing it changes both).
- **Symbols:** `DieFace.tags` is a list, and a symbol may be there more than once. `count(tag)` counts every appearance: a face `[hit, hit, shield]` adds 2 hits and 1 shield. For a face with one symbol, `face.tag` reads the first one and writing it leaves only that one.
- **A roll:** each die draws **one** number from the rng, `rng.randi_range(0, faces - 1)`, in order. That is why the same seed gives the same roll, and two rolls in a row from the same rng follow its sequence.
- **Slots:** each die of the roll has a place (a `slot`), 0 the first. `highest()`, `lowest()` and `slots_with(tag)` return slots; `highest_values()` and `lowest_values()` return values.
- **Rolling again:** `rerolled(slots, rng)` gives a new roll with those slots rolled again and the others as they were. Each die rolled again draws one number from the rng, in slot order.
- **What it keeps:** `dice` (the die in each slot), `faces` (the face that came up) and `indices` (that face's place in `faces`, 0 first). They are read only: whatever reads them gets copies, and a roll never changes. The dice and the indices build the same roll again: that is what travels over the network or gets saved.
- **Mixed dice:** `DiceRoller.extra_dice` adds one die of each to every roll, after the `count` dice of `die`. `roller.pool()` says which dice it rolls.
- **Seed:** a `DiceRoller.rng_seed` other than 0 gives the same rolls in every match. With 0, each roller takes a new random seed when it starts, different from the other rollers'. Changing `rng_seed` starts the roller's own rng again.
- **One rng for the whole match:** `roller.rng = match_rng`. Then a single number (the match's seed) repeats everything, dice included. Changing `rng_seed` never touches an assigned rng; `roller.rng = null` goes back to the own one.
- **Empty slots:** a die with an empty slot in `faces` cannot roll (`can_roll()` is false): it gives an error and an empty roll, and draws nothing from the rng. The `DiceRoller` shows it as a warning in the editor.
- **Errors:** no dice, a die without faces or with an empty slot, `n` under -1 or no rng: an error and an empty roll (`size() == 0`). The roller does not emit `rolled` or change `last_roll`. A roll that fails draws no numbers from the rng.
- **The tray uses no randomness:** each die's tumble comes from its place and from the face that came up. The same roll always tumbles the same way.
- **Godot changes:** a test pins the sequence of a d6 with seed 12345. If a new Godot version changes its `RandomNumberGenerator`, that test fails: saved seeds would no longer give the same rolls.

## API

### `DieFace` (Resource)

| Member | What it does |
| --- | --- |
| `value: int` | What it adds to `sum()`. A symbol that adds nothing stays at 0 |
| `tags: Array[StringName]` | The face's symbols, counted by `count(tag)` (`hit`, `blank`, `shield`); one may repeat. Empty: none |
| `tag: StringName` | A shortcut for a face with one symbol: reads the first of `tags`; writing it leaves only that one |
| `icon: Texture2D` | The picture views draw. Empty: they write the value and the symbols |
| `DieFace.new(value, tag, icon)` | All optional; for several symbols, set `tags` afterwards |

### `DieData` (Resource)

| Member | What it does |
| --- | --- |
| `faces: Array[DieFace]` | The faces, in order. Changing the list or a face applies at once (the roller's warnings, the tray's dice) |
| `sides() -> int` | How many faces it has |
| `mesh: Mesh` | The shape views draw for this die (a d8 model). Empty: the view's own (the tray's `die_mesh`, or a cube). The ready dice have none |
| `can_roll() -> bool` | It has faces and no empty slot |
| `roll(n, rng) -> DiceRoll` | Rolls `n` dice of this kind |
| `DieData.numbered(sides)` | A die with faces worth 1 to `sides` (`numbered(6)` is a d6) |

### `DiceRoll` (RefCounted)

| Member | What it does |
| --- | --- |
| `sum() -> int` | The values added up |
| `count(tag) -> int`, `has(tag) -> bool` | How many times that symbol came up (every appearance), and whether it did |
| `slots_with(tag) -> Array[int]` | The slots whose face has that symbol |
| `values() -> Array[int]`, `size() -> int` | Each die's value, in order, and how many dice there are |
| `highest(n = 1)`, `lowest(n = 1) -> Array[int]` | The **slots** of the `n` highest (or lowest) values, highest (or lowest) first; a tie keeps the earlier slot first |
| `highest_values(n = 1)`, `lowest_values(n = 1) -> Array[int]` | Those **values** |
| `rerolled(slots, rng) -> DiceRoll` | A new roll with those slots rolled again; the others stay. This one does not change |
| `dice`, `faces`, `indices` | The die, the face and the face's index in each slot. Read only: copies |
| `describe() -> String` | The roll in words: "3 + 5 = 8", "1 + 0 + 2 = 3 · 1 blank · 1 crit · 1 hit" |
| `DiceRoll.of(pool, rng)` | One die of each, in order: mixed dice (`[d6, d6, d8]`) |
| `to_dict()` / `DiceRoll.from_dict(pool, data)` | `{"indices": [..]}` to save or send; on the other side, with the same dice, the same roll. JSON numbers work |
| `DiceRoll.from_indices(pool, indices)` | The roll those indices give (a log, a fixed roll for a tutorial). It draws nothing |

### `DiceRoller` (Node)

- **Inspector:** `die`, `count` (how many of `die` per roll), `extra_dice` (one more of each in every roll: a d8 here and `count` 2 of a d6 roll 2d6 + 1d8; without `die`, only these) and `rng_seed` (0: random). In the **Try it** group, the **Roll** button rolls with those values, in the editor too, and `last_result` (read only) shows what came up. Each Roll continues the sequence; to start over, type the seed again.
- **Editor warnings:** no dice, a die without faces or with empty slots, and an empty slot in `extra_dice`.
- **`roll(n = -1) -> DiceRoll`:** rolls `n` of `die` (-1: `count`) and one of each of `extra_dice`, keeps the roll in `last_roll` and emits `rolled(roll)`.
- **`pool(n = -1) -> Array[DieData]`:** the dice `roll(n)` would roll, in order. Handy for `DiceRoll.from_dict(roller.pool(), data)`.
- **`rng`:** where the numbers come from. When you assign your match's rng, it uses that one; otherwise its own, built from `rng_seed` the first time. Changing `rng_seed` builds only the own one again; `null` goes back to the own one.
- **Signals:** `rolled(roll)` and `dice_changed` (`die`, `count`, `extra_dice` or a face of those dice changed).

### `DiceTray3D` (Node3D, optional)

- **Inspector:** `roller` (shows each of its rolls), `die_mesh` (the shape of the dice without a `mesh` of their own; empty: a cube), `die_size`, `spacing` (center to center), `per_row` (dice per row), `tumble_time` (0: they land at once), `die_color` and `pip_color` (the color of the value and the symbols; icons keep their own).
- **What it draws:** a die per slot, in rows of `per_row` along the X axis, centered on the node and resting on its XZ plane; the next row goes behind. On top goes the face's icon or, without an icon, its value and its symbols. While it tumbles, the top face keeps changing until it lands on the one that came up.
- **Another die shape:** each die uses its `DieData.mesh`; without one, the tray's `die_mesh`; without that either, a cube. So in 2d6 + 1d8 the d8 shows with its shape. Any mesh works (a d20 model): it is scaled so its longest side is `die_size`, and the face that came up is drawn flat above the mesh, like a sticker: the mesh does not turn to that face. A mesh with a material of its own keeps it; one without is painted `die_color`.
- **In the editor and before the first roll:** it shows the roller's dice at rest, first face up. Changing `die`, `count` or `extra_dice` shows at once (it listens to `dice_changed`; it does not ask every frame). Pressing **Roll** on the roller tumbles them in the 3D view.
- **`show_roll(roll)`:** shows any roll (mixed dice, one that came over the network). A new roll replaces the one tumbling.
- **Signal `settled(roll)`:** the dice came to rest. That is the moment to show the result to the player.
- **Questions:** `shown_roll` (the roll on the table; `null` at rest), `is_tumbling()`, `dice_shown()` and `face_on_top(slot)` (the face seen on top of die `slot`).

## You want → you write

| You want | Write |
|---|---|
| Roll 2d6 and add them up | `roller.roll(2).sum()` with a d6 in `die` |
| Count the hits | `roll.count(&"hit")` |
| Know whether a crit came up | `roll.has(&"crit")` |
| A die of your own with symbols | New Resource → `DieData`; in `faces`, one `DieFace` per face with `value`, `tags` and `icon` |
| A face with two symbols (2 hits and a shield) | `tags = [hit, hit, shield]` on that face: `count(&"hit")` counts 2 |
| A face that comes up more often | The same face twice in `faces` |
| Edit a ready die | Copy the `.tres` from `addons/dice_kit/dice/` into your game and edit the copy |
| Mixed dice (2d6 + 1d8) | `count` 2 with a d6 in `die` and a d8 in `extra_dice`; in code, `DiceRoll.of([d6, d6, d8], rng)` |
| Advantage (the best of 2d20) | `roller.roll(2).highest_values()[0]` |
| Disadvantage | `roll.lowest_values()[0]` |
| 4d6 dropping the lowest | `roll.sum() - roll.lowest_values()[0]` |
| Mark the two highest dice | `roll.highest(2)`: their slots, for `tray.face_on_top(slot)` or your own view |
| Roll the blanks again | `roll = roll.rerolled(roll.slots_with(&"blank"), roller.rng)` and `tray.show_roll(roll)` |
| The same rolls in every match | An `rng_seed` other than 0 in the inspector |
| The dice to use the match's rng | `roller.rng = match_rng` |
| Roll from the rules, no nodes | `die.roll(3, rng)` |
| Show the result when they land | `tray.settled.connect(_show_result)` |
| No animation | `tray.tumble_time = 0` |
| A d8 that looks like a d8, among other dice too | Your d8 mesh in its `DieData`'s `mesh` |
| Another shape for every die | Your mesh in the tray's `die_mesh` (dice with their own `mesh` keep it) |
| Many dice | `per_row` on the tray: more rows, not one long row |
| Send a roll over the network | `roll.to_dict()`; on the other side, `DiceRoll.from_dict(roller.pool(), data)` and `tray.show_roll(roll)` |
| Save and keep the same sequence | Save `roller.rng.state`; when loading, `roller.rng.state = saved` |
| A line for the log | `roll.describe()` |
| Try the die without running the game | **Roll** in the `DiceRoller`'s inspector |

## Tips

- **The rules use `DieData` and an rng, not the node.** `attack_die.roll(3, match_rng)` is all a rule needs, and it tests without a scene. The `DiceRoller` is for the editor and the tray.
- **Over the network, the server rolls.** The server rolls and sends `roll.to_dict()`; each client builds the same roll with `DiceRoll.from_dict(roller.pool(), data)` (or with the dice the game knows) and shows it with `tray.show_roll(roll)`. Another way is to share the match's seed and roll in the same order on every machine.
- **The ready dice belong to the kit.** Reinstalling the kit writes over `addons/dice_kit/dice/`: copy the `.tres` into a folder of your game before editing it (an icon on the 8 of a d8, for example).
- **The meaning is the game's.** `hit`, `crit` or `blank` are symbols: how much damage a crit does is up to your rules.

## Tests

```bash
godot --headless --path dicekit_lab --script res://addons/dice_kit/tests/dice_test_runner.gd
```

It prints `DICEKIT TESTS PASS (n)`. The tests cover:

- The faces and their symbols (a face saved with the old `tag` too), numbered dice, the ready dice in `dice/`, rolling errors, that a die with an empty slot does not roll or draw numbers, and live changes.
- The roll: sum, counts with several symbols per face, `slots_with`, the highest and the lowest, `rerolled` (with its fixed sequence), that it cannot be changed, `describe`, mixed dice, the same seed on several seeds, a fixed sequence (a d6 with seed 12345 and a d20 with 2026), one number from the rng per die, `to_dict` through JSON and the errors.
- The node: `count`, `rolled` and `last_roll`, `extra_dice` and `pool()`, `rng_seed`, two rollers at seed 0 that do not repeat each other, an assigned rng that `rng_seed` does not touch, `dice_changed`, the Roll button with `last_result` and the warnings.
- The tray: the dice at rest, tumbling and landing on the face that came up, what is drawn on top, that the same roll tumbles the same way without drawing any random number, rows, one mesh for all and one per die, following the roller without asking every frame, size and spacing.
- The example played with its buttons, the same seed twice too.
- That the addon names no other kit and calls no global random function.

In the real editor, the lab has a check that opens the example, changes the roller from the inspector, presses **Roll** and looks at `last_result` and the tray's dice in the 3D view:

```bash
godot --headless --editor --path dicekit_lab -- --dicekit-editor-check
```

It prints `DICEKIT EDITOR CHECK PASS (n)`.
