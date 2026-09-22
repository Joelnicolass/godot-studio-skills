# File tree (before OK)

The tech lead delivers this **before** asking for approval. The orchestrator shows it to the user. Without it there is no “OK, implement”.

It shows at a glance whether the feature is a god-node or a set of pieces.

## Template

```text
<feature>/
├── foo.tscn              # container: physics/layout + orchestrates children
├── foo.gd                # thin: signals up, @export sockets
├── bar.tscn              # reusable packed (2nd caller or F6 alone)
├── bar.gd
└── data/
    └── foo_stats.tres    # type; do not mutate at runtime
```

Plus a **responsibility map** (one row per file or node):

| Piece | Responsibility (one) | Kind | Why it is not merged |
|-------|----------------------|------|----------------------|
| `foo.gd` | Orchestrates input → `apply_*` | Node | If it also painted HUD, split |
| `bar.tscn` | FX / HUD / hitbox | Packed | Second caller or F6 |
| `foo_stats.tres` | Type stats | Resource | Another skin = another `.tres` |

Clean: `src/features/<n>/`, `src/core/`, `src/domain/` per [clean.md](../godot-layered-architecture/clean.md).  
Standard: next to the scene; do not invent `src/domain/`.

## Test scene

It belongs in the same tree, under `res://debug/`, and on the RFC or the `F<n>`. The developer builds it from product pieces. The playtester does not create it and does not edit it: they only play it.

```text
debug/
└── goal_ready.tscn     # actor + goal + stats_debug.tres (same script, other numbers)
```

The initial state makes the criterion **easy** (do not play the whole game to reach it). It does not leave the criterion **already true** (the goal is not already done, the notice does not start visible). A debug `.tres` changes numbers; not a parallel script. `res://debug/` stays out of the release export.

## Signals to compose more

- One `.gd` paints, spawns, scores, and changes scene.
- Hardcoded copy or round numbers (belong in a module / `MatchRules.tres`).
- The same block copied in two features → `shared/` or packed.
- HUD mixed with match rules.

## Signals to compose less

- A packed scene of a ColorRect nobody reuses.
- An autoload for *this* round’s score.
- `src/domain/` in a project that chose **standard**.

## What to ask the user

Show the tree + the table. Ask: is the cut right, or do you want more/fewer pieces? Only with OK does `studio-developer` run.
