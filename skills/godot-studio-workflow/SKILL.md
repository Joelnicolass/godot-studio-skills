---
name: godot-studio-workflow
description: >-
  Orchestrates a Godot 4 game from idea to a simple scalable base: interviews
  the user, runs product commands (PRD, features, rules, RFCs), researches when
  needed, then delegates tech-lead / developer / reviewer (optional tester and
  visual). Use when starting a game, a Godot project, PRD, RFC, feature
  implementation, or when the user wants the studio workflow / orchestration.
---

# Godot studio — orchestrator

The **main agent in this chat** is the orchestrator. It talks to the user. It does not dump the whole product into one subagent.

Goal: a Godot 4 game with a **small, clear base**, easy to continue by hand or with AI. Priorities: clean layers, composition, editor/`@export`, reusable components. Also load [godot-layered-architecture](../godot-layered-architecture/SKILL.md) and [godot-composition-first](../godot-composition-first/SKILL.md). Networking: [godot-mp-kit](../godot-mp-kit/SKILL.md). Tests: [godot-testing](../godot-testing/SKILL.md) (GUT / GdUnit4) **only** if the user asks or RULES requires them.

Roles (kit subagents; `Task` `subagent_type` = their `name`):

| Role | Subagent | When |
|------|----------|------|
| Tech lead | `studio-tech-lead` | Plan one RFC/feature **before** code |
| Developer | `studio-developer` | Implement **one** RFC or a bounded change |
| Reviewer | `studio-reviewer` | After implementation |
| Tester | `studio-tester` | **Only** if the user asked for tests or RULES.md requires them |
| Visual | `studio-visual` | **Only** if HUD/menu/layout changed and a look check is needed |

## 1. Startup (you ask and you run commands)

If the user wants a game / new feature and artifacts are missing, **do not wait** for them to type the slash: execute the matching command (read `commands/*.md` in the kit or `.cursor/commands/` in the project).

Order:

1. Architecture Clean vs standard — **ask** (layered skill). No answer: do not scaffold.
2. `/create-prd` → `PRD.md` (for games: a short GDD; see that command).
3. `/verify-prd`
4. `/extract-features` → `FEATURES.md`
5. `/generate-rules` → `RULES.md` (must cite these skills)
6. `/generate-rfcs` — first RFC = playable vertical slice, not endless infra
7. `/test-strategy` only if the user wants tests or the PRD asks for them
8. Implement RFC by RFC with the pipeline below
9. `/workflow-status` when they ask where things stand

Research (Godot API, a pattern, an addon): `explore` subagent or a targeted read. The orchestrator summarizes; do not paste dumps.

Mid-work scope changes: `/manage-changes`.

## 2. One-RFC pipeline (simple path)

One RFC at a time. Predecessors done.

```
orchestrator (chat)
  → studio-tech-lead     plan, files, Resources vs nodes  [no code]
  → user approval
  → studio-developer     implements the plan
  → studio-reviewer      vs RFC + composition + editor
  → studio-tester        optional
  → studio-visual        optional (UI/scene)
  → orchestrator         synthesizes, next RFC or stop
```

The subagent prompt must include: repo path, RFC id, architecture already chosen, and to read PRD / FEATURES / RULES / that RFC. Subagents **do not** see this chat.

Do not launch developer and reviewer in parallel on the same RFC. Tech-lead on independent RFCs may run in parallel.

## 3. Do not

- Ship product features without PRD + RFC (except a pinpoint fix the user scoped).
- One `studio-developer` “build the game”.
- Invent Clean layers if they chose standard, or the reverse.
- Put score, copy, or title netcode in `addons/mp_kit`.
- Tests or visual passes if the user did not ask and RULES does not require them.

## 4. Done when

The vertical slice plays; each feature is a small scene/component/`Resource`; a human can open the inspector and continue. That is the scalable base.
