# Clean path — layers

Use **only** if the user chose Clean (or the repo already declares it). Dependencies point inward:

```
features (Nodes, .tscn, physics, RPCs, spawners)
    → core (autoloads: session, events, director, net glue)
        → domain (RefCounted: match rules)
```

```
src/
  core/autoload/     # GameConstants or MatchRules.tres, GameEvents, GameSession, SceneDirector
  domain/            # pure trackers and resolvers (round state, not catalogs)
  features/<name>/   # scripts + scenes together
  shared/            # Wrap, StateMachine, PostFx
  resources/         # class_name + .tres (bullets, enemies, power-ups)
addons/              # MpKit and framework plugins (zero gameplay)
```

Facade names: `GameSession`, `GameEvents`, `SceneDirector`. Do not reuse names from a previous title.

### Domain

- `extends RefCounted`. `new()` in tests and in the session.
- Forbidden: `Node`, `Input`, `MultiplayerAPI`, `get_tree()`, `@rpc`, scene `await`.
- Receives numbers **or definition Resources** via constructor. Tests do not read autoloads.
- **Not** the place for “how plasma looks”. That is `BulletData.tres`. Domain uses `data.damage`, not type strings.

### Core

- **GameSession**: trackers per slot, `start` / `abort`, `submit_*`, `to_snapshot` / `apply_snapshot`. The client turns off the tick when applying a snapshot.
- **GameEvents**: HUD/FX listen; the pawn does not store score.
- **SceneDirector**: changes scene. Does not score.
- **GameConstants** / `MatchRules.tres`: **round** tunables (duration, lives, layers). Not a dump of 80 floats per enemy.

1P = local host. Same rules as 2P.

### Features

Nodes. `@rpc`, physics, spawners. `@export var data: EnemyData` (or whatever the type is). No `match kind`.

### Shared + resources

Scene components in `shared/`. `.tres` templates in `resources/<family>/`.
