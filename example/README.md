# MpKit Example

Minimal demo of the [Godot studio kit](../README.md): **not a game**. It shows MpKit (1P, listen-server, dedicated), composition, `.tres` Resources, and the product flow (PRD → FEATURES → RULES → RFCs → code).

Architecture: **by entity** (one folder per topic; see [`docs/architecture.md`](docs/architecture.md)). Art: placeholders. UI in English on this branch: the texts are in `locale/texts.csv` and the language comes from `internationalization/locale/*` in `project.godot`. Where to change each thing: [`docs/tuning.md`](docs/tuning.md).

## Open

Godot **4.7**. Open the `example/` folder as a project.

If the addon is missing or stale, from the studio kit root:

```bash
./install.sh --addon-only example
```

The **MpKit** plugin is already enabled. Autoload `MpKit` comes **before** `NetSession`. For the agent CLI, install AgentKit from [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest) (`./install.sh --addon-only example agent_kit` from this kit).

## Play

| Mode | How |
|------|-----|
| **1P** | F5 → Play solo. Toggle 2D/3D. WASD/arrows, **E** emote. |
| **LAN** | Instance A: Host LAN (shows under **LAN rooms**). Instance B: click a room or Join `127.0.0.1`. Debug → Run Multiple Instances. |
| **Dedicated** | See below. The server process is **not** a player. |

F6: `player/pawn_2d.tscn`, `player/pawn_3d.tscn`, `levels/match_2d/match_2d.tscn`, `levels/match_3d/match_3d.tscn`. To see the 3D pawn with a camera and a floor: `debug/pawn_3d_preview.tscn`.

## Dedicated (same project)

```bash
godot --headless --path example -- --dedicated
# optional: --world=3d --mp-port=7777
```

Then a client in the editor: Join `127.0.0.1`.

`--headless` **alone** is not dedicated (GUT/CI are also headless). You need `-- --dedicated`, the `dedicated_server` feature tag, or a Dedicated Server export. In Customize Run Instances, if **Override Main Run Args** is off, Godot may ignore that row’s Launch Arguments.

## What to look at

| Piece | Where | Role |
|-------|--------|------|
| Transport | `addons/mp_kit/` | ENet, slots, tunnel. Zero gameplay. |
| Autoload | `autoloads/net_session.tscn` | `extends MpFlow`: `2d`/`3d` catalog + emote; its numbers are in the inspector |
| Texts | `locale/texts.csv` | One key per text, columns `es` and `en` |
| Match | `match/demo_match.tscn` | `elapsed` snapshot (no spawn) |
| Spawn | `MpSlotSpawner` in `levels/match_2d/` and `levels/match_3d/` | One pawn per slot |
| Network checks | `debug/spawn_lab/`, `agent/` | Spawn lab + AgentKit playtest |
| Pawns | `player/` | `submit_move` / `apply_move`, `MpReplicate`, pipe |
| Types | `player/pawn_*_type.tres` | Color, letter, speed — no `if kind` |
| Knobs | `docs/tuning.md` | What to change, and in which file, node and property |
| Product | `PRD.md`, `FEATURES.md`, `RULES.md`, `RFCs/` | Studio flow |

## Network checks

Two scripts, one group of Godot processes at a time (do not run them while other Godot tests run):

```bash
debug/spawn_lab/run_lab.sh            # headless: MpSpawner lab
agent/run_mp_playtest.sh              # windows: AgentKit flows on this demo + the lab
```

- **Spawn lab** (`debug/spawn_lab/`): dedicated + client A + late client B. The server spawns actors with a synchronizer, without one, with `MpReplicate` and no synchronizer, and with one added too late; a static synced node; two rooms with their own `MpSpawner` and `room_id`. It unseats slot 1 and, in a second run, reloads the world with both clients connected. `check_lab.py` prints PASS/FAIL per scenario.
- **Playtest** (`agent/`): 1P 2D/3D, listen host + client, dedicated + A + late B in 2D and 3D, all through the boot buttons and the InputMap. Needs AgentKit (`./install.sh --addon example agent_kit` from the kit root). Shots and logs in `agent/out/mp/`.

Network runs use `--max-fps 60`, never `--fixed-fps`: it drops real-time sync and a headless server quits before clients connect.

## Product flow

This folder **is** the output of `/create-prd` → `/verify-prd` → `/extract-features` → `/generate-rules` → `/generate-rfcs` → `/implement-rfc` 001–004 → `/review-rfc`. Status: [`WORKFLOW-STATUS.md`](WORKFLOW-STATUS.md) and `reviews/`.

## Not here

Score, lives, Steam, prediction, production art, GUT tests (the network checks above are scripts, not a test framework). Those do not belong in the kit or in this guide.
