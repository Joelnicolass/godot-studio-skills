# Spec + skills (kit loop)

**Product truth** lives in versioned artifacts. **How** to write Godot lives in `SKILL.md`. No PRD without a skill, and no skill that invents the game.

## Spec (what and why)

| Artifact | What it is |
|----------|------------|
| `RULES.md` | Technical constitution (stack, layers, MP, code non-goals) |
| `VISUAL.md` | Look constitution (style, refs, hierarchy, do not invent) |
| `FEATURES.md` | The slice contract: `F<n>`, criteria, `res://debug/…` path if needed, InputMap action, observable. Grows with `/implement-feature`. |
| `PRD.md` | Optional and short. Not the suite. |
| `RFCs/` | Contract for a large slice (optional). `/implement-feature` does not require an RFC. |
| Tech-lead plan | File tree + responsibilities (derived; rewrite if the RFC changes) |

Code, review, playtest, and the visual pass are measured **against** those files, not by ear.

Authority: `PRD.md` > `FEATURES.md` > `RULES.md` > `VISUAL.md` > RFC > generated plan.

## Skills (how)

| Skill | When |
|-------|------|
| `godot-studio-workflow` | Orchestrate (this chat) |
| `godot-studio-memory` | Notes across chats (gotchas, decisions, next step) |
| `godot-layered-architecture` / `godot-composition-first` | Write Godot |
| `godot-playtest` | Launch the binary and exercise the feature ([godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest) module) |
| `godot-visual-qa` | Screenshot vs `VISUAL.md` |
| `godot-testing` | GUT/GdUnit4 **only** if the user or RULES asks |
| `godot-mp-kit` | Only if there is MP |

Whoever **writes** does not self-validate. Developer ≠ reviewer ≠ playtester ≠ visual.

When launching a `Task`, paste [compact-rules.md](compact-rules.md) (subagents do not see this chat).

## Three ways to validate

- `studio-tester` + `godot-testing` = the repo’s automated runner.
- `studio-playtester` + `godot-playtest` = **play** the scene named on the `F<n>` (playtest module; if not installed, manual playtest or skip). Does not ask for a second OK. The live playtest rule is in that module (`evaluate.md`); do not restate a second copy here.
- `studio-visual` + `godot-visual-qa` = UI/UX. Without style/refs/`VISUAL.md`, **stop** and ask for them.

A review = one pass. If there are blockers, one correction; not a loop until green.

## Before implementation OK

The tech lead **shows** the [file tree](file-tree.md). Without a tree, do not ask to implement: the user cannot judge more vs fewer pieces.
