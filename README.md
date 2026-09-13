# Godot studio kit

A small studio for **Cursor + Godot 4**: the chat does not “make the game”, it **orchestrates**. It interviews you, writes PRD/RFCs, and hands plan / code / review to subagents. The result is not a thousand-line `World.gd`: it is a **small, playable, clear base** that a human (or another AI) can continue from the inspector.

Repo: https://github.com/Joelnicolass/godot-studio-skills

`main` is English. `release/spanish` is Spanish.

## Why this exists

Without the kit, an agent often:

- assumes Clean Architecture or a leftover genre (wrap, CRT, plasma…)
- mixes score, spawn, FX, and netcode in one script
- implements the whole product in one turn, with no PRD or RFC

With the kit:

- **you** choose Clean or standard Godot **before** any scaffold
- **you** choose whether there is multiplayer and which type (none · local/Wi-Fi · online)
- each feature is a scene + `@export` + Resource `.tres`, not a `match kind`
- one RFC at a time, with an approved plan, review, and MpKit kept off gameplay
- the game lives in **another** repo; this one only has skills, commands, agents, and the transport addon

| Piece | Where | What it is |
|-------|--------|--------|
| Orchestrator | `skills/godot-studio-workflow/` | The chat agent: interview + PRD→RFC→implement |
| How to write Godot | `skills/` | Layers, composition, MpKit, tests (GUT/GdUnit4) |
| Subagents | `agents/` | Tech lead, developer, reviewer; optional tester and visual |
| Commands | `commands/` | `/create-prd`, `/generate-rfcs`, `/implement-rfc`, … |
| MpKit | `addons/mp_kit/` | LAN / Wi-Fi host-authoritative. **Zero** gameplay. Not needed if there is no MP. Online = it must be expanded. |

What **does not** belong here: score, product copy, a title’s scenes, `GameSession`, `SceneDirector`. That is game glue.

## Orchestrator architecture

The main chat talks to you. It does not implement the title alone. It loads Godot skills, runs product commands, and invokes **one role at a time**.

```mermaid
flowchart TB
  you[You]
  orch[Main chat — orchestrator]

  you <--> orch

  subgraph kit [This framework]
    skills[Godot skills]
    cmds[PRD / RFC commands]
    agents[Subagents]
    mpkit[MpKit addon]
  end

  subgraph game [Your Godot project]
    arts[PRD FEATURES RULES RFCs]
    code[Scenes Resources glue]
  end

  orch --> skills
  orch --> cmds
  cmds --> arts
  orch --> agents
  agents --> code
  mpkit -.-> code
```

Roles (`Task` → `subagent_type`):

| Role | Subagent | When |
|------|----------|------|
| Tech lead | `studio-tech-lead` | Plan for **one** RFC, no code |
| Developer | `studio-developer` | Implements that plan |
| Reviewer | `studio-reviewer` | After the code |
| Tester | `studio-tester` | Only if you ask for tests or RULES requires them |
| Visual | `studio-visual` | Only if HUD/menu/layout changed |

Subagents **do not** see this chat. The prompt passes repo, RFC, architecture style, and tells them to read the artifacts.

## Godot architectures (always ask)

Two styles are valid. The agent does not assume Clean. Both require composition, the editor, and Resources.

```mermaid
flowchart TB
  ask{Clean or standard?}

  ask -->|Clean| clean[features → core → domain]
  ask -->|Standard| std[scenes + scripts together]

  clean --> feat[features: nodes, physics, RPC]
  feat --> core[core: session, events, director]
  core --> domain[domain: RefCounted, testable]

  std --> scenes[scenes/ next to the .gd]
  scenes --> match[Match node in the world]

  clean --> shared[Composition]
  std --> shared

  shared --> packed[Packed scenes + @export]
  packed --> tres[Types = Resource .tres]
  tres --> f6[Each scene runs with F6]
```

| Style | Shape | Match state |
|--------|--------|-------------|
| **Clean** | `src/domain` + `core` + `features` | `GameSession` autoload **only** if it survives scene change |
| **Standard** | Scene + script together; no `src/domain/` | `Match` node, child of the world |

Type data → Resource. Pure helpers → `class_name` + `static func`. Actor behavior → child node. Autoload only for global services (MpKit **if there is MP**, event bus).

## Multiplayer (always ask)

Do not copy `addons/mp_kit` “just in case”. Ask the type **before** RPCs or the addon.

```mermaid
flowchart TB
  mp{What multiplayer?}

  mp -->|None| none[No MpKit, no RPCs]
  mp -->|Local / Wi-Fi| lan[Current MpKit — ENet LAN]
  mp -->|Online| net[Expand MpKit — relay / WebRTC / Steam / dedicated]
```

| Type | MpKit |
|------|--------|
| **No multiplayer** | Do not install |
| **Local / Wi-Fi** | This repo’s addon is enough |
| **Online** (internet) | **Expand** the addon transport. Glue and `submit_*` stay in the game |

Tests: skill `godot-testing` (GUT / GdUnit4) **only** if you ask.

## Development flow

From idea to a **playable** base. The first RFC is the vertical slice, not endless infra.

```mermaid
flowchart TD
  idea[Game idea] --> arch[Choose Clean or standard]
  idea --> mp[Choose MP type]
  arch --> prd["/create-prd → PRD / GDD"]
  mp --> prd
  prd --> ver["/verify-prd"]
  ver --> feat["/extract-features"]
  feat --> rules["/generate-rules"]
  rules --> rfcs["/generate-rfcs"]
  rfcs --> slice[RFC-001 vertical slice]

  slice --> plan[studio-tech-lead: plan]
  plan --> ok{Your OK?}
  ok -->|no| plan
  ok -->|yes| dev[studio-developer]
  dev --> rev[studio-reviewer]
  rev --> more{Another RFC?}
  more -->|yes| plan
  more -->|no| done[Small, playable, scalable base]
```

In a new chat, with the kit installed, ask for the game. The orchestrator runs those commands **without** you typing every slash. Tester and visual only if you ask. Scope mid-build: `/manage-changes`. Where we are: `/workflow-status`.

Done when: the slice plays; each feature is a scene / component / `.tres`; a human opens the inspector and follows.

## Priorities (always)

- architecture that is easy to scale and clean in layers
- composition structures always take priority
- nodes and editor configuration always take priority
- component reusability always takes priority

On **standard**, “layers” does not mean `domain/core/features` folders. It means small scripts and composition.

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
