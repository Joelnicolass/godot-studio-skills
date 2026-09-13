# Clean path — layers

Use **only** if the user chose Clean (or the repo already declares it). Dependencies inward:

```
features (Nodes, .tscn, physics, RPCs, spawners)
    → core (autoloads: session, events, director, net glue)
        → domain (RefCounted: match rules)
```

```
src/
  core/autoload/     # MatchRules.tres, GameEvents, GameSession, SceneDirector
  domain/            # pure trackers and resolvers (round state, not catalogs)
  features/<name>/   # scripts + scenes together
  shared/            # StateMachine, PostFx, Health
  resources/         # class_name + .tres (content types)
addons/              # MpKit and framework plugins (zero gameplay)
```

Facade names: `GameSession`, `GameEvents`, `SceneDirector`. Do not reuse names from a previous title.

`GameSession` as an autoload **only** if it must survive scene change; otherwise a node under `Main`. Tests: [godot-testing](../godot-testing/SKILL.md).

### Domain

- `extends RefCounted`. `new()` in tests and in the session.
- Forbidden: `Node`, `Input`, `MultiplayerAPI`, `get_tree()`, `@rpc`, scene `await`.
- Receives numbers **or definition Resources** via constructor. Does not read autoloads in tests.
- **Not** the place for “how the projectile looks”. That is the `.tres`. Domain uses `data.damage`, not type strings.

### Core

- **GameSession**: trackers per slot, `start` / `abort`, `submit_*`, `to_snapshot` / `apply_snapshot`. The client turns off the tick when applying a snapshot.
- **GameEvents**: HUD/FX listen; the actor does not store the score.
- **SceneDirector**: changes scenes. Prefer swapping `World` children and leaving `GUI` alive. Does not score.
- **`MatchRules.tres`**: **round** tunables (duration, lives, layers). Not 80 floats per enemy.

1P = local host. Same rules as 2P.

### Features

Nodes. `@rpc`, physics, spawners. `@export var data: EnemyData`. No `match kind`.

### Shared + resources

Scene components in `shared/`. `.tres` templates in `resources/<family>/`.
