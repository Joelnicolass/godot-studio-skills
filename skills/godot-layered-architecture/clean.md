# Clean path — layers

Use **only** if the user chose Clean (or the repo already declares it). Dependencies inward:

```
features (Nodes, .tscn, physics, RPCs, spawners)
    → core (autoloads: session, events, director, net glue)
        → domain (RefCounted: match rules)
```

```
src/
  core/autoload/     # MatchRules.tres, Events, GameSession, SceneDirector
  domain/            # pure trackers and resolvers (round state, not catalogs)
  features/<name>/   # scripts + scenes together
  shared/            # components (a script or a scene): StateMachine, PostFx, Health; no loose shaders
  resources/         # class_name + .tres of types several features share
assets/              # only if RULES.md chose art by type: art/, shaders/, materials/, environment/
addons/              # MpKit and framework plugins (zero gameplay)
```

Facade names: `GameSession`, `Events`, `SceneDirector`. Do not reuse names from a previous title.

`GameSession` as an autoload **only** if it must survive scene change; otherwise a node under `Main`. Tests: [godot-testing](../godot-testing/SKILL.md).

### Domain

- `extends RefCounted`. `new()` in tests and in the session.
- Forbidden: `Node`, `Input`, `MultiplayerAPI`, `get_tree()`, `@rpc`, scene `await`.
- Receives numbers **or definition Resources** via constructor. Does not read autoloads in tests.
- **Not** the place for “how the projectile looks”. That is the `.tres`. Domain uses `data.damage`, not type strings.

### Core

- **GameSession**: trackers per slot, `start` / `abort`, `submit_*`, `to_snapshot` / `apply_snapshot`. The client turns off the tick when applying a snapshot.
- **Events**: event bus, typed `signal` declarations only (no state, no methods). HUD/FX listen; the actor does not store the score.
- **SceneDirector**: changes scenes. Prefer swapping `World` children and leaving `GUI` alive. Does not score.
- **`MatchRules.tres`**: **round** tunables (duration, lives, layers) that the session and the features read. Not 80 floats per enemy: those go on the node's `@export` or on its type's `.tres`.

1P = local host. Same rules as 2P.

### Features

Nodes. `@rpc`, physics, spawners. `@export var data: EnemyData`. No `match kind`.

### Shared + resources

Components (a script or a scene) in `shared/`; loose shaders, materials and art do not go there, they go with their feature or in `assets/` (RULES.md decides). A `.tres` that a single feature uses lives in `features/<name>/`; `resources/<family>/` is for shared types.
