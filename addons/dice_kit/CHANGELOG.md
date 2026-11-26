# DiceKit changes

## 0.1.0

First version:

- `DieFace` and `DieData`: a die as a resource, with faces that have a value, symbols (`tags`, one may repeat; `tag` is the shortcut for a face with one symbol) and an icon. An optional `DieData.mesh`: the shape the tray draws that die with. Ready dice in `dice/` (d4, d6, d8, d10, d12 and d20, without a mesh), `DieData.numbered(sides)` and `can_roll()`. A die with an empty slot does not roll.
- `DiceRoll`: the roll as plain, read-only data. `sum()`, `count(tag)` (every appearance of a symbol), `has(tag)`, `slots_with(tag)`, `values()`, `highest(n)` / `lowest(n)` (slots) and `highest_values(n)` / `lowest_values(n)` (values), `rerolled(slots, rng)` to roll some dice again, `describe()`, mixed dice with `DiceRoll.of`, and `to_dict` / `from_dict` / `from_indices` to save it or send it over the network. Each die draws one number from the rng you give it: the same seed gives the same roll.
- `DiceRoller`: rolls `count` of `die` plus one of each of `extra_dice` (mixed dice from the inspector) with its own rng, built from `rng_seed`, or with your match's rng (`rng`); changing `rng_seed` never touches an assigned rng. It emits `rolled` and `dice_changed`; `pool()` says which dice it rolls. A **Roll** button in the inspector, with `last_result`, to try the dice without running the game.
- `DiceTray3D`: shows the roll in 3D, in rows of `per_row`; each die with its `DieData.mesh`, or the tray's mesh (`die_mesh`), or a cube; the dice tumble without randomness and land with the face that came up on top, and it says so with `settled`. It follows the roller through `dice_changed`, without asking every frame.
- Example `examples/minimal` (3D), the kit's own tests and `dicekit_lab/`, with strict GDScript warnings and a check in the real editor (`-- --dicekit-editor-check`).
