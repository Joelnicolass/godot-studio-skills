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
foo/
├── [+] foo.tscn              # container: physics and layout; orchestrates its children
├── [+] foo.gd                # thin: signals up, @export references
├── [+] foo_type.gd           # class_name FooType: the design numbers of a foo
├── [+] fast/fast_foo_type.tres   # one variant; not mutated at runtime
└── [-] old_foo.gd            # replaced by foo.gd
shared/components/
├── [+] bar.tscn              # reusable packed (two entities use it)
└── [+] bar.gd
levels/forest/
└── [~] forest.tscn           # instances foo.tscn under %Actors
docs/
└── [~] tuning.md             # new rows: foo speed and damage
```

Small cut (typo, `@export`, a 1–3 file bug): the list is enough, no table.

```text
[~] player/player.tscn   # coyote_time 0.10 → 0.12 (@export on the root)
```

Plus a **responsibility map** (one row per file or node):

| Piece | Responsibility (one) | Kind | Why it is not merged |
|-------|----------------------|------|----------------------|
| `foo.gd` | Orchestrates input → `apply_*` | Node | If it also painted HUD, split |
| `bar.tscn` | FX / HUD / hitbox | Packed | Second caller or F6 |
| `fast_foo_type.tres` | Numbers of one variant | Type Resource | Another variant = another `_type.tres` |

For each new design number, the plan brings its `docs/tuning.md` row (I want to change → file → node → property), and `[~] docs/tuning.md` goes in the tree. If changing it means opening more than 2 files, the cut is redesigned before the OK.

Each file in the tree goes in the folder it belongs to, and each `.tres` carries its suffix ([godot-code-quality](../godot-code-quality/SKILL.md) §1).

By entity: the entity's folder, or `shared/` ([by-entity.md](../godot-layered-architecture/by-entity.md)).  
Systems + content: `systems/`, `content/`, `ui/` ([systems-content.md](../godot-layered-architecture/systems-content.md)).  
Clean (only a repo that already declares it): [clean.md](../godot-layered-architecture/clean.md).

## Test scene

It belongs in the same tree, under `res://debug/`, and on the RFC or the `F<n>`. The developer builds it from product pieces. The playtester does not create it and does not edit it: they only play it.

```text
debug/
└── goal_ready.tscn     # actor + goal, with other @export values on the instance (same script, other numbers)
```

The initial state makes the criterion **easy** (do not play the whole game to reach it). It does not leave the criterion **already true** (the goal is not already done, the notice does not start visible). The debug scene changes numbers (an `@export` on the instance, or a debug `.tres` if the feature already uses one); not a parallel script. `res://debug/` stays out of the export (`debug/*` in the preset's exclude filter) and nothing in the game names it: `rg -n "res://debug" --glob '!debug/**' --glob '!agent/**'` comes back empty.

## Signals to compose more

- One `.gd` paints, spawns, scores, and changes scene.
- Text or numbers written in code (text goes to the translation file; numbers, to their owner per rule 0).
- The same block copied in two features → `shared/` or packed.
- HUD mixed with match rules.

## Signals to compose less

- A packed scene of a ColorRect nobody reuses.
- An autoload for *this* round’s score.
- A `domain/`, `core/`, or `scenes/` folder in a project that did not declare Clean.
- A `.tres` that meets none of the three conditions of rule 0, or one that points at another through a tag or a string.
- A new autoload, registry, locator, or manager for something a signal, an `@export`, or the `Events` bus solves.

## What to ask the user

Show the tree (with `[+]` / `[~]` / `[-]`) + the table. Ask: is the cut right, or do you want more/fewer pieces? Only with OK does anything get written: `studio-developer` runs or this chat does it. If implementing needs a file that was not in the tree, stop and show the corrected tree before continuing.
