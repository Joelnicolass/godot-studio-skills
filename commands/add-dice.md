---
description: "Dice (DiceKit addon): dice with numbers, icons and symbols rolled with the game's rng, sum and count by symbol, the highest and the lowest, rerolls, mixed dice from the inspector, the same seed for the same rolls, a Roll button in the inspector and an optional 3D tray."
---

Add **dice** to the **game's Godot project** with the DiceKit addon:
- a `DieData` per kind of die (a ready one from `addons/dice_kit/dice/`, copied into the game if it must be edited, or your own, with one `DieFace` per face: `value`, `tags`, `icon`);
- a `DiceRoller` with that die, `count`, `extra_dice` if dice are mixed, and `rng_seed` (or the match's rng in `roller.rng`);
- the rules reading the roll with `sum()`, `count(tag)`, `highest()` / `lowest()` and, when dice are rolled again, `rerolled(slots, rng)`;
- if the dice are seen, a `DiceTray3D` with `roller` and the HUD listening to `settled`.

Then the person presses **Roll** in the inspector and sees the result without running the game; the agent builds and explains.

This is **not** the game's rules: the kit says what came up, and the game decides what a hit or a crit does. **Not** physics: the tray's dice tumble as presentation. **Not** the network: a network game rolls on the server and sends indices.

Load: `godot-dice-kit`, `godot-composition-first`.

If `addons/dice_kit/` is missing:

```bash
./install.sh --addon /ABS/GODOT_ROOT dice_kit
```

Enable **DiceKit**. If `godot-studio-workflow` is loaded: orchestrator → tree (this chat if it is 1–3 files; otherwise `studio-tech-lead`) → OK → `studio-developer`. No extra subagent.

## 1. Scope

If missing, ask in one batch:

1. Which dice exist: numbered (d6, d20) or with their own symbols (which faces, what each is worth, which symbols and icon it has).
2. Who rolls, how many dice and when (an attack, a turn, an event); whether dice of different kinds are mixed.
3. What the game does with the roll: add it up, count a symbol, look for a crit, keep the highest or the lowest, roll some again.
4. Whether rolls repeat with a seed (replays, daily challenges) or whether the game already has a match rng.
5. Whether the dice are seen in 3D or only the result (and with which shape: cubes, one model for all in `die_mesh` or one per kind of die in `DieData.mesh`); whether the match is saved or networked.

## 2. Plan

Show the file tree before touching the game (`[+]` new, `[~]` changed, `[-]` deleted), for example:

```
[~] project.godot                        # DiceKit plugin
[+] dice/attack_die.tres          # DieData: 3 hit (1), 2 blank (0), 1 crit (2), with icons
[+] dice/icons/hit.png            # the hit face's icon
[~] combat/combat.gd              # roller.roll(n); count(&"hit") to the rules
[~] ui/combat_hud.gd              # listens to tray.settled; shows sum() and count(&"hit")
[~] levels/level/level.tscn       # DiceRoller (die, count, extra_dice, rng_seed) + DiceTray3D (roller)
```

Start from `addons/dice_kit/examples/minimal/minimal.tscn` (a die of its own, Roll 1/2/3, a seed).

## 3. Implement

Follow [godot-dice-kit](../skills/godot-dice-kit/SKILL.md) and `addons/dice_kit/README.md`.

- One `.tres` per die of your own; repeated faces go twice in `faces`.
- `die`, `count`, `extra_dice` and `rng_seed` in the `DiceRoller`'s inspector; with a match rng, `roller.rng = match_rng`.
- The rules read the roll `roll()` returns (or `rolled`); without nodes, `die.roll(n, rng)` and `DiceRoll.of(pool, rng)` for mixed dice. Rolling again: `roll.rerolled(roll.slots_with(&"blank"), rng)`.
- The HUD shows the result on `tray.settled`, when the dice landed.
- Save with `to_dict()` / `DiceRoll.from_dict(roller.pool(), data)`. Over the network, the server rolls and sends indices.
- Tell the person how to see it: **Roll** in the `DiceRoller`'s inspector, and the tray's dice in the 3D view.

## 4. Done when

- The `DiceRoller` shows no warnings and the person pressed **Roll** in the inspector.
- F6: the dice tumble, land with the face that came up and the HUD shows the sum and the counts.
- With the same `rng_seed`, the same rolls in the same order.
- No game rules, `randi()` or network inside `addons/dice_kit`.
