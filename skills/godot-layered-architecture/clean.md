# Camino Clean — capas

Usar **solo** si el usuario eligió Clean (o el repo ya lo declara). Dependencias hacia adentro:

```
features (Nodes, .tscn, física, RPCs, spawners)
    → core (autoloads: sesión, eventos, director, glue de red)
        → domain (RefCounted: reglas de partida)
```

```
src/
  core/autoload/     # GameConstants o MatchRules.tres, GameEvents, GameSession, SceneDirector
  domain/            # trackers y resolvers puros (estado de ronda, no catálogos)
  features/<name>/   # scripts + escenas juntas
  shared/            # Wrap, StateMachine, PostFx
  resources/         # class_name + .tres (balas, enemigos, power-ups)
addons/              # MpKit (Joelnicolass/godot-studio-skills/addons/)
```

Nombres genéricos: `GameSession`, `GameEvents`, `SceneDirector`. Ejemplar: `MatchSession`.

### Domain

- `extends RefCounted`. `new()` en tests y en la sesión.
- Prohibido: `Node`, `Input`, `MultiplayerAPI`, `get_tree()`, `@rpc`, `await` de escena.
- Recibe números **o Resources de definición** por constructor. No lee autoloads en tests.
- **No** es el lugar de “cómo se ve el plasma”. Eso es `BulletData.tres`. Domain usa `data.damage`, no strings de tipo.

### Core

- **GameSession**: trackers por slot, `start` / `abort`, `submit_*`, `to_snapshot` / `apply_snapshot`. El cliente apaga el tick al aplicar snapshot.
- **GameEvents**: HUD/FX escuchan; el pawn no guarda el score.
- **SceneDirector**: cambia de escena. No puntúa.
- **GameConstants** / `MatchRules.tres`: tunables de **ronda** (duración, vidas, layers). No un dumping de 80 floats de cada enemigo.

1P = host local. Mismas reglas que 2P.

### Features

Nodos. `@rpc`, física, spawners. `@export var data: EnemyData` (o el tipo que sea). No `match kind`.

### Shared + resources

Componentes de escena en `shared/`. Plantillas `.tres` en `resources/<familia>/`.
