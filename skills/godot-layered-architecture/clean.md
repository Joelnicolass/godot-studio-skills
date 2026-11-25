# Clean layered (only repos that already declare it)

Not offered to a new project. Use **only** if the repo already declares it or the user asked for it by name. For a new game: [by-entity.md](by-entity.md) or [systems-content.md](systems-content.md). What Clean was after, rules you can test without a scene, comes from the pure core of [SKILL.md](SKILL.md) §2.

Dependencies inward:

```
features (nodes, .tscn, physics, spawners)
    → core (autoloads: session, events, scene changes)
        → domain (RefCounted: match rules)
```

```
src/
  core/              # Events, GameSession, SceneDirector
  domain/            # pure rules: round state, not catalogs
  features/<name>/   # scripts + scenes together, with their .tres files
  shared/            # components, and shaders and materials several features use
  balance/           # match_config.tres and other balance .tres files
addons/              # kits (zero gameplay)
docs/                # architecture.md, tuning.md
```

File names and suffixes: [godot-code-quality](../godot-code-quality/SKILL.md) §1. `docs/tuning.md` is required here too.

### Domain

The pure-core rules of [SKILL.md](SKILL.md) §2, in the `src/domain/` folder. It uses `type.damage`, not type strings. It does not decide how anything looks.

### Core

- **GameSession**: the match state and `start` / `abort`. An autoload **only** if it must survive a scene change; otherwise a node under `Main`. If it has values to tune, it is registered as a `.tscn` or reads `balance/match_config.tres`.
- **Events**: event bus, typed `signal` declarations only (no state, no methods). HUD and effects listen; the actor does not store the score.
- **SceneDirector**: changes scenes. Prefer swapping `World` children and leaving `GUI` alive. Does not score.

Only if networked: `GameSession` adds `submit_*` and `to_snapshot` / `apply_snapshot`; the client turns off its tick when applying a snapshot; a single player is a local host with the same rules. Without a network, none of that exists.

### Features

Nodes, physics, spawners. `@export var type: EnemyType`. No `match kind`.
