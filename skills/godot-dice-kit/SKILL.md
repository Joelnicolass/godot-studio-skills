---
name: godot-dice-kit
description: >-
  Dice in a Godot 4 game with the DiceKit addon: dice with any faces (numbers,
  icons, one or more symbols such as hit, blank or crit), rolled with the
  game's RandomNumberGenerator, with the sum and how many times each symbol
  came up; the highest and the lowest (advantage, disadvantage, dropping the
  lowest), rolling some dice again, ready dice (d4 to d20), mixed dice from the
  inspector (2d6 + 1d8), the same seed for the same rolls, rolls saved or sent
  over the network as indices, a Roll button in the inspector to try the dice
  and a 3D tray (cubes or your mesh, in rows) where the dice tumble and land
  with the face that came up. A plain-data DieData and DiceRoll for the rules,
  a DiceRoller node for the editor and an optional DiceTray3D. Use when the
  user wants dice, rolling dice, a 2d6, attack dice with symbols, hits and
  crits, advantage, rerolls, rolls that repeat with a seed or /add-dice. Not
  the game's rules (what a hit does), dice physics nor the network.
---

# Godot — dice (DiceKit)

Addon `addons/dice_kit/` in the **game's** project. Reference: `addons/dice_kit/README.md`.

If the addon is missing:

```bash
./install.sh --addon /path/to/godot-project dice_kit
```

Enable the **DiceKit** plugin (types `DiceRoller` and `DiceTray3D` in Create Node; `DieData` and `DieFace` in New Resource). Scoped request: `/add-dice`. Composition: [godot-composition-first](../godot-composition-first/SKILL.md).

## Rules

- **Two levels.** The game's rules roll with `die.roll(n, rng)` or `DiceRoll.of(pool, rng)` (plain data, tests headless). The `DiceRoller` is the node that rolls the inspector's die; the `DiceTray3D` shows it.
- **A die is a resource.** `DieData` with one `DieFace` per face (`value`, `tags`, `icon`). A face may have several symbols, and one may repeat (`[hit, hit, shield]`). Numbered dice are ready in `addons/dice_kit/dice/` (d4 to d20): to edit one, copy the `.tres` into the game. A die of your own is a `.tres` of the game; a more likely face goes twice in `faces`. An empty slot in `faces` keeps the die from rolling.
- **The randomness is the game's.** Each die draws one number from the rng it gets; nothing in the kit calls the global random functions. An `rng_seed` other than 0 repeats the rolls; with a match rng (`roller.rng = match_rng`), one seed repeats everything, and `rng_seed` no longer touches it.
- **The roll is typed and does not change.** `DiceRoll` with `sum()`, `count(tag)`, `has(tag)`, `slots_with(tag)`, `values()`, `highest()` / `lowest()` (slots), `highest_values()` / `lowest_values()` (values), `rerolled(slots, rng)` (a new roll) and `describe()`. `dice`, `faces` and `indices` are read-only copies. No arrays of dictionaries.
- **Mixed dice without code.** `count` of `die` plus one of each of `extra_dice`, from the inspector; `roller.pool()` says which dice it rolls.
- **Editor first.** The inspector's **Roll** button rolls with the node's values and shows the result in `last_result`; the tray shows the dice in the editor, follows the roller through `dice_changed` and tumbles them with that button. The roller warns when dice are missing, when one has no faces or when it has empty slots.
- **The tray is presentation.** The dice tumble without randomness (the same roll tumbles the same way) and `settled` says when they landed: that is when the result is shown. The rule uses the roll as soon as it comes up (`rolled` or what `roll()` returns). Each die is drawn with its `DieData.mesh` (a d8 shaped like a d8, among other dice too), otherwise with the tray's `die_mesh`, otherwise as a cube; the face that came up goes on top, like a sticker. `per_row` makes rows.
- **Saving and the network.** `to_dict()` keeps only the indices; `DiceRoll.from_dict(roller.pool(), data)` rebuilds it with the same dice. Over the network, the server rolls and sends indices.
- **No kit depends on another.** DiceKit has no rules, network or autoload: the game connects (for example, each hit takes health off another unit).

## Tree

```
Level
├── AttackRoller (DiceRoller)            # die = attack_die.tres, count = 3, extra_dice = [], rng_seed = 0
├── DiceTray3D                           # roller = AttackRoller; settled → HUD
├── Hud (Control)                        # listens to settled and shows sum() / count(&"hit")
└── Combat (Node)                        # roller.roll(n) → applies count(&"hit") to its rules
```

Start from `addons/dice_kit/examples/minimal/minimal.tscn`.

## What goes where

| Kit | Game |
|---|---|
| The faces, rolling, adding up and counting symbols | What each symbol means, how many dice each one rolls |
| `rng_seed`, `rng`, a roll from indices | The match's seed, who rolls over the network |
| `highest`, `lowest`, `rerolled`, `slots_with` | When there is advantage, which dice are rolled again and how many times |
| `DiceTray3D`, `settled` | The camera, the table, the HUD and when to show the result |
| `to_dict` / `from_dict` / `from_indices` | Where it is saved and how it travels over the network |
| `describe()` | The log line in the game's language |

## Done when

- The `DiceRoller` shows no warnings and **Roll** in the inspector shows a `last_result` that makes sense.
- F6: the dice tumble, land with the face that came up and the HUD shows the sum and the counts on `settled`.
- With the same `rng_seed`, the same sequence of rolls.
- `godot --headless --path dicekit_lab --script res://addons/dice_kit/tests/dice_test_runner.gd` gives `DICEKIT TESTS PASS` (in the kit's repo).

## Anti-patterns

- `randi()`, `randf()` or `pick_random()` to roll dice: use a `DieData` and a game rng.
- An `Array` of dictionaries as a roll: `DiceRoll` is already typed.
- Damage or combat rules inside the kit: the kit says what came up, the game decides what it does.
- Showing the result on `rolled` while the tray tumbles: wait for `settled`.
- Rolling on each client without sharing the seed: the server rolls and sends indices.
- A loose `Dictionary` for faces with several symbols: they go in `tags`, repeated when needed.
- Editing a die of `addons/dice_kit/dice/` in place: reinstalling the kit writes over it; copy it into the game.
- Building a roll by hand to roll some dice again: `roll.rerolled(slots, rng)`.
