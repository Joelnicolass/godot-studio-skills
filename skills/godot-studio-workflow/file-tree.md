# File tree (always, before OK)

**Always**, before creating, modifying, or deleting any file, show the tree and wait for the user's OK. It applies to a feature, an RFC, a command (`/add-juicy`, `/create-material`, `/new-mp-feature`, …), a typo, or an `@export`. The tech lead builds it when there is one; otherwise this chat. Without an approved tree, nothing is written.

Only exceptions: what the playtester writes in `res://agent/` (already covered by the slice's OK) and memory notes (`.studio/MEMORY.md`).

Every line carries a mark:

| Mark | Meaning |
|------|---------|
| `[+]` | New file |
| `[~]` | Existing file that changes (say what changes) |
| `[-]` | File that gets deleted |

`[~]` and `[-]` lines are included too: the user must see what is touched among the existing files, not only what is new.

It shows at a glance whether the feature is a god-node or a set of pieces.

## Template

```text
<feature>/
├── [+] foo.tscn              # container: physics/layout + orchestrates children
├── [+] foo.gd                # thin: signals up, @export sockets
├── [+] bar.tscn              # reusable packed (2nd caller or F6 alone)
├── [+] bar.gd                # its numbers as @export, visible in the inspector
└── [+] foo_fast.tres         # only for a type with shared variants; do not mutate at runtime
scenes/world/
└── [~] world.tscn            # instances foo.tscn under %Actors
scenes/actors/
└── [-] old_foo.gd            # replaced by foo.gd
```

Small cut (typo, `@export`, a 1–3 file bug): the list is enough, no table.

```text
[~] scenes/player/player.gd   # coyote_time 0.10 → 0.12 (@export)
```

Plus a **responsibility map** (one row per file or node):

| Piece | Responsibility (one) | Kind | Why it is not merged |
|-------|----------------------|------|----------------------|
| `foo.gd` | Orchestrates input → `apply_*` | Node | If it also painted HUD, split |
| `bar.tscn` | FX / HUD / hitbox | Packed | Second caller or F6 |
| `foo_fast.tres` | Stats of one variant | Resource | Several scenes share it; another variant = another `.tres` |

For each new tunable number, the plan says which node it lives on. If changing it means opening more than 2 files, the cut is redesigned before the OK.

Clean: `src/features/<n>/`, `src/core/`, `src/domain/` per [clean.md](../godot-layered-architecture/clean.md).  
Standard: next to the scene; do not invent `src/domain/`.

## Test scene

It belongs in the same tree, under `res://debug/`, and on the RFC or the `F<n>`. The developer builds it from product pieces. The playtester does not create it and does not edit it: they only play it.

```text
debug/
└── goal_ready.tscn     # actor + goal, with other @export values on the instance (same script, other numbers)
```

The initial state makes the criterion **easy** (do not play the whole game to reach it). It does not leave the criterion **already true** (the goal is not already done, the notice does not start visible). The debug scene changes numbers (an `@export` on the instance, or a debug `.tres` if the feature already uses one); not a parallel script. `res://debug/` stays out of the release export.

## Signals to compose more

- One `.gd` paints, spawns, scores, and changes scene.
- Hardcoded copy or numbers (copy goes through `tr()`; numbers, to an `@export` on the node that uses them).
- The same block copied in two features → `shared/` or packed.
- HUD mixed with match rules.

## Signals to compose less

- A packed scene of a ColorRect nobody reuses.
- An autoload for *this* round’s score.
- `src/domain/` in a project that chose **standard**.
- A `.tres` that a single scene uses, or one that points at another through a tag or a string.
- A new autoload, registry, locator, or manager for something a signal, an `@export`, or the `Events` bus solves.

## What to ask the user

Show the tree (with `[+]` / `[~]` / `[-]`) + the table. Ask: is the cut right, or do you want more/fewer pieces? Only with OK does anything get written: `studio-developer` runs or this chat does it. If implementing needs a file that was not in the tree, stop and show the corrected tree before continuing.
