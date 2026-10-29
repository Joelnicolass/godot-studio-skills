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

- **You** choose Clean or standard Godot **before** scaffolding. That gives you a clear structure for development.
- **You** choose whether there is multiplayer and which type (none · local/Wi-Fi · online)
- Simple and predictable comes first: each feature is scene(s) with its numbers as `@export`s on the node that uses them, Resource `.tres` files only for shared types, not a `match kind`. If changing a number means opening more than 2 files, the design is wrong.
- Standard Godot code: proven patterns (signals, `Events` bus, FSM, components…), real typing, `gdformat` / `gdlint`, and GUT + CI when there are tests (skill `godot-code-quality`).
- One RFC at a time, with a **file tree** approved, review, playtest and visual pass if you ask
- MpKit kept off gameplay; notes across sessions in Engram or `.studio/MEMORY.md` if needed.
- The game lives in **another** repo; this one has skills, commands, agents, and addons (MpKit, FsmKit, PlatKit, RtsKit, PropKit, GrassKit). AgentKit / playtester: [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest)

| Piece               | Where                                                                          | What it is                                                                                       |
| ------------------- | ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------ |
| Orchestrator        | `skills/godot-studio-workflow/`                                                | The chat agent: interview + `/implement-feature` (PRD/RFC optional)                              |
| How to write Godot  | `skills/`                                                                      | Layers, composition, code quality, MpKit, FSM, 2D platformer, RTS controls, props and their navmesh, grass, juicy, materials, feature research, visual, memory, tests and CI |
| Subagents           | `agents/`                                                                      | Tech lead, developer, reviewer; optional tester and visual. Playtester: playtest module         |
| Commands            | `commands/`                                                                    | `/implement-feature`, `/add-juicy`, `/add-state-machine`, `/add-platformer-2d`, `/add-rts-controls`, `/add-props`, `/add-grass`, `/create-prd`, … |
| MpKit               | `addons/mp_kit/`                                                               | Multiplayer with nodes and no hand-written RPCs: the game in one `.tres` (`MpGame`), the world in one node (`MpWorld`), the match's verbs in `Mp`, plus `MpActor`, `MpInput`, `MpState`, `MpMatch`. Prediction, adaptive buffers, lag compensation and network quality; LAN, dedicated, online rooms, private matches, web, a relay for servers without a public IP (Railway), VPS deploy and a *Setup game* wizard. **Zero** gameplay. Start with `addons/mp_kit/QUICKSTART.md` (step by step: `GUIDE.md`); game-free checks in `mpkit_lab/run/all.sh`. |
| AgentKit            | [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest) | Agent CLI + harness. This kit installs it; it is not maintained here.                            |
| FsmKit              | `addons/fsm_kit/`                                                              | `FsmMachine` + `FsmState`. No autoload.                                                          |
| PlatKit             | `addons/plat_kit/`                                                             | 2D motor: coyote, buffer, apex, corner, lift. No levels or score.                                |
| RtsKit              | `addons/rts_kit/`                                                              | RTS controls for 2D and 3D: units, selection and groups, typed orders in formations, command input (command panel and radial menu optional), RTS cameras. No network inside; no movement or combat. Start with `addons/rts_kit/GUIDE.md` (includes MpKit); tests in `rtskit_lab/`. |
| PropKit             | `addons/prop_kit/`                                                             | Props for 2D and 3D: scatter over any ground as saved nodes (clusters, keep-outs, masks, variants), batch drawing (3D), and the navmesh baked in zones with props as cheap obstructions, re-baking only what changed on worker threads. No network inside; no prop behavior. Start with `addons/prop_kit/README.md`; tests in `propkit_lab/`. |
| GrassKit            | `addons/grass_kit/`                                                            | Grass for 3D: blades drawn on the GPU around the camera in cells that move with it, tiers that thin with distance without popping, a ground read from the colliders (exact heights, normals, slope fade), clearings, trampling, a look that changes in play. No network inside. Start with `addons/grass_kit/README.md`; tests in `grasskit_lab/`. |

What **does not** belong here: score, product copy, a title’s scenes, `GameSession`, `SceneDirector`. That is game glue.

## How it works

The details (orchestrator diagrams, roles, Clean vs standard, multiplayer types, the iteration flow, art/shaders) live in [docs/architecture.md](docs/architecture.md). Interactive flow diagram: [joelnicolass.github.io/godot-studio-skills/en.html](https://joelnicolass.github.io/godot-studio-skills/en.html). In short: interview → `/implement-feature` → one OK on the tree (includes `res://debug/` when needed) → developer → reviewer → playtester on that scene → the orchestrator classifies the FAIL → close on `FEATURES.md`. A visual pass is asked. The slice contract is the `F<n>`, not a mandatory RFC.

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
7. `/add-grass` — grass around the camera on the GPU, over the ground's colliders (GrassKit addon)
8. `/new-mp-feature` — MpKit actor scaffold only
9. `/create-material` — procedural material / texture with [Material Maker](https://github.com/RodZill4/material-maker) → `.tres`
10. `/research-feature` — understand a mechanic of a similar game (web research, and decompiling it when it can be opened) before implementing it
11. `/workflow-status`

Written contract, if you ask:

12. `/create-prd` → `PRD.md` (short **living** GDD, not the whole title)
13. `/verify-prd` → `PRD-REVIEW.md`
14. `/extract-features` → `FEATURES.md`
15. `/generate-rules` → `RULES.md`
16. `/create-visual-guide` → `VISUAL.md`
17. `/generate-rfcs` → `RFCs/` + `RFCS.md`
18. `/implement-rfc <id>`
19. `/review-rfc <id>`
20. `/manage-changes`
21. `/test-strategy` — optional

## Install addons in a Godot project

```bash
./install.sh --addon /path/to/godot-project            # MpKit
./install.sh --addon /path/to/godot-project fsm_kit    # FsmKit
./install.sh --addon /path/to/godot-project plat_kit   # PlatKit
./install.sh --addon /path/to/godot-project rts_kit    # RtsKit
./install.sh --addon /path/to/godot-project prop_kit   # PropKit
./install.sh --addon /path/to/godot-project grass_kit  # GrassKit
./install.sh --addon /path/to/godot-project agent_kit  # AgentKit (fetched from the playtest repo)
```

Enable each plugin in Project → Plugins. MpKit also needs the autoload (`MpKit="*res://addons/mp_kit/mp_kit.gd"`); first steps in `addons/mp_kit/QUICKSTART.md`, reference in `addons/mp_kit/README.md`, editor in `skills/godot-mp-kit/editor.md`, online/VPS in `skills/godot-mp-kit/dedicated.md`. AgentKit lives in [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest): JSON/harness live in the game’s `res://agent/`; details in that repo’s README. PlatKit is not a Celeste clone: dash/stamina stay in the game. RtsKit commands, the game acts: it hands each unit its order and the game walks and fights (`addons/rts_kit/README.md`). PropKit places props and keeps their navmesh cheap; what a prop does stays in the game (`addons/prop_kit/README.md`). GrassKit draws grass around the camera over the game's ground; the ground's data and when it changes are the game's (`addons/grass_kit/README.md`).

External tools the flow **offers** when needed (never installed without asking): [Material Maker](https://github.com/RodZill4/material-maker) for procedural materials and textures (skill `godot-material-maker`), and a decompiler (gdsdecomp, ILSpy, …) to open a similar game when researching a mechanic (skill `godot-feature-research`). Same as the Aseprite and Blender MCPs.

A ready demo lives in [`example/`](example/README.md) (1P, LAN, dedicated, 2D and 3D worlds with placeholders, PRD→RFC flow). VS Code/Cursor snippets: `.vscode/mpkit.code-snippets` (the installer copies them).

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
rtskit_lab/                    # RtsKit's tests and examples, no game
propkit_lab/                   # PropKit's tests and examples, no game
grasskit_lab/                  # GrassKit's tests and example, no game
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
  godot-material-maker/
  godot-feature-research/
agents/                        # studio-tech-lead, studio-developer, …
commands/
install.sh
```

AgentKit, `/agent-kit`, `studio-playtester`, and the flow editor: [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest).

How the framework grows: extract into `addons/` or `skills/` when something is reused. Do not copy an FX or a score tracker “just in case”.

## License

[MIT](LICENSE).
