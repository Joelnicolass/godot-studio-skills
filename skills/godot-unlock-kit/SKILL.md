---
name: godot-unlock-kit
description: >-
  Tech trees, talent trees or skill trees in a Godot 4 game with the UnlockKit
  addon: what can be unlocked now, what needs what and what it costs. The tree
  is built in the editor by nesting `UnlockEntry` nodes (an entry inside
  another requires it; `requires` adds cross links, `requires_any` the "one
  of" ones; `start_unlocked` marks the starting ones), an `UnlockTreeView`
  draws it in the editor and in the game (or instances a scene of yours per
  entry), and buying takes one call, `buy(id, pay)`. Rejection reasons
  (`why_not`, `missing`), undo with `lock`, saving with `unlocked_ids` /
  `restore`, one graph per player with `new_graph`, and a plain-data
  `UnlockGraph` for the rules. Use when the user wants a tech tree, talents,
  skills, perks, research, metagame progression, upgrades that unlock, or
  /add-unlocks. It does not know the currency or apply the effects, nor is it
  the network.
---

# Godot — unlock trees (UnlockKit)

Addon `addons/unlock_kit/` in the **game's** project. Reference: `addons/unlock_kit/README.md`.

If the addon is missing:

```bash
./install.sh --addon /path/to/godot-project unlock_kit
```

Enable the **UnlockKit** plugin (types `UnlockTree`, `UnlockEntry` and `UnlockTreeView` in Create Node). Scoped request: `/add-unlocks`. Composition: [godot-composition-first](../godot-composition-first/SKILL.md).

## Rules

- **The scene tree is the unlock tree.** An `UnlockTree` with `UnlockEntry` nodes inside: an entry inside another requires it (Farming › Irrigation › Aqueduct). A plain `Node` groups a branch without adding requirements. `requires` adds entries from another branch (cross links).
- **All of and one of.** Everything in `requires` (and the parent) is required; of `requires_any`, one is enough (the wheel or pottery). Both are inspector data, and the view draws "one of" dashed.
- **One call to buy.** `tree.buy(id, pay)`: when it can, it calls the game's `pay(cost) -> bool` and, when that charged, unlocks. `unlock(id)` unlocks with no cost. When it cannot, they return false and nothing changes: not an error.
- **The kit does not know the currency.** `cost_of(id)` is data, `{key: amount}`, and `pay` is the game's. It does not apply effects either: the game listens to `unlocked`, and the effect's data goes in a script of its own that extends `UnlockEntry`.
- **Reasons.** `why_not(id)` returns a `String`, like a CommandKit `can_*` reason: `""`, `"unknown"`, `"already_unlocked"` or `"locked"`; `missing(id)` says what is missing. The game maps them to its messages.
- **Editor first.** Cost, title, description, icon, `requires`, `requires_any`, `start_unlocked` and `view_position` in each entry's inspector. An `UnlockTreeView` with `tree` assigned draws the tree in the editor (left to right or top to bottom, with the font of the game's `Theme`); with `entry_scene`, each box is a scene of the game (theme, keyboard and gamepad focus, art). Warnings: a repeated id, a requirement from another tree, a circle, an entry outside a tree, `start_unlocked` under a locked entry.
- **One effect per entry.** Each `UnlockEntry` emits its own `unlocked` and `locked`: connect them in the Node › Signals panel.
- **Two levels.** With several players, the rules keep `player.unlocks = tree.new_graph()` per player (or one tree instance per player) and the tree shows the active one with `tree.use_graph(player.unlocks)`. `rebuilt` says everything must be redrawn.
- **Saving.** `unlocked_ids()` and `restore(ids)`. Stable ids: type `id` yourself when games are saved.
- **No kit depends on another.** UnlockKit has no coins, effects, network or autoload: the game connects.

## Tree

```
Level
├── Research (Node)                      # the game: its pay, the effects, saving
├── Tree (UnlockTree)
│   ├── Economy (Node)                   # a branch: adds no requirement
│   │   └── Farming (UnlockEntry)        # start_unlocked
│   │       └── Irrigation (UnlockEntry) # cost = {points: 2}
│   ├── Military (Node)
│   │   └── Bronze (UnlockEntry)
│   │       └── Swords (UnlockEntry)     # requires = [Irrigation]: a cross link
│   └── Trade (UnlockEntry)              # requires_any = [Irrigation, Bronze]: one is enough
└── Hud
    └── TreeView (UnlockTreeView)        # tree = %Tree; entry_pressed → Research.buy(id)
```

Start from `addons/unlock_kit/examples/minimal/minimal.tscn`.

## What goes where

| Kit | Game |
|---|---|
| What needs what, what can be unlocked now, the order | What each entry gives (its effects) |
| The cost as data (`cost_of`) and the order of `buy` | The `pay` function: in which coin, all or nothing |
| `why_not`, `missing` | The messages to the player |
| `unlocked`, `locked`, `availability_changed`, `rebuilt` | The HUD, the sounds, the animations |
| `unlocked_ids` / `restore`, `to_dict`, `new_graph` | Where it is saved, one graph per player and how it travels over the network |

## With other kits (the game connects)

No kit names another: these recipes live in the game's code.

**With WalletKit.** Buying a tech charges its cost from the wallet, all or nothing, and unlocks it: `Wallet.pay` already is a `pay`:

```gdscript
@export var tree: UnlockTree
@export var wallet: Wallet


func buy(id: StringName) -> bool:
	return tree.buy(id, wallet.pay)
```

**With CommandKit.** Researching is a move with a rejection reason and undo (it gives back what was charged):

```gdscript
func can_research(_seat: int, id: StringName) -> String:
	var why := tree.why_not(id)
	if why != "":
		return why
	return "" if wallet.can_pay(tree.cost_of(id)) else "too_expensive"


func do_research(_seat: int, id: StringName) -> void:
	tree.buy(id, wallet.pay)


func undo_research(_seat: int, id: StringName) -> void:
	tree.lock(id)
	wallet.add(tree.cost_of(id))
```

**With StatKit.** One effect per entry: on unlock, the game adds the modifiers with the entry's id as `source`, and on lock it takes them away with `remove_source(id)`.

## Done when

- The `UnlockTree` and its entries show no warnings, and the person saw the tree drawn in the editor by an `UnlockTreeView`.
- F6: a click on an available entry buys it with `buy`; a locked one says what is missing (also "one of"); falling short changes nothing.
- Saving and loading brings back what was unlocked (`unlocked_ids` / `restore`).
- `godot --headless --path unlockkit_lab --script res://addons/unlock_kit/tests/unlock_test_runner.gd` gives `UNLOCKKIT TESTS PASS`, and `godot --headless --editor --path unlockkit_lab -- --unlockkit-editor-check` gives `UNLOCKKIT EDITOR CHECK PASS` (in the kit repo).

## Anti-patterns

- `can_unlock`, charging and `unlock` by hand, in that order: use `buy(id, pay)`, which never gets the order wrong.
- A tech's effects as code in the entry, or a loose `Dictionary` of data: the game listens to `unlocked`, and the data goes in typed `@export` fields of a script that extends `UnlockEntry`.
- Requirements written as text in the game, or an `if` with ids for "one of": nest the entries, use `requires` or `requires_any`.
- Building each player's graph with `from_dict(tree.to_dict())`: use `tree.new_graph()`.
- Keeping `tree.graph` somewhere else: it changes when the tree rebuilds; read it each time.
- Unlocking in `_ready` for the starting state: use `start_unlocked`, or `restore` from a saved game.
- Ids that come from the node's name in a game that saves: type `id`.
