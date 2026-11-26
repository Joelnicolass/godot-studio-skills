# <img src="icons/unlock_kit.svg" width="32" height="32" alt=""> UnlockKit

Tech trees, talent trees, skill trees and metagame progression: what can be unlocked now, what needs what and what it costs. It has three pieces:

- **`UnlockGraph`**: the tree as plain data (`RefCounted`, no nodes, no scene). Each entry has an id, the ids it requires (all of them), the ids it requires one of, and a cost. Your game's rules use it directly, and it tests headless.
- **`UnlockTree`** and **`UnlockEntry`** (Node): the tree built in the editor. An entry inside another one requires it, so the scene tree is the unlock tree.
- **`UnlockTreeView`** (Control, optional): draws the tree, in the editor too, and reports clicks. With a scene of yours per entry, it takes your theme, your focus and your art.

UnlockKit **does not know your currency**: the cost is data, and `buy(id, pay)` asks a function of yours to charge it. It has **no** effects of the entries (what a tech gives), network or autoload.

## Install

```bash
./install.sh --addon /path/to/godot-project unlock_kit
```

Enable the **UnlockKit** plugin (types `UnlockTree`, `UnlockEntry` and `UnlockTreeView` in Create Node).

## In 3 steps

1. Add an `UnlockTree` and, inside it, one `UnlockEntry` per tech. Nest them: `Irrigation` inside `Farming` requires `Farming`. A plain `Node` groups a branch and adds no requirement. In the inspector set the `cost` (for example `points: 2`) and tick `start_unlocked` on the ones you have from the start.
2. If you want to see it, add an `UnlockTreeView` and assign the tree to its `tree`: it draws it in the editor while you build it.
3. Buy with one call. `buy` charges with your function and unlocks, only when it can be unlocked and your function charged:

```gdscript
var points := 5

@onready var tree: UnlockTree = %Tree


func buy(id: StringName) -> bool:
	return tree.buy(id, pay_points)


func pay_points(cost: Dictionary) -> bool:
	var price: int = cost.get(&"points", 0)
	if points < price:
		return false
	points -= price
	return true
```

Your function gets the cost (`{key: amount}`, empty too when it is free), charges all or nothing and returns `true` when it charged. When `id` cannot be unlocked, it is not even called.

## Minimal example

`examples/minimal/minimal.tscn` (F6): nine techs in three branches. `Farming` is there from the start, `Aqueduct` requires `Irrigation` (its parent) and `Masonry` (a `requires`), and `Market` needs `Pottery` or `Writing` (its `requires_any`, drawn dashed). Green boxes are unlocked, gold ones can be unlocked and dark ones not yet. A click on a box buys it with `tree.buy(id, _pay)` when the points are enough; the tooltip says what is missing. **+3 points** adds points and **Reset** goes back to the start. The log says what happened, or why not.

```
Minimal              # minimal.gd: keeps the points and its _pay; connects the view and the buttons
├── Box              # Points, the +3 points and Reset buttons, %View and the log
│   └── %View        # UnlockTreeView: tree = %Tree
└── %Tree            # UnlockTree
    ├── Land         # a plain Node: groups a branch
    │   └── Farming          # start_unlocked
    │       ├── Irrigation   # 2 points
    │       │   └── Aqueduct # 4 points, requires = [Masonry]; its unlocked signal goes to minimal.gd
    │       └── Pottery      # 1 point
    ├── Stone
    │   └── Masonry          # 2 points
    │       └── Walls        # 3 points
    ├── Lore
    │   └── Writing          # 2 points
    │       └── Library      # 3 points
    └── Market               # 3 points, requires_any = [Pottery, Writing]
```

## How it works

- **Entries.** Each one has an id (`StringName`), the ids it requires and a cost `{key: amount}`. In the tree, the id is `id` or, when it is empty, the node's name. What a view shows is `title` or, when it is empty, the id.
- **Requirements: all of them.** An entry needs **all** of these: its parent entry (the nearest `UnlockEntry` above it) and each one of `requires`.
- **Requirements: one of.** When it has `requires_any`, it also needs **one** of those unlocked (the wheel or pottery). The view draws those links dashed.
- **Asking.** `can_unlock(id)` says whether it can. `why_not(id)` says why not, like the rejection reason of a move: `""` (it can), `"unknown"` (not an entry), `"already_unlocked"` or `"locked"` (a requirement is missing). `missing(id)` says what is missing: the ones of `requires` that are not unlocked and, when none of `requires_any` is, all of those (one is enough). Map them to your game's messages.
- **Buying.** `buy(id, pay)` does it all in order: when it can be unlocked, it calls `pay` with the cost; when `pay` returns `true`, it unlocks. When it cannot be unlocked, nothing is charged. When `pay` returns anything else, nothing is unlocked.
- **Unlocking with no cost.** `unlock(id)` unlocks when `can_unlock(id)`. Otherwise it returns false and nothing changes: not an error, it is normal play. Use it for gifts, cheats or rules that charge another way.
- **Undo.** `lock(id)` locks it again. It returns false when it was not unlocked or another unlocked entry needs it (it is in its `requires`, or it is the only unlocked one of its `requires_any`): undo from the tip.
- **Signals.** `unlock` and `buy` emit `unlocked(id)` and then `availability_changed` (what can be unlocked changed). Each `UnlockEntry` also emits its own `unlocked` and `locked`, so you connect an effect per entry from the Node › Signals panel. `restore` emits no `unlocked` or `locked`: it emits one `availability_changed` (read everything again).
- **The tree rebuilds itself.** Changing an inspector value, adding, moving, renaming or taking out an entry rebuilds the graph once per frame (or sooner, when someone reads it), keeps what was unlocked and emits `rebuilt`. When the whole tree leaves (a scene closing), it does not rebuild. It is a new object: do not keep `tree.graph`, read it each time. In the editor the tree always shows the start (only what is `start_unlocked`).
- **Columns.** `depth(id)` is the longest chain of requirements (of both kinds) under an entry: 0 without requirements, otherwise 1 more than its deepest requirement. The view puts one column per depth, left to right, and in each column the entries in tree order. With `direction = TOP_TO_BOTTOM`, one row per depth, top to bottom, and in each row the entries left to right; the curves follow the direction. An entry with a `view_position` goes there, in pixels, and takes no place.
- **Problems.** A requirement that is not an entry, an entry that requires itself, or entries that require each other in a circle: `problems()` describes them in words and the editor shows them as warnings.
- **Saving.** Save `unlocked_ids()` (or `to_dict(false)`) and, when loading, call `restore(ids)` (it does not check the order). `to_dict()` and `UnlockGraph.from_dict()` also save the entries, for a graph your rules build. They are plain data and survive JSON.

### One graph per player

`tree.new_graph()` builds a new graph from the tree's entries, with the `start_unlocked` ones unlocked. Keep one per player in your rules and show the active player's with `use_graph`. When the match starts, each player gets their own and the view shows the first one's:

```gdscript
func start_match(players: Array[Player]) -> void:
	for player in players:
		player.unlocks = tree.new_graph()
	tree.use_graph(players[0].unlocks)
```

The entries still give titles, icons and descriptions to the view, by id; an id of the graph without an entry is a warning. Another way: instance the tree scene once per player, and each instance owns its graph.

## Entries with data of their own

What an entry gives in your game goes in your own script, which extends `UnlockEntry` with typed fields, never with a loose `Dictionary`. Start it with `@tool`, so the editor keeps rebuilding the tree when you change it. This tech adds food per turn:

```gdscript
@tool
class_name TechEntry
extends UnlockEntry

## Food per turn this tech gives once unlocked.
@export var food_per_turn := 0
```

The rules ask for the type and read the fields. This unlocked tech adds its food:

```gdscript
func _on_tree_unlocked(id: StringName) -> void:
	var tech := tree.entry(id) as TechEntry
	if tech != null:
		food_per_turn += tech.food_per_turn
```

The inspector shows the new fields, and `UnlockTree` and `UnlockTreeView` treat it like any `UnlockEntry`.

## API

### `UnlockGraph` (RefCounted)

| Member | What it does |
| --- | --- |
| `UnlockGraph.new()` | An empty graph |
| `add(id, needs = [], cost = {}, needs_any = []) -> bool` | Defines an entry: all of `needs` are required, and one of `needs_any` is enough. They may name ids added later. An empty or repeated id is an error and adds nothing (false); a negative amount is an error and that key is left out |
| `has(id)`, `ids()` | Whether it exists, and all of them in the order they were added |
| `requires(id)`, `requires_any(id)` | What it requires, all of it, and what it requires one of |
| `cost_of(id) -> Dictionary` | A copy of the cost, `{key: amount}` (`{}` when it is free) |
| `is_unlocked(id)`, `can_unlock(id)`, `why_not(id) -> String`, `missing(id)` | Asking |
| `buy(id, pay: Callable) -> bool` | When it can be unlocked, calls `pay(cost_of(id))` and, when that returns `true`, unlocks |
| `unlock(id) -> bool`, `lock(id) -> bool` | Unlocking with no cost and undoing. When it cannot, false and nothing changes |
| `unlocked_ids()`, `available_ids()` | The unlocked ones (in the order they were unlocked) and those that can be unlocked now (in the order they were added) |
| `depth(id) -> int` | The longest chain of requirements under it (0 without requirements) |
| `restore(saved_ids)` | Unlocks exactly those (a saved game); `restore([])` locks everything. No `unlocked` or `locked`; one `availability_changed`. An unknown id is an error and is skipped |
| `problems() -> PackedStringArray` | Requirements that are not entries, entries that require themselves and circles, in words |
| `to_dict(with_entries = true)` / `UnlockGraph.from_dict(data)` | `{"entries": [{"id", "requires", "requires_any", "cost"}], "unlocked": [...]}`; with `false`, only `{"unlocked": [...]}` |
| signals `unlocked(id)`, `locked(id)`, `availability_changed` | Past tense: it already happened |

### `UnlockEntry` (Node)

- **Inspector:** `id` (empty: the node's name), `title` (empty: the id), `description`, `icon`, `cost` (`{key: amount}`), `requires` (more entries of the same tree it requires, all of them, besides its parent), `requires_any` (entries of the same tree it requires one of), `start_unlocked` (unlocked when the graph is built and on `reset`, for free) and `view_position` (where its box goes in the view; (0, 0) is the automatic column).
- **Signals:** `unlocked` and `locked`, emitted by its tree.
- **Methods:** `entry_id()` (the id the graph uses) and `is_unlocked()`.
- **Editor warnings:** outside an `UnlockTree`; an empty slot in `requires` or `requires_any`, or a node there that is not an entry or belongs to another tree; a negative amount; a repeated id (on the one left out: the first one counts); a circle; and `start_unlocked` on an entry whose parent or `requires` do not start unlocked, or with none of `requires_any` starting unlocked.

### `UnlockTree` (Node)

- **Graph:** `graph` is the `UnlockGraph` it shows. `new_graph()` builds a new one from the entries (one per player), `use_graph(graph)` shows your rules' graph and `use_own_graph()` goes back to the one from the entries, from the start.
- **Methods:** the same as `UnlockGraph` (`buy`, `can_unlock`, `why_not`, `unlock`, `lock`, `cost_of`, `is_unlocked`, `unlocked_ids`, `available_ids`, `missing`, `requires`, `requires_any`, `restore`, `to_dict`), plus `reset()` (back to the start: in its own graph, with the `start_unlocked` entries unlocked; in one from `use_graph`, everything locked), `entry(id) -> UnlockEntry` (null when there is none), `entries()` (in tree order) and `title_of(id)` (its entry's `title`, or the id).
- **Signals:** `unlocked(id)`, `locked(id)`, `availability_changed` and `rebuilt` (it shows another graph or its entries changed: read everything again).
- **Editor warnings:** no entries, and the graph's `problems()`.

### `UnlockTreeView` (Control)

- **Inspector:** `tree` and `entry_scene`; under **Layout**, `direction` (`LEFT_TO_RIGHT` or `TOP_TO_BOTTOM`), `box_size`, `gap` (the space between boxes: x across, y down), `font_size` and `corner_radius`; under **Colors**, `unlocked_color`, `available_color`, `locked_color`, `line_color` and `text_color`.
- **Drawing:** one box per entry with its icon, its title and its cost ("2 points"), in the color of its state and with `corner_radius` corners, and a curve from each requirement to the entry (dashed for `requires_any`). The font comes from the game's theme: the `Label` font of a `Theme` on the view or an ancestor, or its `default_font`, or the project's; `font_size` sets the size.
- **Focus:** the drawn boxes answer only to the mouse. For keyboard and gamepad focus, use `entry_scene` with a `Button`. Its minimum size is the tree's: put it inside a `ScrollContainer` when the tree is big. It redraws itself with the tree's signals.
- **A scene per entry:** with `entry_scene`, the view instances your scene once per entry instead of drawing the box, and keeps drawing the curves. The contract:
  - the root is a `Control` whose script declares `var entry_id: StringName` and `var tree: UnlockTree`;
  - the view sets both before it enters the scene tree, and places it on its entry's box (position, and size `box_size`);
  - the scene reads its state from `tree` and listens to its signals (`unlocked`, `locked`, `availability_changed`, `rebuilt`);
  - when the root is a `BaseButton`, its `pressed` comes out as `entry_pressed` (keyboard and gamepad too); with any root, the pointer comes out as `entry_hovered`.
  So the box takes the game's `Theme` and focus. Without `entry_scene`, the view draws the boxes.
- **Tooltip:** title, description, cost and what is missing ("Needs: …", "Needs one of: …", or "Unlocked"). The texts go through `tr()`.
- **Signals:** `entry_pressed(id)` (left click on a box) and `entry_hovered(id)` (`&""` when it leaves). The view never unlocks: your game decides.
- **Methods:** `entry_at(point) -> StringName` and `box_rect(id) -> Rect2`.

## You want → write

| You want | Write |
|---|---|
| A tech that requires another | Put its `UnlockEntry` inside the other one |
| One that requires an entry of another branch | Add the other one to its `requires` |
| One of several to be enough | Put those in its `requires_any` |
| To group a branch without adding requirements | A plain `Node` between the tree and the entries |
| A tech you start with | `start_unlocked` on its entry |
| To buy | `tree.buy(id, pay)`: your `pay(cost) -> bool` charges all or nothing |
| To tell the player why not | `tree.why_not(id)` and `tree.missing(id)` |
| An effect when an entry is unlocked | Connect its `unlocked` signal in the Node panel |
| An effect for any entry | `tree.unlocked.connect(func(id): ...)` |
| The effect's data in the entry | A `@tool` script that `extends UnlockEntry` with typed `@export` fields ([above](#entries-with-data-of-their-own)) |
| Undo | `tree.lock(id)` and give back what you charged |
| The entries without requirements | `tree.requires(id).is_empty() and tree.requires_any(id).is_empty()` |
| Save and load | `save["unlocks"] = tree.unlocked_ids()` and later `tree.restore(save["unlocks"])` |
| One graph per player | `player.unlocks = tree.new_graph()` and `tree.use_graph(player.unlocks)` |
| A tree built in code | `var graph := UnlockGraph.new()` and `graph.add(&"irrigation", [&"farming"], {&"points": 2})` |
| Back to the start | `tree.reset()` |
| To see the tree | An `UnlockTreeView` with `tree` assigned |
| To move a box | `view_position` on its entry |
| A tree from top to bottom | `direction = TOP_TO_BOTTOM` on the view |
| The game's font in the boxes | A `Theme` on the view or an ancestor (its `Label` font or its `default_font`) |
| To move through the tree with keyboard or gamepad | `entry_scene` with a `Button` root |
| Boxes with your theme, focus and art | A scene with a `Button` root in `entry_scene` (see the contract above) |

## Tips

- **Stable ids.** If you save games, type the `id` yourself: renaming the node changes the id that comes from its name.
- **The rules use the graph, not the nodes.** In a game with several players, keep each one's `new_graph()` in the match state and show the active player's with `tree.use_graph()`. The view listens to `rebuilt` and redraws.
- **The costs are yours.** The kit does not know what `points` is: it can be a coin, a token or experience. Your `pay` charges it the way your game charges.
- **A big tree** fits in a `ScrollContainer`: the view asks for its minimum size.

## Tests

```bash
godot --headless --path unlockkit_lab --script res://addons/unlock_kit/tests/unlock_test_runner.gd
```

It prints `UNLOCKKIT TESTS PASS (n)`. The tests cover:

- The graph: entries, requirements added later, "all of them" and "one of", `why_not` and `missing`, `buy` (when it calls `pay` and what it does with what `pay` returns), `unlock` and `lock` with their signals, `availability_changed` once per call, `depth`, `restore`, the problems (unknown requirement, circles, also through `requires_any`) and `to_dict` (also after JSON and without the entries).
- The nodes: the graph from nested entries (a plain `Node` adds no requirement), `requires_any`, `buy`, a cost changed in the game, the signals per entry, live changes that keep what was unlocked (one rebuild per frame, none when the whole tree leaves), `new_graph` per player, `use_graph` and its warning, one instance per player, `reset`, an entry with data of its own and the editor warnings (also `start_unlocked` under a locked entry).
- The view: columns by depth (or rows, top to bottom), `view_position`, `corner_radius` and the theme's font, the minimum size, clicks, hover, tooltips (also "one of"), `entry_scene` and redrawing with the tree.
- The example played with clicks on the boxes and the buttons, and the scene ready without running it (what the editor shows).
- That the addon names no other kit.

The lab also has a check inside the real editor: see `unlockkit_lab/README.md`.
