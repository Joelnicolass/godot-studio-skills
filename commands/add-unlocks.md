---
description: "Tech, talent or skill trees (UnlockKit addon): entries nested in the editor, cross links with requires and 'one of' with requires_any, buying with buy(id, pay), why not with why_not, undo with lock, one graph per player with new_graph, a view that draws the tree, and saving with unlocked_ids."
---

Add an **unlock tree** (techs, talents, skills, metagame progression) to the **game's Godot project** with the UnlockKit addon:
- an `UnlockTree` with one `UnlockEntry` per entry, nested: an entry inside another requires it, `requires` adds cross links and `requires_any` the "one of" ones;
- the cost, title, description and icon in each entry's inspector, and `start_unlocked` on the starting ones;
- an `UnlockTreeView` that draws the tree (in the editor too) and reports clicks, or instances a scene of the game per entry;
- the game's code: a `pay(cost) -> bool` function that charges, `tree.buy(id, pay)` to buy, and the effects listening to `unlocked`.

Then the person sees the tree drawn in the editor and changes it in the inspector; the agent builds and explains.

This does **not** know the currency or apply effects: the kit says what can be unlocked and what it costs and ties the order of a purchase, and the game charges in its `pay` (with its rules or with another kit) and decides what each entry gives. **Not** the network: a network game unlocks on the server and sends `unlocked_ids()`.

Load: `godot-unlock-kit`, `godot-composition-first`.

If `addons/unlock_kit/` is missing:

```bash
./install.sh --addon /ABS/GODOT_ROOT unlock_kit
```

Enable **UnlockKit**. If `godot-studio-workflow` is loaded: orchestrator → tree (this chat if it is 1–3 files; otherwise `studio-tech-lead`) → OK → `studio-developer`. No extra subagent.

## 1. Scope

If missing, ask in one batch:

1. What unlocks (techs, talents, skills, upgrades), how many entries there are and in which branches.
2. What needs what: the chain of each branch, the cross links between branches and the ones that ask for "one of several".
3. What each one costs and what pays for it (points, a coin, experience); what you start with.
4. What each entry gives when unlocked, and whether it can be undone.
5. How many players (one tree per player), whether the game is saved and whether it is networked. Whether the player sees the tree (a view) or only a menu.

## 2. Plan

Show the file tree before touching the game (`[+]` new, `[~]` changed, `[-]` deleted), for example:

```
[~] project.godot                        # UnlockKit plugin
[+] research/tech_tree.tscn       # UnlockTree with the UnlockEntry nodes nested by branch; costs in the inspector
[+] research/research.gd          # pay(cost) -> bool, buy(id) with tree.buy(id, pay), the effects on unlocked
[+] research/tech_entry.gd        # @tool, extends UnlockEntry: the effect's data as typed @export fields
[+] ui/tech_tree_panel.tscn       # UnlockTreeView: tree assigned; entry_pressed → research.buy(id)
[~] save/save_game.gd             # saves unlocked_ids(), loads with restore(ids)
[~] levels/level/level.tscn       # instances the tree and the panel
[~] docs/tuning.md                # one row per cost: file, node (the entry), cost
```

Start from `addons/unlock_kit/examples/minimal/minimal.tscn` (three branches, a cross link, a "one of", a starting tech, buying with points).

## 3. Implement

Follow [godot-unlock-kit](../skills/godot-unlock-kit/SKILL.md) and `addons/unlock_kit/README.md`.

- One `UnlockEntry` per entry, nested under the one it requires; a plain `Node` per branch; `requires` only for the cross links; `requires_any` for "one of several".
- `cost`, `title`, `description` and `icon` in each entry's inspector; `id` typed by hand when games are saved.
- The game buys with one call: `tree.buy(id, pay)`, where `pay(cost) -> bool` charges all or nothing. When it cannot, `why_not(id)` (a `String`) and `missing(id)` give the reason.
- What each entry gives goes in a `@tool` script that `extends UnlockEntry`, with typed `@export` fields.
- The effects listen to `tree.unlocked` (or an entry's `unlocked` signal, connected in the editor). Undo: `lock(id)` and give back what was charged.
- With several players: `player.unlocks = tree.new_graph()` per player in the rules and `tree.use_graph(player.unlocks)` for the active one (or one tree instance per player); the view listens to `rebuilt`.
- Save with `unlocked_ids()` / `restore(ids)`. Over the network, the server unlocks and sends the list.
- Tell the person how to see it: opening the tree scene shows the view drawn, and the editor warns about a repeated id, a requirement from another tree or a cycle.

## 4. Done when

- The tree and its entries show no warnings, and the person saw the tree drawn in the editor.
- F6: buying an available entry with `buy` charges and unlocks it; a locked one says what is missing; falling short changes nothing.
- The effects apply on `unlocked`, and saving and loading brings back what was unlocked.
- No coins, effects or network inside `addons/unlock_kit`.
