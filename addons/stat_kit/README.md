# <img src="icons/stat_kit.svg" width="32" height="32" alt=""> StatKit

Stats with bonuses for RPGs, roguelikes, strategy or board games: how much a number is worth now, with every bonus. Attack +2 from a sword, +10 % from a ring, food ×2 from a granary, moves fixed at 1 in a swamp, a defense that never goes past 10, and taking away at once everything one source gave. It has three pieces:

- **`StatModifier`** (Resource): one bonus. It adds to (`ADD`), adds a percent to (`PERCENT`), multiplies (`MUL`) or fixes (`SET`) a stat, and says who gives it (`source`).
- **`StatSheet`**: the stats as plain data (`RefCounted`, no nodes, no scene). One base per stat, an optional minimum and maximum, and a list of modifiers. Your game's rules use it directly, and it tests headless.
- **`StatBlock`** (Node): builds or shows a `StatSheet` with the values from the inspector, and shows the final values in the inspector without running the game.

StatKit has **no** items, inventory, buff durations, UI, network or autoload. What each thing gives and when it is put on or taken off is up to your game.

## Install

```bash
./install.sh --addon /path/to/godot-project stat_kit
```

Enable the **StatKit** plugin (type `StatBlock` in Create Node; `StatModifier` in New Resource).

## In 3 steps

1. Add a `StatBlock`.
2. In the inspector set `base_values` (for example `attack: 5, defense: 4`) and, if you want, `start_modifiers` (what it starts with equipped), `min_values` and `max_values`. Below, in the **Values** group, you see the final value (`Attack 5`) without running the game. Change a number and the value changes at once.
3. Make the sword a resource: New Resource › `StatModifier`, with `stat` = `attack`, `op` = `Add`, `amount` = `2`, `source` = `sword`, saved as `sword.tres`. Drag it onto the script's `sword`, which equips it, unequips it and rounds the attack for the damage:

```gdscript
@export var sword: StatModifier

@onready var hero: StatBlock = %Hero


func equip_sword() -> void:
	hero.add(sword)


func unequip_sword() -> void:
	hero.remove(sword)


func damage() -> int:
	return roundi(hero.value(&"attack"))
```

For the sword to give +3, change `amount` in `sword.tres`: no code to touch.

## Minimal example

`examples/minimal/minimal.tscn` (F6): a hero card with attack 5, defense 4 (at most 10, in `max_values`) and 3 moves. The sword starts equipped: it is a `start_modifiers` entry in the `Hero` inspector, so the editor already shows `Attack 7` under **Values**. The buttons put on and take off one modifier each (`.tres` files in `modifiers/`): the sword (+2 attack), the shield (×1.5 defense) and the swamp (moves = 1). A single `ring.tres` (+50 % attack) is worn on both hands: each hand adds it with its own source (`left_ring`, `right_ring`), and the two +50 % add up (×2, not ×2.25). **Bless** adds two modifiers made in code under one source (+2 defense, +1 moves); press it twice and they stack up to the defense maximum. **Remove blessing** takes all of them away with `remove_source`. The card shows each value with its breakdown (`describe`), and the log shows each `stat_changed`.

```
Minimal          # minimal.gd: builds the card and connects the buttons; sword, shield, swamp and ring in its inspector
├── Card         # values with their breakdown, the toggles, the rings, Bless, Remove blessing, log
└── %Hero        # StatBlock: base_values = {attack: 5, defense: 4, moves: 3}, max_values = {defense: 10}
                 # start_modifiers = [sword.tres: +2 attack]
```

## How it computes

- **The final value** is `(base + every ADD) × (1 + every PERCENT) × every MUL`. When there is a SET, the last SET added wins: it overrides the base, the ADDs, the PERCENTs and the MULs. Last, the value is kept between the stat's minimum and maximum (a SET's too).
  - Shield ×1.5 and blessing +2 on a defense of 4: `(4 + 2) × 1.5 = 9`, not `4 × 1.5 + 2 = 8`. The order they were added in does not matter.
  - Swamp `= 1` on 3 moves plus a blessing +1: it is 1. Without the swamp, 4.
  - With `max_values = {defense: 10}`, two blessings and the shield make `(4 + 4) × 1.5 = 12`, which stays at 10.
- **PERCENT adds up, MUL multiplies:** two +50 % (`PERCENT`, `amount` 0.5) make ×2; two ×1.5 (`MUL`) make ×2.25. Pick the one your design says: "+10 % attack" from rings and talents is usually `PERCENT`; "double" from a strong buff is usually `MUL`.
- **No base:** a stat without a base starts at 0. `value()` of a stat that does not exist is 0.
- **Stacking:** the same modifier twice counts twice.
- **The source:** each modifier counts as given by its `source`, or by the one you pass when adding it: `add(ring, &"left_ring")` and `add(ring, &"right_ring")` are two rings from a single `.tres`. `add_all(mods, source)` adds an item's bonuses under one source. `remove_source(source)` takes away every one of that source, from every stat, and returns how many it took.
- **Taking one away:** `remove(mod)` takes that modifier away once; `remove(mod, source)`, one added with that source. What comes back from `from_dict` is copies: for those, `remove` accepts an equal modifier (same `stat`, `op`, `amount` and source). For everything else it is the very same object that counts.
- **A modifier changes live:** if you change `amount`, `op` or `stat` of a modifier that is already in a sheet, the value changes at once and `stat_changed` is emitted.
- **The signal:** `stat_changed(stat, value)` is emitted only when the final value really changes. A +0, a ×1, a new base under a SET or a value already at its maximum do not emit it. When several stats change at once, there is one per stat, in alphabetical order.
- **Reading is cheap:** the sheet keeps the final value of every stat and updates it on each change; `value()` only reads it. A HUD can read it every frame.
- **Numbers:** they are `float`. If your game wants whole numbers, it rounds (`roundi(value)`, `int(value)`). A minimum or a maximum goes in the inspector (`min_values`, `max_values`) or in `set_limits`.
- **Errors:** a null modifier or one without a `stat`, or a minimum above the maximum, is an error and changes nothing.
- **Saving:** `to_dict()` and `StatSheet.from_dict()` keep the bases, the limits and the modifiers in order (the order decides which SET wins), each with the source it counts as given by.

## API

### `StatModifier` (Resource)

| Member | What it does |
| --- | --- |
| `stat`, `op` (`ADD`, `MUL`, `SET`, `PERCENT`), `amount`, `source` | The stat, what it does to it, how much, and who gives it. Changing any of them emits `changed` |
| `StatModifier.new(stat, op, amount, source)` | One by hand. All optional |
| `StatModifier.plus(stat, amount, source)` | Adds `amount` |
| `StatModifier.percent(stat, fraction, source)` | Adds a percent: `0.1` is +10 %, and it adds up with the others |
| `StatModifier.times(stat, factor, source)` | Multiplies by `factor` |
| `StatModifier.fixed(stat, value, source)` | Fixes the stat at `value` |
| `describe(source = &"")` | For a tooltip: `+2 attack (sword)`, `+10 % attack (ring)`, `×1.5 food (granary)`, `= 1 moves (swamp)`. With `source`, it names that source instead of its own |
| `to_dict()` / `StatModifier.from_dict(data)` | Plain data. `op` goes as `"add"`, `"mul"`, `"set"` or `"percent"`; `from_dict` also takes the number. An unknown `op` is an error and returns null |

### `StatSheet` (RefCounted)

| Member | What it does |
| --- | --- |
| `StatSheet.new(bases)` | A sheet with `{stat: base}`. All optional |
| `set_base(stat, amount)`, `base(stat)`, `bases()` | The bases (0 when there is none) |
| `set_limits(stat, min_value = -INF, max_value = INF)`, `clear_limits(stat)`, `limits(stat) -> Vector2` | The minimum and maximum, applied last. `limits` gives `Vector2(min, max)`, with `-INF` or `INF` where there is none |
| `add(mod, source = &"")` | Adds a modifier; with `source`, it counts as given by that source. The same one twice stacks |
| `add_all(mods, source = &"")` | Adds several, all with that source (an item with several bonuses) |
| `remove(mod, source = &"") -> bool` | Takes that modifier away once (with `source`: one added with that source) |
| `remove_source(source) -> int` | Takes away every one of a source and returns how many |
| `modifiers(stat = &"")`, `sources(stat = &"")` | The modifiers, or those of one stat, in the order they were added, and the source each counts as given by, in the same order |
| `describe(stat) -> PackedStringArray` | One line per modifier of the stat, with its source: a tooltip's breakdown |
| `clear_modifiers()` | Takes every modifier away; the bases and the limits stay |
| `value(stat) -> float` | The final value |
| `values()`, `stats()` | Every value and every stat (with a base, a limit or a modifier), in alphabetical order |
| `to_dict()` / `StatSheet.from_dict(data)` | Plain data to save, send over the network or compare a replay |
| signal `stat_changed(stat, value)` | Past tense: the final value already changed |

### `StatBlock` (Node)

- **Inspector:** `base_values` (`{stat: base}`), `start_modifiers` (a list of `StatModifier`, like what the character starts with equipped), `min_values` and `max_values` (`{stat: limit}`). Changing a value inside a modifier applies at once. Changing the bases, the list or the limits builds the sheet again **and keeps what code did**: the modifiers added with `add`, the start ones it took away, and the bases and limits it changed. It never touches a `use_sheet` sheet.
- **Values:** a read-only group at the end of the inspector with the final value of every stat (with its limits), always up to date. It is not saved in the scene. With a `use_sheet` sheet it shows that sheet's values.
- **Editor warnings:** an empty stat name, an empty slot in `start_modifiers`, a modifier without a `stat`, a `MUL` with `amount` 0 (it leaves the stat at 0), a minimum above the maximum, and a stat with a modifier or a limit but no base (allowed, it starts at 0; said once per stat).
- **Sheet:** `sheet` is the `StatSheet` it shows. `use_sheet(sheet)` shows your rules' sheet and `use_own_sheet()` goes back to a new sheet built from the inspector alone.
- **Methods:** the same as `StatSheet`: `value`, `values`, `base`, `set_base`, `add`, `add_all`, `remove`, `remove_source`, `modifiers`, `sources`, `describe`. `set_base` changes the sheet, not `base_values`. Limits in code go through `sheet.set_limits`.
- **Signals:** `stat_changed(stat, value)`, plus `rebuilt` when the node starts showing another sheet (`use_sheet`, `use_own_sheet` or new inspector values). When it arrives, read every value again.

## You want → write

| You want | Write |
| --- | --- |
| To equip an item | `@export var sword: StatModifier` with its `.tres`, and `hero.add(sword)` |
| To unequip it | `hero.remove(sword)`, or `hero.remove_source(&"sword")` if it gave several bonuses |
| An item with several bonuses | `@export var bonuses: Array[StatModifier]` and `hero.add_all(bonuses, &"armor")`; taking it off is `hero.remove_source(&"armor")` |
| Two identical rings | One `ring.tres` and `hero.add(ring, &"left_ring")`, `hero.add(ring, &"right_ring")`: each is taken off with its source |
| Two +10 % to make +20 % | `op` = `Percent` and `amount` = `0.1` on each |
| A bonus the code works out | `hero.add(StatModifier.plus(&"attack", level, &"level"))`, or `percent`, `times`, `fixed` |
| A buff, taken away later | `hero.add(haste)` and, when it ends (a `Timer` of your game), `hero.remove(haste)` |
| A terrain that fixes a value | A `.tres` with `op` = `Set` (`= 1 moves`) that the terrain adds on entering and removes on leaving |
| Moves never below 1 | `min_values = {moves: 1}` in the inspector, or `sheet.set_limits(&"moves", 1)` |
| The whole number for the game | `roundi(hero.value(&"attack"))` |
| A tooltip with the breakdown | `"\n".join(hero.describe(&"attack"))` |
| To know whether a buff is on | `hero.sources().has(&"haste")` |
| To redraw the HUD | `hero.stat_changed.connect(_on_stat_changed)` and `hero.rebuilt.connect(_redraw_all)` |
| One sheet per character in your rules | `var sheet := StatSheet.new({&"attack": 5})` in the match state, and `block.use_sheet(sheet)` to see it |
| To save and load | `save["stats"] = sheet.to_dict()` and `StatSheet.from_dict(save["stats"])` |

## Tips

- **Rules use `StatSheet`, not the node.** Keep one sheet per character in your match state and show it with `block.use_sheet(unit.stats)`. The HUD listens to `stat_changed` and, to redraw everything when the unit shown changes, to `rebuilt`.
- **A `.tres` is shared:** the same `sword.tres` on ten characters is a single resource. If you change its `amount` in the game, it changes on all ten. For just one, `sword.duplicate()` (or *Local to Scene* in the inspector).
- **Whoever adds it sets the source:** the resource says what the bonus does; who gives it is known by the code that puts it on. Pass the source in `add` or `add_all` (the id of the item, the buff, the unlock) and do not repeat it in every `.tres`.
- **`remove_source(&"")`** takes away the modifiers without a source. Always give a source to what you will want to take away.

## Tests

```bash
godot --headless --path statkit_lab --script res://addons/stat_kit/tests/stat_test_runner.gd
```

It prints `STATKIT TESTS PASS (n)`. The tests cover:

- The modifier: defaults, `plus` / `percent` / `times` / `fixed`, `describe` (with another source too), `changed` and `to_dict` (through JSON too, and with `op` as a number).
- The sheet: bases, the ADD → PERCENT → MUL → SET order (PERCENTs add up, MULs multiply, the last SET wins), the limits (on a SET too), stacking, the source given when adding (`add`, `add_all`, `remove` with a source), `remove` of a loaded copy, `remove_source` (`&""` too), `stat_changed` only when the value changes, a modifier that changes after it was added, one shared by two sheets, errors and `to_dict` / `from_dict` (with limits and sources, through JSON).
- The node: the sheet from the inspector, the read-only **Values** group that is not saved, live changes, the inspector's limits, that a rebuild keeps what code did, signals, `use_sheet`, `rebuilt` and the editor warnings (a `MUL` of 0 too).
- The example played with its buttons.
- That the addon names no other kit.

The lab also has a check in the real editor (see `statkit_lab/README.md`).
