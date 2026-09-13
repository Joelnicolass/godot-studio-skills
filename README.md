# Godot studio kit

A small (on purpose) framework for Godot 4 games: **Cursor skills**, **product commands** (PRD / RFC), and **Godot addons**. It grows one reusable piece at a time. The game (domain, glue, scenes) does not live here.

Repo: https://github.com/Joelnicolass/godot-studio-skills

| Piece | Where | What it is |
|-------|--------|--------|
| Architecture (Clean **or** standard; **ask**) / composition / Resources / MP | `skills/` | Agent instructions |
| PRD → features → rules → RFCs → implement / review | `commands/` | Cursor slash commands (`/create-prd`, …) |
| MpKit | `addons/mp_kit/` | Godot plugin: transport, slots, session RPCs. Zero gameplay |

What **does not** belong in this repo: score, product copy, a title’s scenes, `GameSession`, `SceneDirector`. That is game glue.

## Priorities (always)

Always prioritize:

- architecture that is easy to scale and clean in layers
- composition structures always take priority
- nodes and editor configuration always take priority
- component reusability always takes priority

## Install skills (Cursor)

```bash
./install.sh                 # ~/.cursor/skills/ and ~/.cursor/commands/
./install.sh --project       # ./.cursor/skills/ and ./.cursor/commands/ of cwd
```

From GitHub:

```bash
npx skills add Joelnicolass/godot-studio-skills -g -a cursor -y
```

`npx skills` only copies `skills/`. Commands and the Godot addon go through `./install.sh`.

Open a **new chat** in Cursor after installing.

## Product commands

They land as slash commands (`/create-prd`, …). Flow:

1. `/create-prd` → `PRD.md`
2. `/verify-prd` → `PRD-REVIEW.md`
3. `/extract-features` → `FEATURES.md`
4. `/generate-rules` → `RULES.md`
5. `/generate-rfcs` → `RFCs/` + `RFCS.md`
6. `/test-strategy` → `TEST-STRATEGY.md`
7. `/implement-rfc <id>`
8. `/review-rfc <id>`
9. `/manage-changes` when scope moves
10. `/workflow-status` at any time

`npx skills` does not install these files; use `./install.sh`.

## Install MpKit in a Godot project

```bash
./install.sh --addon /path/to/godot-project
```

That leaves `addons/mp_kit/` in that project. Then, in `project.godot`, autoload **before** glue:

```
MpKit="*res://addons/mp_kit/mp_kit.gd"
```

Details: `addons/mp_kit/README.md` and the `godot-mp-kit` skill.

## Zip

```bash
./pack.sh    # dist/godot-studio-skills.zip  (skills + commands + addons + installer)
unzip dist/godot-studio-skills.zip
cd godot-studio-skills
./install.sh
./install.sh --addon /path/to/godot-project
```

## Layout

```
addons/mp_kit/                 # canonical Godot plugin
skills/
  godot-layered-architecture/
  godot-composition-first/
  godot-mp-kit/
commands/                      # /create-prd, /generate-rfcs, /implement-rfc, …
install.sh                     # skills, commands, and/or --addon
```

How the framework grows: extract into `addons/` or `skills/` when something is reused. Do not copy an FX or a score tracker “just in case”.
