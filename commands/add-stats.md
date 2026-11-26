---
description: "Stats with bonuses (StatKit addon): one base and caps per stat, and modifiers that add, add a percent, multiply or fix, in ADD → PERCENT → MUL → SET order, each with its source; remove_source takes away everything an item or a buff gave, and the inspector shows the final value."
---

Add **stats with bonuses** to the **game's Godot project** with the StatKit addon:
- a `StatBlock` on each thing that has stats (or a `StatSheet` per character in its rules, shown with `use_sheet`);
- the bases in `base_values` and the caps in `min_values` / `max_values`;
- the bonuses it starts with in `start_modifiers` (`StatModifier` resources);
- the game putting bonuses on and taking them off with `add` / `add_all` (with the item's source) and `remove_source`, and the HUD listening to `stat_changed` and `rebuilt`.

Then the person sees the final values in the inspector's **Values** group, without running the game; the agent builds and explains.

This is **not** items, inventories, buff durations or UI: the kit computes, and the game decides what each thing gives and when it is put on or taken off. **Not** the network: a network game decides the bonuses on the server and sends values.

Load: `godot-stat-kit`, `godot-composition-first`.

If `addons/stat_kit/` is missing:

```bash
./install.sh --addon /ABS/GODOT_ROOT stat_kit
```

Enable **StatKit**. If `godot-studio-workflow` is loaded: orchestrator → tree (this chat if it is 1–3 files; otherwise `studio-tech-lead`) → OK → `studio-developer`. No extra subagent.

## 1. Scope

If missing, ask in one batch:

1. Which stats exist (attack, defense, moves, food) and on what (characters, units, cities).
2. What gives bonuses: items, terrains, techs, buffs. Whether each adds, adds a percent (`PERCENT`: two +10 % = +20 %), multiplies (`MUL`: two ×1.1 = ×1.21) or fixes.
3. When each bonus is put on and when it is taken off (equipping, entering a terrain, a timed buff).
4. Whether the value is used as a whole number (damage, moves) and what minimum or maximum each stat has.
5. What the HUD shows (the value, the breakdown) and whether the game saves or is networked.

## 2. Plan

Show the file tree before touching the game (`[+]` new, `[~]` changed, `[-]` deleted), for example:

```
[~] project.godot                        # StatKit plugin
[+] items/sword/sword_modifier.tres      # StatModifier: attack, ADD, 2
[+] items/ring/ring_modifier.tres        # StatModifier: attack, PERCENT, 0.1 (+10 %)
[~] units/hero/hero.tscn                 # StatBlock: base_values {attack: 5, defense: 4, moves: 3}, min_values {moves: 1}
[+] units/hero/equipment.gd              # equip: block.add(mod, item_id); unequip: block.remove_source(item_id)
[+] ui/stats_hud.gd                      # listens to stat_changed and rebuilt; shows roundi(value) and describe()
[~] docs/tuning.md                       # rows for base_values and each bonus .tres
```

Start from `addons/stat_kit/examples/minimal/minimal.tscn` (sword, shield, swamp, one ring on both hands and a two-bonus blessing).

## 3. Implement

Follow [godot-stat-kit](../skills/godot-stat-kit/SKILL.md) and `addons/stat_kit/README.md`.

- `base_values`, `start_modifiers`, `min_values` and `max_values` in the `StatBlock` inspector. Each fixed bonus of an item is a `StatModifier` `.tres` (or a list in the item's type `.tres`) exported in the script: never its number in code. `StatModifier.plus` / `percent` / `times` / `fixed` only for bonuses the code works out.
- Whoever adds it sets the source: `add(mod, item_id)` or `add_all(item.bonuses, item_id)`. Taking it away is `remove_source(item_id)`. Two identical items are two sources with the same `.tres`.
- A timed buff: a game `Timer` that calls `remove_source` when it ends.
- Changing the inspector values in the game keeps what code did; `use_own_sheet()` starts from scratch.
- With a `StatSheet` per character in the rules: `block.use_sheet(unit.stats)` and the HUD listens to `rebuilt`.
- The game rounds (`roundi(value)`) and sets its minimums and maximums.
- Save with `to_dict()` / `StatSheet.from_dict()`. Over the network, the server puts the bonuses on and sends values.
- Tell the person how to see it: pick the `StatBlock` and look at the inspector's **Values** group; change an `amount` and the value changes at once.

## 4. Done when

- The `StatBlock` shows no warnings and the person saw the **Values** group with the expected values.
- F6: equipping and unequipping changes the value; ADDs come before PERCENTs and MULs; a SET overrides everything; the caps hold; `remove_source` takes away everything of a source.
- The HUD shows the values and redraws with `stat_changed` and `rebuilt`.
- No items, inventories, timers or network inside `addons/stat_kit`.
