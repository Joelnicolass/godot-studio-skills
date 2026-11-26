# Godot studio kit

A small studio for **Claude Code or Cursor + Godot 4**: the chat does not “make the game”, it **orchestrates**. It interviews you, writes PRD/RFCs, and hands plan / code / review to subagents. The result is not a thousand-line `World.gd`: it is a **small, playable, clear base** that a human (or another AI) can continue from the inspector.

Repo: https://github.com/Joelnicolass/godot-studio-skills — English on `main`, Spanish on `release/spanish`.

## Why this exists

Without the kit, an agent often:

- Loses development context.
- Assumes an architecture, or mixes several in the same build.
- Creates scripts with too many responsibilities: mixing score, spawn, VFX, etc.
- Implements the whole product in one turn, with no PRD or RFC.
- Skips the testing phase before delivering the implementation.

With the kit:

- **You** choose the project size (by entity, the recommended one, or systems + content) **before** any folder is created. You get a structure where each thing can be found: `docs/tuning.md` says what to open to change each value.
- **You** choose whether there is multiplayer and which type (none · local/Wi-Fi · online)
- Simple and predictable comes first: each feature is scene(s) with one owner per number (the `.tres` of its type, or the scene root), not a `match kind`. If changing a number means opening more than 2 files, the design is wrong.
- A person sees it and tunes it in the editor: each `@export` with a tooltip, a range, and a unit, and what shows at runtime shows when the scene is opened.
- Standard Godot code: proven patterns (signals, `Events` bus, FSM, components…), real typing, `gdformat` / `gdlint`, and GUT + CI when there are tests (skill `godot-code-quality`).
- One RFC at a time, with a **file tree** approved, review, playtest and visual pass if you ask
- MpKit kept off gameplay; notes across sessions in Engram or `.studio/MEMORY.md` if needed.
- The game lives in **another** repo; this one has skills, commands, agents, and addons (MpKit, FsmKit, PlatKit, RtsKit, PropKit, GrassKit, PerceptionKit, SpillKit, BotKit, GridKit, TurnKit, WalletKit, CommandKit, UnlockKit, StatKit, DeckKit, DiceKit, GestureKit). AgentKit / playtester: [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest)

| Piece               | Where                                                                          | What it is                                                                                       |
| ------------------- | ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------ |
| Orchestrator        | `skills/godot-studio-workflow/`                                                | The chat agent: interview + `/implement-feature` (PRD/RFC optional)                              |
| How to write Godot  | `skills/`                                                                      | Architecture, composition, code quality, MpKit, FSM, 2D platformer, RTS controls, props and their navmesh, grass, perception, blood and other substances, bots, boards, turns, resources and moves, touch gestures, juicy, materials, feature research, visual, memory, tests and CI, a determinism bench (with AgentKit) |
| Subagents           | `agents/`                                                                      | Tech lead, developer, reviewer; optional tester and visual. Playtester: playtest module         |
| Commands            | `commands/`                                                                    | `/implement-feature`, `/add-juicy`, `/add-state-machine`, `/add-platformer-2d`, `/add-rts-controls`, `/add-props`, `/add-grass`, `/add-perception`, `/add-spill`, `/add-bots`, `/add-grid`, `/add-turns`, `/add-wallet`, `/add-commands`, `/add-unlocks`, `/add-stats`, `/add-deck`, `/add-dice`, `/add-gestures`, `/create-prd`, … |
| MpKit               | `addons/mp_kit/`                                                               | Multiplayer with nodes and no hand-written RPCs: the game in one `.tres` (`MpGame`), the world in one node (`MpWorld`), the match's verbs in `Mp`, plus `MpActor`, `MpInput`, `MpState`, `MpMatch` and `MpOrders` (the moves of a turn-based game, or one with no pawns). Prediction, adaptive buffers, lag compensation and network quality; LAN, dedicated, online rooms, private matches, web, a relay for servers without a public IP (Railway), VPS deploy and a *Setup game* wizard. **Zero** gameplay. Start with `addons/mp_kit/QUICKSTART.md` (step by step: `GUIDE.md`); game-free checks in `mpkit_lab/run/all.sh`. |
| AgentKit            | [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest) | Agent CLI + harness. This kit installs it; it is not maintained here.                            |
| FsmKit              | `addons/fsm_kit/`                                                              | `FsmMachine` + `FsmState`. No autoload.                                                          |
| PlatKit             | `addons/plat_kit/`                                                             | 2D motor: coyote, buffer, apex, corner, lift. No levels or score.                                |
| RtsKit              | `addons/rts_kit/`                                                              | RTS controls for 2D and 3D: units, selection and groups, typed orders in formations, command input (command panel and radial menu optional), RTS cameras with touch. No network inside; no movement or combat. Start with `addons/rts_kit/GUIDE.md` (includes MpKit); tests in `rtskit_lab/`. |
| PropKit             | `addons/prop_kit/`                                                             | Props for 2D and 3D: scatter over any ground as saved nodes (clusters, keep-outs, masks, variants), batch drawing (3D), and the navmesh baked in zones with props as cheap obstructions, re-baking only what changed on worker threads. No network inside; no prop behavior. Start with `addons/prop_kit/README.md`; tests in `propkit_lab/`. |
| GrassKit            | `addons/grass_kit/`                                                            | Grass for 3D: blades drawn on the GPU around the camera in cells that move with it, painted by hand with brushes in the 3D view (where it grows, how tall, the ground's colour, flower patches), tiers that thin with distance without popping, a ground read from the colliders (exact heights, normals, slope fade), clearings, trampling, a look that changes in play. No network inside. Start with `addons/grass_kit/README.md`; tests in `grasskit_lab/`. |
| PerceptionKit       | `addons/perception_kit/`                                                       | What an actor perceives, in 2D and 3D: a view cone that keeps seeing until farther, all-around awareness up close, walls that hide, noises heard, any sense of the game's own (light, alarms), a memory that forgets with the last position, sides as physics layers, and handles to drag the view in the editor. No network inside; no states or combat. Start with `addons/perception_kit/README.md`; tests in `perceptionkit_lab/`. |
| SpillKit            | `addons/spill_kit/`                                                            | What a body spills, in 3D (blood, ichor, oil, slime, ink): every hit sprays and marks the floor, a death grows a puddle that follows the slope; each substance is a type with the kit's wet look, PBR textures of its own or the game's shader; rules as values, one synced property for the network, Compatibility and WebGL 2, buttons to try it in the editor |
| BotKit              | `addons/bot_kit/`                                                              | Bots that play your character like a person, in 3D: a node that presses a player's keys (an `Input` of its own your character reads), sees the nearest enemy with no wall in between, aims with a person's limits (reaction, error, cone, bursts, leading and lobbing), picks the weapon by distance, walks the navmesh to pickups, to where it saw the enemy or anywhere, and gets out of where it is stuck; your own behaviours as child nodes, difficulty presets, its sight and handles in the editor. And `BotBrain`, which picks by score with no body (a turn-based, card or strategy bot), with noise and a seed. No network inside. Start with `addons/bot_kit/README.md`; tests in `botkit_lab/`. |
| GridKit             | `addons/grid_kit/`                                                             | Boards of hexagons or squares with the same API: `CellGrid` (`HexGrid` and `SquareGrid`; plain data: values per cell, neighbors, distance, range, paths, flood, `to_dict`), the map as a `GridLayout` (a `.tres`) and nodes to show it and pick cells in 3D (`GridBoard`, `GridView3D`, `GridCursor`), fog of war per player (`CellFog` and `GridFog`: hidden, explored, visible), with a brush in the editor's 3D view (terrain, cells and heights). No game rules, no network. Start with `addons/grid_kit/README.md`; tests in `gridkit_lab/`. |
| TurnKit             | `addons/turn_kit/`                                                             | Turns, rounds and cycles: `TurnCycle` (plain data: actions per turn, rounds, cycles and an end you set, inactive seats and, optional, a first player that rotates, phases inside the turn, time per turn and initiative, `to_dict`) and a clock with one child per player (`TurnClock`, `TurnSeat`). No game rules, no network. Start with `addons/turn_kit/README.md`; tests in `turnkit_lab/`. |
| WalletKit           | `addons/wallet_kit/`                                                           | Resources and coins: `Purse` (plain data: amounts by key, limits that report what is lost, all-or-nothing payments, substitutes with a rate that cover what is missing (`WalletSubstitute`), `payment_for` to show the cost, `to_dict`) and the `Wallet` node. No prices or UI, no network. Start with `addons/wallet_kit/README.md`; tests in `walletkit_lab/`. |
| CommandKit          | `addons/command_kit/`                                                          | Validated moves with a history: each move is a function of your game (`do_<name>(seat, args…)`, with `can_<name>` giving the rejection reason and an optional `undo_<name>`); `CommandLog` (plain data: runs only valid ones, keeps `{name, seat, args}`, undoes the last one, replays a history) and the `GameCommands` node. No game rules, no randomness, no network. Start with `addons/command_kit/README.md`; tests in `commandkit_lab/`. |
| UnlockKit           | `addons/unlock_kit/`                                                           | Unlock trees: `UnlockGraph` (plain data: what can be unlocked now, requirements that are all needed (`requires`) or of which one is enough (`requires_any`), a cost the kit never charges: `buy(id, pay)` takes the function that charges; `why_not`, `lock` to undo, `to_dict`), the `UnlockTree` node built from `UnlockEntry` children (one inside another requires it; `new_graph()` gives one graph per player) and an `UnlockTreeView` that draws the tree, in the editor too and with a scene of your own per entry. No effects, no network. Start with `addons/unlock_kit/README.md`; tests in `unlockkit_lab/`. |
| StatKit             | `addons/stat_kit/`                                                             | Stats with bonuses: `StatSheet` (plain data: one base per stat and `StatModifier`s that add, add percentages, multiply or fix, in ADD → PERCENT → MUL → SET order; limits per stat; the source is given when adding and `remove_source` takes away everything of one; `stat_changed` only on a real change, `to_dict`) and the `StatBlock` node, which shows the final values in the inspector. No items, inventory, buff durations or UI, no network. Start with `addons/stat_kit/README.md`; tests in `statkit_lab/`. |
| DeckKit             | `addons/deck_kit/`                                                             | Cards: `CardStack` (plain data: a pile in order with index 0 on top, copies by index, drawing, moving between piles, shuffling with your `RandomNumberGenerator`, refilling from the discard, `to_dict`), the `CardData` resource, the `CardPile` and `Deck` nodes (with `rng_seed` or the match's rng) and a `HandView` that shows a hand in a fan, drawn or with a scene per card, in the editor too. No card rules, costs or turns, no network. Start with `addons/deck_kit/README.md`; tests in `deckkit_lab/`. |
| DiceKit             | `addons/dice_kit/`                                                             | Dice: `DieData` (faces with a value, tags and an icon; d4 to d20 ready) and `DiceRoll` (plain data: `sum()`, `count(tag)`, the highest or lowest, rerolling some, mixed dice, `to_dict`), rolled with your `RandomNumberGenerator` (same seed, same rolls), the `DiceRoller` node (a Roll button in the inspector, extra dice) and `DiceTray3D` (the dice tumble and land in 3D, with your mesh). No game rules, no physics, no network. Start with `addons/dice_kit/README.md`; tests in `dicekit_lab/`. |
| GestureKit          | `addons/gesture_kit/`                                                          | Touch gestures Godot does not have: taps with several fingers, double tap, long press, swipe, drag with the velocity on release, pinch and twist. A `GestureArea` (Control) that reports with signals or presses Input Map actions, and a plain-data `GestureReader`. The mouse is a finger (Alt + drag is two). No stick or buttons (Godot has them), no camera. Start with `addons/gesture_kit/README.md`; tests in `gesturekit_lab/`. |

What **does not** belong here: score, product copy, a title’s scenes, `GameSession`, `SceneDirector`. That is game code.

## How it works

The details (orchestrator diagrams, roles, the two project sizes, multiplayer types, the iteration flow, art/shaders) live in [docs/architecture.md](docs/architecture.md). Interactive diagrams: [the flow of one feature](https://joelnicolass.github.io/godot-studio-skills/en.html) and [a kit in your game](https://joelnicolass.github.io/godot-studio-skills/kits-en.html) (sources in [docs/diagram/](docs/diagram/README.md)). In short: interview → `/implement-feature` → one OK on the tree (includes `res://debug/` when needed) → developer → reviewer → playtester on that scene → the orchestrator classifies the FAIL → close on `FEATURES.md`. A visual pass is asked. The slice contract is the `F<n>`, not a mandatory RFC.

## Install (Claude Code or Cursor)

```bash
./install.sh --claude            # ~/.claude/skills, commands, agents
./install.sh                     # ~/.cursor/skills, commands, agents (default)
./install.sh --all               # both
./install.sh --claude --project  # ./.claude/ of cwd (without --claude: ./.cursor/)
```

From GitHub:

```bash
npx skills add Joelnicolass/godot-studio-skills -g -a claude-code -y   # or -a cursor
npx skills add Joelnicolass/godot-studio-playtest -g -a claude-code -y
```

`npx skills` only copies `skills/`. Commands, subagents, and the addons go through `./install.sh` (this installer also pulls the playtest module). Uninstall: `./uninstall.sh` with the same flags (`--claude`, `--all`, `--project`).

Open a **new session** after installing. In Claude Code, `/agents` lists the `studio-*` roles and `/` shows the commands.

### What differs between Claude Code and Cursor

The same files serve both; the kit keeps no per-harness copy.

| Piece          | Claude Code                                                                                 | Cursor                                    |
| -------------- | ------------------------------------------------------------------------------------------- | ----------------------------------------- |
| Skills         | `~/.claude/skills/<skill>/SKILL.md`                                                         | `~/.cursor/skills/<skill>/SKILL.md`       |
| Commands       | `~/.claude/commands/*.md` → `/implement-feature`. Uses `description` / `argument-hint`      | `~/.cursor/commands/*.md`                 |
| Subagents      | `~/.claude/agents/*.md`. Read-only through `disallowedTools`; `skills:` preloads the role’s | `~/.cursor/agents/*.md`. `readonly: true` |
| Launch a role  | `Agent` tool (`subagent_type`)                                                              | `Task` tool (`subagent_type`)             |
| Ask the user   | `AskUserQuestion`                                                                           | `AskQuestion`                             |
| MCP (optional) | `.mcp.json` at the game root or `claude mcp add`                                            | `.cursor/mcp.json`                        |
| Game rules     | `CLAUDE.md` importing `@RULES.md` (see [`example/CLAUDE.md`](example/CLAUDE.md))            | `AGENTS.md` or `.cursor/rules/`           |

In Claude Code, subagents do not ask the user or launch other subagents: they return the open question and the orchestrator asks. `./install.sh --addon … agent_kit` also drops the workspace rule into the game (the playtest module writes it): `.cursor/rules/` for Cursor and, from playtest v0.3.0 on, `.claude/rules/` for Claude Code.

## Product commands

Short path (default):

1. `/implement-feature` — one feature or the vertical slice (tree → OK → code → review). Grows `FEATURES.md`.
2. `/add-juicy` — juicy feel (shake, VFX, post, impact) on an event that already exists
3. `/add-state-machine` — `FsmMachine` + child states (FsmKit addon)
4. `/add-platformer-2d` — coyote, jump buffer, apex, corner (PlatKit addon)
5. `/add-rts-controls` — units, selection, groups, orders in formations, RTS camera (RtsKit addon)
6. `/add-props` — scattered props, batch drawing, a navmesh baked in zones that they cut (PropKit addon)
7. `/add-grass` — grass around the camera on the GPU, over the ground's colliders, painted by hand in the 3D view (GrassKit addon)
8. `/add-perception` — actors that see, hear and remember, with a view cone dragged in the editor, 2D or 3D (PerceptionKit addon)
9. `/add-spill` — blood and other substances: sprays, marks on the floor and a puddle on death, with PBR of their own or the game's shader, in 3D (SpillKit addon)
10. `/add-bots` — bots that play your character like a person: they see, aim, pick a weapon, walk the level, with difficulty presets, in 3D; or a turn-based bot that picks by score (`BotBrain`) (BotKit addon)
11. `/add-grid` — boards of hexagons or squares: the saved map, painted in the 3D view, one scene per cell with click and hover, cursors (GridKit addon)
12. `/add-turns` — turns: whose it is, actions, phases, time per turn, rounds, cycles and a rotating first player (TurnKit addon)
13. `/add-wallet` — resources and coins: limits, all-or-nothing payments, substitutes with a rate and the cost to show (WalletKit addon)
14. `/add-commands` — validated moves with a rejection reason, undo and a history that is saved and replayed (CommandKit addon)
15. `/add-unlocks` — unlock trees: what can be unlocked, what needs what (all of or one of) and what it costs, buying in one call, built in the editor (UnlockKit addon)
16. `/add-stats` — stats with bonuses: ADD → PERCENT → MUL → SET, limits, sources taken away at once and final values in the inspector (StatKit addon)
17. `/add-deck` — cards: a seeded deck, a hand, a discard, drawing, shuffling and refilling, copies of a card, a fanned hand (DeckKit addon)
18. `/add-dice` — dice: faces with numbers or symbols, sum and count by tag, advantage and rerolls, seed, a 3D tray (DiceKit addon)
19. `/add-gestures` — touch gestures: taps with several fingers, double tap, long press, swipe, drag and throw, pinch and twist, with the mouse as a finger (GestureKit addon)
20. `/new-mp-feature` — MpKit actor scaffold only
21. `/create-material` — procedural material / texture with [Material Maker](https://github.com/RodZill4/material-maker) → `.tres`
22. `/research-feature` — understand a mechanic of a similar game (web research, and decompiling it when it can be opened) before implementing it
23. `/workflow-status`

Written contract, if you ask:

24. `/create-prd` → `PRD.md` (short **living** GDD, not the whole title)
25. `/verify-prd` → `PRD-REVIEW.md`
26. `/extract-features` → `FEATURES.md`
27. `/generate-rules` → `RULES.md`
28. `/create-visual-guide` → `VISUAL.md`
29. `/generate-rfcs` → `RFCs/` + `RFCS.md`
30. `/implement-rfc <id>`
31. `/review-rfc <id>`
32. `/manage-changes`
33. `/test-strategy` — optional

## Install addons in a Godot project

```bash
./install.sh --addon /path/to/godot-project            # MpKit
./install.sh --addon /path/to/godot-project fsm_kit    # FsmKit
./install.sh --addon /path/to/godot-project plat_kit   # PlatKit
./install.sh --addon /path/to/godot-project rts_kit    # RtsKit
./install.sh --addon /path/to/godot-project prop_kit   # PropKit
./install.sh --addon /path/to/godot-project grass_kit  # GrassKit
./install.sh --addon /path/to/godot-project perception_kit  # PerceptionKit
./install.sh --addon /path/to/godot-project spill_kit  # SpillKit
./install.sh --addon /path/to/godot-project bot_kit    # BotKit
./install.sh --addon /path/to/godot-project grid_kit   # GridKit
./install.sh --addon /path/to/godot-project turn_kit   # TurnKit
./install.sh --addon /path/to/godot-project wallet_kit # WalletKit
./install.sh --addon /path/to/godot-project command_kit # CommandKit
./install.sh --addon /path/to/godot-project unlock_kit # UnlockKit
./install.sh --addon /path/to/godot-project stat_kit   # StatKit
./install.sh --addon /path/to/godot-project deck_kit   # DeckKit
./install.sh --addon /path/to/godot-project dice_kit   # DiceKit
./install.sh --addon /path/to/godot-project gesture_kit # GestureKit
./install.sh --addon /path/to/godot-project agent_kit  # AgentKit (fetched from the playtest repo)
```

Enable each plugin in Project → Plugins. MpKit also needs the autoload (`MpKit="*res://addons/mp_kit/mp_kit.gd"`); first steps in `addons/mp_kit/QUICKSTART.md`, reference in `addons/mp_kit/README.md`, editor in `skills/godot-mp-kit/editor.md`, online/VPS in `skills/godot-mp-kit/dedicated.md`. AgentKit lives in [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest): JSON/harness live in the game’s `res://agent/`; details in that repo’s README. PlatKit is not a Celeste clone: dash/stamina stay in the game. RtsKit commands, the game acts: it hands each unit its order and the game walks and fights (`addons/rts_kit/README.md`). PropKit places props and keeps their navmesh cheap; what a prop does stays in the game (`addons/prop_kit/README.md`). GrassKit draws grass around the camera over the game's ground; the ground's data and when it changes are the game's (`addons/grass_kit/README.md`). PerceptionKit says what an actor sees, hears and remembers; what it does about it stays in the game (`addons/perception_kit/README.md`).

External tools the flow **offers** when needed (never installed without asking): [Material Maker](https://github.com/RodZill4/material-maker) for procedural materials and textures (skill `godot-material-maker`), and a decompiler (gdsdecomp, ILSpy, …) to open a similar game when researching a mechanic (skill `godot-feature-research`). Same as the Aseprite and Blender MCPs.

A ready demo lives in [`example/`](example/README.md) (1P, LAN, dedicated, 2D and 3D worlds with placeholders, PRD→RFC flow). VS Code/Cursor snippets: `.vscode/mpkit.code-snippets` (the installer copies them).

## Each kit's examples

Every kit ships a **minimal example**: the smallest integration that works, to open and press F6, with its code explained in the kit's README next to **tips and recommendations**. Each kit's tests play its examples.

| Kit | Minimal example | Full examples | README | Tests |
|---|---|---|---|---|
| MpKit | `addons/mp_kit/examples/minimal_2d/boot.tscn`: what *Setup game* writes (menu, world, predicted player) | `arena_2d/boot.tscn`, `bots_2d/boot.tscn` (the host starts, bots in the free seats, late join), `sports_2d/boot.tscn` (two against two with a ball: a predicted slide, a lag-compensated tackle), `turns_2d/boot.tscn` (three in a row by turns, with no pawns, through `MpOrders`) | [QUICKSTART](addons/mp_kit/QUICKSTART.md) | `mpkit_lab/run/all.sh` |
| FsmKit | `addons/fsm_kit/examples/minimal_2d/minimal_2d.tscn`: `Idle`, `Move`, `Hurt` with a payload | — | [README](addons/fsm_kit/README.md) | `fsmkit_lab/` |
| PlatKit | `addons/plat_kit/examples/minimal_2d/minimal_2d.tscn`: a player and two ledges, no code | — | [README](addons/plat_kit/README.md) | `platkit_lab/` |
| RtsKit | `addons/rts_kit/examples/minimal_2d/minimal_2d.tscn`: six soldiers and the command rig | `skirmish_3d`, `skirmish_2d` | [GUIDE](addons/rts_kit/GUIDE.md) | `rtskit_lab/` |
| PropKit | `addons/prop_kit/examples/minimal_3d/minimal_3d.tscn`: trees around a camp, in batches | `forest_3d`, `grove_2d` | [README](addons/prop_kit/README.md) | `propkit_lab/` |
| GrassKit | `addons/grass_kit/examples/minimal_3d/minimal_3d.tscn`: a floor and a field, with the ground shader | `grass_3d` | [README](addons/grass_kit/README.md) | `grasskit_lab/` |
| PerceptionKit | `addons/perception_kit/examples/minimal_3d/minimal_3d.tscn`: a guard turning its head toward what it perceives (and `minimal_2d`) | `guards_3d` | [README](addons/perception_kit/README.md) | `perceptionkit_lab/` |
| SpillKit | `addons/spill_kit/examples/minimal_3d/minimal_3d.tscn`: a dummy that bleeds, marks the floor and leaves a puddle | `substances_3d` (six substances: the kit's look, PBR of their own, a shader of their own) | [README](addons/spill_kit/README.md) | `spillkit_lab/` |
| BotKit | `addons/bot_kit/examples/minimal_3d/minimal_3d.tscn`: a robot that hunts you round some walls | `arena_3d` (four bots, rifle and grenades, pickups, fleeing when hurt), `turn_based` (a villager by turns that picks by score) | [README](addons/bot_kit/README.md) | `botkit_lab/` |
| GridKit | `addons/grid_kit/examples/minimal_3d/minimal_3d.tscn`: a hexagon board of radius 4 that comes from a `GridLayout`; a click marks the cell and its neighbors | `squares_3d` (8 × 8 squares: range and path), `fog_3d` (two players' fog) | [README](addons/grid_kit/README.md) | `gridkit_lab/` |
| TurnKit | `addons/turn_kit/examples/minimal/minimal.tscn`: three seats pass the turn with phases (`draw`, `play`) and 10 seconds per turn, the first seat of each round rotates and the match ends after two cycles | — | [README](addons/turn_kit/README.md) | `turnkit_lab/` |
| WalletKit | `addons/wallet_kit/examples/minimal/minimal.tscn`: harvest under limits that lose the excess and build with substitutes that have a rate (2 food cover 1 wood, gold covers anything 1 to 1) | — | [README](addons/wallet_kit/README.md) | `walletkit_lab/` |
| CommandKit | `addons/command_kit/examples/minimal/minimal.tscn`: stones in turns on a 5 × 5 board with `do_place`, `can_place` and `undo_place`, with occupied cells rejected, Undo and Replay | — | [README](addons/command_kit/README.md) | `commandkit_lab/` |
| UnlockKit | `addons/unlock_kit/examples/minimal/minimal.tscn`: nine techs in three branches of nested `UnlockEntry` nodes, a cross link, a one-of and a starting tech, drawn by an `UnlockTreeView`; a click on the view buys with points (`tree.buy`) | — | [README](addons/unlock_kit/README.md) | `unlockkit_lab/` |
| StatKit | `addons/stat_kit/examples/minimal/minimal.tscn`: a hero card with a sword, a shield and a swamp put on and taken off, and a two-bonus blessing that stacks and goes away with `remove_source` | — | [README](addons/stat_kit/README.md) | `statkit_lab/` |
| DeckKit | `addons/deck_kit/examples/minimal/minimal.tscn`: a 12-card deck (three copies of one), draw to a hand of 5 that uses a scene of its own per card, discard with a click, refill the deck shuffled and deal with a seed (same seed, same order) | — | [README](addons/deck_kit/README.md) | `deckkit_lab/` |
| DiceKit | `addons/dice_kit/examples/minimal/minimal.tscn`: a die of its own (3 hit, 2 blank, 1 crit) rolled 1, 2 or 3 at a time on a 3D tray; the same seed brings back the same rolls | — | [README](addons/dice_kit/README.md) | `dicekit_lab/` |
| GestureKit | `addons/gesture_kit/examples/minimal/minimal.tscn`: a card that is dragged and thrown, pinched and twisted with two fingers (Alt + drag with the mouse), comes back with a double tap, is marked by holding it and changes color with a swipe | — | [README](addons/gesture_kit/README.md) | `gesturekit_lab/` |

Each lab is a small Godot project with the kit as a symlink; its README says how to run the tests.

## Layout

```
docs/                          # architecture and flow in detail
example/                       # Godot 4.7 demo (1P + LAN + dedicated, 2D and 3D)
addons/mp_kit/
addons/fsm_kit/
addons/plat_kit/
addons/rts_kit/
addons/prop_kit/
addons/grass_kit/
addons/perception_kit/
addons/spill_kit/
addons/bot_kit/
addons/grid_kit/
addons/turn_kit/
addons/wallet_kit/
addons/command_kit/
addons/unlock_kit/
addons/stat_kit/
addons/deck_kit/
addons/dice_kit/
addons/gesture_kit/
mpkit_lab/                     # MpKit's tests, network runs and examples, no game
fsmkit_lab/                    # FsmKit's tests and example, no game
platkit_lab/                   # PlatKit's tests and example, no game
rtskit_lab/                    # RtsKit's tests and examples, no game
propkit_lab/                   # PropKit's tests and examples, no game
gridkit_lab/                   # GridKit tests and example, no game
turnkit_lab/                   # TurnKit tests and example, no game
walletkit_lab/                 # WalletKit tests and example, no game
commandkit_lab/                # CommandKit tests and example, no game
unlockkit_lab/                 # UnlockKit tests and example, no game
statkit_lab/                   # StatKit tests and example, no game
deckkit_lab/                   # DeckKit tests and example, no game
dicekit_lab/                   # DiceKit tests and example, no game
gesturekit_lab/                # GestureKit tests and example, no game
grasskit_lab/                  # GrassKit's tests and examples, no game
perceptionkit_lab/             # PerceptionKit's tests and examples, no game
spillkit_lab/                  # SpillKit's tests and examples, no game
botkit_lab/                    # BotKit's tests and examples, no game
skills/
  godot-studio-workflow/
  godot-studio-memory/
  godot-layered-architecture/
  godot-composition-first/
  godot-code-quality/
  godot-mp-kit/
  godot-visual-qa/
  godot-testing/
  godot-animation/
  godot-juicy/
  godot-fsm/
  godot-platformer-2d/
  godot-rts-kit/
  godot-prop-kit/
  godot-grass-kit/
  godot-perception-kit/
  godot-spill-kit/
  godot-bot-kit/
  godot-grid-kit/
  godot-turn-kit/
  godot-wallet-kit/
  godot-command-kit/
  godot-unlock-kit/
  godot-stat-kit/
  godot-deck-kit/
  godot-dice-kit/
  godot-gesture-kit/
  godot-material-maker/
  godot-feature-research/
  godot-determinism/
agents/                        # studio-tech-lead, studio-developer, …
commands/
install.sh
```

AgentKit, `/agent-kit`, `studio-playtester`, and the flow editor: [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest).

How the framework grows: extract into `addons/` or `skills/` when something is reused. Do not copy an FX or a score tracker “just in case”.

## License

[MIT](LICENSE).
