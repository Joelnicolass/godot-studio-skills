# Godot studio kit

A small (on purpose) framework for Godot 4 games. The **main chat orchestrates**: it asks questions, runs product commands, researches when needed, and hands plan / code / review to subagents. The game (domain, glue, scenes) does not live here.

Goal: a **simple base that scales** by hand or with AI (composition, editor, Resources, small scripts).

Repo: https://github.com/Joelnicolass/godot-studio-skills

| Piece | Where | What it is |
|-------|--------|--------|
| Orchestrator | `skills/godot-studio-workflow/` | The chat agent: PRD→RFC→implement flow |
| Architecture / composition / MP / tests | `skills/` | How to write and test Godot |
| Tech lead, developer, reviewer, tester, visual | `agents/` | Cursor subagents (`.cursor/agents/`) |
| PRD → features → rules → RFCs | `commands/` | Slash commands (`/create-prd`, …) |
| MpKit | `addons/mp_kit/` | LAN transport. Zero gameplay |

What **does not** belong in this repo: score, product copy, a title’s scenes, `GameSession`, `SceneDirector`. That is game glue.

## Priorities (always)

Always prioritize:

- architecture that is easy to scale and clean in layers
- composition structures always take priority
- nodes and editor configuration always take priority
- component reusability always takes priority

## How work runs

In a new chat, with the kit installed, ask for the game. The orchestrator:

1. Asks Clean vs standard (and whatever else is missing).
2. Runs `/create-prd` … `/generate-rfcs` without you typing every slash.
3. Researches Godot APIs if needed.
4. Per RFC: **tech lead** (plan) → your OK → **developer** → **reviewer**. Tester and visual only if you ask.

The developer (human or subagent) gets one RFC + plan + RULES: a short path, no guessing the rest of the product.

## Install (Cursor)

```bash
./install.sh                 # ~/.cursor/skills, commands, agents
./install.sh --project       # ./.cursor/ of cwd
```

From GitHub:

```bash
npx skills add Joelnicolass/godot-studio-skills -g -a cursor -y
```

`npx skills` only copies `skills/`. Commands, subagents, and the addon go through `./install.sh`.

Open a **new chat** in Cursor after installing.

## Product commands

1. `/create-prd` → `PRD.md` (for games: a short GDD)
2. `/verify-prd` → `PRD-REVIEW.md`
3. `/extract-features` → `FEATURES.md`
4. `/generate-rules` → `RULES.md`
5. `/generate-rfcs` → `RFCs/` + `RFCS.md` (the first is the vertical slice)
6. `/test-strategy` → optional
7. `/implement-rfc <id>` (subagent pipeline)
8. `/review-rfc <id>`
9. `/manage-changes` when scope moves
10. `/workflow-status`

## Install MpKit in a Godot project

```bash
./install.sh --addon /path/to/godot-project
```

Autoload **before** glue:

```
MpKit="*res://addons/mp_kit/mp_kit.gd"
```

## Layout

```
addons/mp_kit/
skills/
  godot-studio-workflow/
  godot-layered-architecture/
  godot-composition-first/
  godot-mp-kit/
  godot-testing/
agents/                        # studio-tech-lead, studio-developer, …
commands/
install.sh
```

How the framework grows: extract into `addons/` or `skills/` when something is reused. Do not copy an FX or a score tracker “just in case”.
