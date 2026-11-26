# Addons (Godot)

Reusable pieces of the framework. Copy them to `res://addons/<name>/` in **each** game. Zero match rules, product copy, or scenes.

| Addon | Role |
|-------|------|
| `mp_kit` | Multiplayer with nodes and no hand-written RPCs: the game in one `.tres` (`MpGame`), the world in one node (`MpWorld`), `MpActor` / `MpInput` / `MpState`, prediction and lag compensation; solo, LAN, dedicated, online rooms with one dedicated per match, private match, web and relay; the *Setup game* wizard. No gameplay |
| `fsm_kit` | `FsmMachine` + `FsmState` (no autoload) |
| `plat_kit` | 2D motor: coyote, jump buffer, apex, corner, lift (no levels) |
| `rts_kit` | RTS command layer, 2D and 3D: units, selection and groups, orders in formations, command input (optional command panel / radial menu), RTS cameras. No network, no movement or combat |
| `prop_kit` | Props, 2D and 3D: scatter over any ground (clusters, keep-outs, masks, variants), batch drawing (3D), the navmesh in zones with props as cheap obstructions and partial re-bakes on worker threads. No network, no prop behavior |
| `grass_kit` | Grass, 3D: blades drawn on the GPU around the camera in cells that move with it, painted by hand with brushes in the 3D view, a ground read from the colliders (heights, normals, slope), clearings, trampling, a look that changes in play. No network, no game rules |
| `perception_kit` | Perception, 2D and 3D: a view cone with a farther lose radius, near awareness, walls that hide, noises, any sense of the game's own, a memory that forgets, sides as physics layers, handles to drag the view in the editor. No network, no states or combat |
| `spill_kit` | What a body spills, 3D: blood, ichor, oil, slime, ink. Every hit sprays drops and leaves marks on the floor that stay; a death grows a puddle that follows the slope. Each substance is a type with the kit's wet look, PBR textures of its own (albedo, normal, ORM) or the game's shader. Rules as values, one synced property for the network, Compatibility and WebGL 2, nothing drawn on a dedicated server. No HP, damage or network |
| `grid_kit` | Boards of hexagons or squares with the same API: `CellGrid` (`HexGrid` and `SquareGrid`; plain data: values per cell, neighbors, distance, range, paths, flood, `to_dict`), the map as a `GridLayout` (a `.tres`) and nodes to show it and pick cells in 3D (`GridBoard`, `GridView3D`, `GridCursor`), fog of war per player (`CellFog` and `GridFog`: hidden, explored, visible), with a brush in the editor's 3D view. No game rules, no network |
| `turn_kit` | Turns, rounds and cycles: `TurnCycle` (plain data: actions per turn, rounds, cycles and an end you set, inactive seats and, optional, a first player that rotates, phases inside the turn, time per turn and initiative, `to_dict`) and a clock with one child per player (`TurnClock`, `TurnSeat`). No game rules, no network |
| `wallet_kit` | Resources and coins: `Purse` (plain data: amounts by key, limits that report what is lost, all-or-nothing payments, substitutes with a rate that cover what is missing (`WalletSubstitute`), `payment_for` to show the cost, `to_dict`) and the `Wallet` node. No prices or UI, no network |
| `command_kit` | Validated moves with a history: each move is a function of your game (`do_<name>(seat, args…)`, with `can_<name>` giving the rejection reason and an optional `undo_<name>`); `CommandLog` (plain data: runs only valid ones, keeps `{name, seat, args}`, undoes the last one, replays a history) and the `GameCommands` node. No game rules, no randomness, no network |
| `unlock_kit` | Unlock trees: `UnlockGraph` (plain data: what can be unlocked now, requirements that are all needed (`requires`) or of which one is enough (`requires_any`), a cost the kit never charges: `buy(id, pay)` takes the function that charges; `why_not`, `lock` to undo, `to_dict`), the `UnlockTree` node built from `UnlockEntry` children (one inside another requires it; `new_graph()` gives one graph per player) and an `UnlockTreeView` that draws the tree, in the editor too and with a scene of your own per entry. No effects, no network |
| `stat_kit` | Stats with bonuses: `StatSheet` (plain data: one base per stat and `StatModifier`s that add, add percentages, multiply or fix, in ADD → PERCENT → MUL → SET order; limits per stat; the source is given when adding and `remove_source` takes away everything of one; `stat_changed` only on a real change, `to_dict`) and the `StatBlock` node, which shows the final values in the inspector. No items, inventory, buff durations or UI, no network |
| `deck_kit` | Cards: `CardStack` (plain data: a pile in order with index 0 on top, copies by index, drawing, moving between piles, shuffling with your `RandomNumberGenerator`, refilling from the discard, `to_dict`), the `CardData` resource, the `CardPile` and `Deck` nodes (with `rng_seed` or the match's rng) and a `HandView` that shows a hand in a fan, drawn or with a scene per card, in the editor too. No card rules, costs or turns, no network |
| `dice_kit` | Dice: `DieData` (faces with a value, tags and an icon; d4 to d20 ready) and `DiceRoll` (plain data: `sum()`, `count(tag)`, the highest or lowest, rerolling some, mixed dice, `to_dict`), rolled with your `RandomNumberGenerator` (same seed, same rolls), the `DiceRoller` node (a Roll button in the inspector, extra dice) and `DiceTray3D` (the dice tumble and land in 3D, with your mesh). No game rules, no physics, no network |
| `bot_kit` | Bots that play your character like a person, 3D: they press a player's keys (an `Input` of their own), see the nearest enemy with no wall in between, aim with a person's limits, pick the weapon by distance, walk the navmesh to goals and get out of where they are stuck; your own behaviours as child nodes, difficulty presets. No network, no weapons or health |

Every addon ships a **minimal example** (`examples/minimal_2d/` or `examples/minimal_3d/`: the smallest integration that works, F6) and, in its README, that code explained with **tips and recommendations**. The table with all of them is in the [repo README](../README.md#each-kits-examples).

**AgentKit** does not live here: [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest). `./install.sh --addon … agent_kit` fetches it from that repo's `main` branch (AgentKit 0.1.6, with the `determinism` module; another branch with `GODOT_STUDIO_PLAYTEST_REF`). `example/addons/agent_kit/` here is a reference copy.

New addons belong here when a second game (or a second feature) needs them. No per-title forks.

Install into a project:

```bash
./install.sh --addon /path/to/godot-project
./install.sh --addon /path/to/godot-project agent_kit
./install.sh --addon /path/to/godot-project fsm_kit
./install.sh --addon /path/to/godot-project plat_kit
./install.sh --addon /path/to/godot-project rts_kit
./install.sh --addon /path/to/godot-project prop_kit
./install.sh --addon /path/to/godot-project grass_kit
./install.sh --addon /path/to/godot-project perception_kit
./install.sh --addon /path/to/godot-project spill_kit
./install.sh --addon /path/to/godot-project bot_kit
./install.sh --addon /path/to/godot-project grid_kit
./install.sh --addon /path/to/godot-project turn_kit
./install.sh --addon /path/to/godot-project wallet_kit
./install.sh --addon /path/to/godot-project command_kit
./install.sh --addon /path/to/godot-project unlock_kit
./install.sh --addon /path/to/godot-project stat_kit
./install.sh --addon /path/to/godot-project deck_kit
./install.sh --addon /path/to/godot-project dice_kit
```
