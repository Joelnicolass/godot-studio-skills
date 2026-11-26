---
name: godot-stat-kit
description: >-
  Stats with bonuses in a Godot 4 game with the StatKit addon: one base per
  stat (attack, defense, food, moves), a minimum and a maximum, and modifiers
  that add to, add a percent to, multiply or fix the value, in a fixed order
  (ADD, PERCENT, MUL, and the last SET wins), each with its source so
  everything an item, a buff or a tech gave can be taken away at once. A
  plain-data `StatSheet` for the rules, `StatModifier` resources and a
  `StatBlock` node that shows the final values in the inspector without
  running the game; saving with `to_dict`. Use when the user wants stats,
  attributes, equipment bonuses, buffs and debuffs, percentages or
  multipliers, a terrain that fixes a value, caps on a stat, tech bonuses or
  /add-stats. Not items, inventory, buff durations, UI or the network.
---

# Godot — stats with bonuses (StatKit)

Addon `addons/stat_kit/` in the **game's** project. Reference: `addons/stat_kit/README.md`.

If the addon is missing:

```bash
./install.sh --addon /path/to/godot-project stat_kit
```

Enable the **StatKit** plugin (type `StatBlock` in Create Node; `StatModifier` in New Resource). Scoped request: `/add-stats`. Composition: [godot-composition-first](../godot-composition-first/SKILL.md).

## Rules

- **Two levels.** The game's rules keep one `StatSheet` per character, unit or city (plain data, tests headless). The `StatBlock` is the node that builds it from the inspector values or shows your rules' sheet (`use_sheet`).
- **A fixed order.** `(base + every ADD) × (1 + every PERCENT) × every MUL`; when there is a SET, the last one added wins; last, the minimum and the maximum. PERCENTs add up (two +10 % = +20 %) and MULs multiply (two ×1.5 = ×2.25): pick the one the design says.
- **Every bonus has a source.** Who gives it (an item, an unlock, a buff) is passed by the code when adding it: `add(mod, &"left_ring")`, `add_all(item.bonuses, item.id)`. When none is passed, the resource's `source` counts. `remove_source(source)` takes away everything of that source.
- **Design numbers go in resources.** A fixed bonus of an item is a `StatModifier` `.tres` (or a list in the item's type `.tres`) exported in the script: `hero.add(sword)`. `StatModifier.plus`, `percent`, `times` and `fixed` are for bonuses the code works out (per level, per count). A `.tres` is shared: to change just one in the game, `duplicate()`.
- **Editor first.** `base_values`, `start_modifiers`, `min_values` and `max_values` are set in the inspector, and the **Values** group shows the final value at once, without running the game. The node warns about an empty slot, a modifier without a `stat`, a `MUL` of 0, a minimum above the maximum and a stat without a base.
- **Rebuilding loses nothing.** Changing the inspector values while the game runs builds the sheet again and keeps what code did (bonuses added or taken away, bases and limits changed). `use_own_sheet()` does start from scratch.
- **The HUD listens.** `stat_changed(stat, value)` only when the final value changes; `rebuilt` to redraw everything when the node starts showing another sheet. `value()` reads an already computed value: it can be read every frame.
- **`float` numbers.** The game rounds (`roundi`); caps go in `min_values` / `max_values`.
- **Saving.** `to_dict()` and `StatSheet.from_dict()` keep bases, limits and modifiers in order, with their source. The ones that come back are copies: take them away with `remove_source`.
- **No kit depends on another.** StatKit has no items, inventory, buff durations, UI, network or autoload: the game connects. A timed buff is a game `Timer` that calls `remove` or `remove_source`. Over the network, the server decides the bonuses and sends values or `to_dict()`.

## Tree

```
Unit
├── StatBlock                            # base_values {attack: 5, defense: 4}, min_values {moves: 1}; Values shows the result
│   └── (start_modifiers)                # [sword.tres: +2 attack] as inspector resources
├── Equipment (Node)                     # equip: block.add_all(item.bonuses, item.id); unequip: block.remove_source(item.id)
└── Hud (Control)                        # listens to stat_changed / rebuilt and shows the values
```

Start from `addons/stat_kit/examples/minimal/minimal.tscn`.

## What goes where

| Kit | Game |
|---|---|
| The bases, the limits, the modifiers, the ADD → PERCENT → MUL → SET order | Which stats exist, what each item, terrain or tech gives, and what their caps are |
| `add`, `add_all`, `remove`, `remove_source`, `sources` | When something is equipped, who gives each bonus, how long a buff lasts, what ends it |
| `value`, `values`, `describe` | Rounding and how the value is used (damage, cost, range) |
| `stat_changed`, `rebuilt` | The HUD, the animations, the notices |
| `to_dict` / `from_dict` | Where it is saved and how it travels over the network |

## Done when

- The `StatBlock` shows no warnings and the inspector's **Values** group shows what is expected without running the game.
- F6: equipping and unequipping changes the value; ADDs come before PERCENTs and MULs; two PERCENTs add up; a SET overrides everything; the caps hold; `remove_source` takes away every bonus of a source.
- The HUD rounds where needed and redraws with `stat_changed` and `rebuilt`.
- `godot --headless --path statkit_lab --script res://addons/stat_kit/tests/stat_test_runner.gd` gives `STATKIT TESTS PASS` (in the kit repo).

## Anti-patterns

- Items, inventories or buff timers inside the kit: the game has them and calls `add` / `remove_source`.
- Keeping the final value in another variable and adding bonuses to it by hand, or clamping it with `maxf` in the game: the value is `value(stat)`, with its limits in the inspector.
- The number of a fixed bonus written in code (`StatModifier.plus(&"attack", 2, …)` for a sword): it goes in an exported `.tres`.
- A bonus without a source: it cannot be taken away with `remove_source` later. Whoever adds it passes the source.
- Changing `amount` of a shared `.tres` for a single character: it changes on all of them; use `duplicate()`.
- Keeping the rules' state in the node: the node is a view; the rules keep the `StatSheet`.
