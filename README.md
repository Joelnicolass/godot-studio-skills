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
- Decoupled structure comes first: each feature is scene(s) with priority to `@export`s, Resource `.tres` files, not a `match kind`. The editor exposes the knobs for convenience.
- One RFC at a time, with a **file tree** approved, review, playtest and visual pass if you ask
- MpKit kept off gameplay; notes across sessions in Engram or `.studio/MEMORY.md` if needed.
- The game lives in **another** repo; this one has skills, commands, agents, and addons (MpKit, FsmKit, PlatKit). AgentKit / playtester: [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest)

| Piece               | Where                                                                          | What it is                                                                                       |
| ------------------- | ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------ |
| Orchestrator        | `skills/godot-studio-workflow/`                                                | The chat agent: interview + `/implement-feature` (PRD/RFC optional)                              |
| How to write Godot  | `skills/`                                                                      | Layers, composition, MpKit, FSM, 2D platformer, juicy, visual, memory, tests                     |
| Subagents           | `agents/`                                                                      | Tech lead, developer, reviewer; optional tester and visual. Playtester: playtest module         |
| Commands            | `commands/`                                                                    | `/implement-feature`, `/add-juicy`, `/add-state-machine`, `/add-platformer-2d`, `/create-prd`, … |
| MpKit               | `addons/mp_kit/`                                                               | Multiplayer with nodes and no hand-written RPCs: the game in one `.tres` (`MpGame`), the world in one node (`MpWorld`), the match's verbs in `Mp`, plus `MpActor`, `MpInput`, `MpState`, `MpMatch`. Prediction, adaptive buffers, lag compensation and network quality; LAN, dedicated, online rooms, private matches, web, a relay for servers without a public IP (Railway), VPS deploy and a *Setup game* wizard. **Zero** gameplay. Start with `addons/mp_kit/QUICKSTART.md` (step by step: `GUIDE.md`); game-free checks in `mpkit_lab/run/all.sh`. |
| AgentKit            | [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest) | Agent CLI + harness. This kit installs it; it is not maintained here.                            |
| FsmKit              | `addons/fsm_kit/`                                                              | `FsmMachine` + `FsmState`. No autoload.                                                          |
| PlatKit             | `addons/plat_kit/`                                                             | 2D motor: coyote, buffer, apex, corner, lift. No levels or score.                                |

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
5. `/new-mp-feature` — MpKit actor scaffold only
6. `/workflow-status`

Written contract, if you ask:

7. `/create-prd` → `PRD.md` (short **living** GDD, not the whole title)
8. `/verify-prd` → `PRD-REVIEW.md`
9. `/extract-features` → `FEATURES.md`
10. `/generate-rules` → `RULES.md`
11. `/create-visual-guide` → `VISUAL.md`
12. `/generate-rfcs` → `RFCs/` + `RFCS.md`
13. `/implement-rfc <id>`
14. `/review-rfc <id>`
15. `/manage-changes`
16. `/test-strategy` — optional

## Install addons in a Godot project

```bash
./install.sh --addon /path/to/godot-project            # MpKit
./install.sh --addon /path/to/godot-project fsm_kit    # FsmKit
./install.sh --addon /path/to/godot-project plat_kit   # PlatKit
./install.sh --addon /path/to/godot-project agent_kit  # AgentKit (fetched from the playtest repo)
```

Enable each plugin in Project → Plugins. MpKit also needs the autoload (`MpKit="*res://addons/mp_kit/mp_kit.gd"`); first steps in `addons/mp_kit/QUICKSTART.md`, reference in `addons/mp_kit/README.md`, editor in `skills/godot-mp-kit/editor.md`, online/VPS in `skills/godot-mp-kit/dedicated.md`. AgentKit lives in [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest): JSON/harness live in the game’s `res://agent/`; details in that repo’s README. PlatKit is not a Celeste clone: dash/stamina stay in the game.

A ready demo lives in [`example/`](example/README.md) (1P, LAN, dedicated, 2D and 3D worlds with placeholders, PRD→RFC flow). VS Code/Cursor snippets: `.vscode/mpkit.code-snippets` (the installer copies them).

## Layout

```
docs/                          # architecture and flow in detail
example/                       # Godot 4.7 demo (1P + LAN + dedicated, 2D and 3D)
addons/mp_kit/
addons/fsm_kit/
addons/plat_kit/
skills/
  godot-studio-workflow/
  godot-studio-memory/
  godot-layered-architecture/
  godot-composition-first/
  godot-mp-kit/
  godot-visual-qa/
  godot-testing/
  godot-animation/
  godot-juicy/
  godot-fsm/
  godot-platformer-2d/
agents/                        # studio-tech-lead, studio-developer, …
commands/
install.sh
```

AgentKit, `/agent-kit`, `studio-playtester`, and the flow editor: [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest).

How the framework grows: extract into `addons/` or `skills/` when something is reused. Do not copy an FX or a score tracker “just in case”.
