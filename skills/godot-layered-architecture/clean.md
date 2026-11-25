# Clean en capas (solo repos que ya lo declaran)

No se ofrece a un proyecto nuevo. Usar **solo** si el repo ya lo declara o si el usuario lo pidió por nombre. Para un juego nuevo: [by-entity.md](by-entity.md) o [systems-content.md](systems-content.md). Lo que Clean buscaba, reglas que se prueban sin escena, lo da el núcleo puro de [SKILL.md](SKILL.md) §2.

Dependencias hacia adentro:

```
features (nodos, .tscn, física, spawners)
    → core (autoloads: sesión, eventos, cambio de escena)
        → domain (RefCounted: reglas de partida)
```

```
src/
  core/              # Events, GameSession, SceneDirector
  domain/            # reglas puras: estado de la ronda, no catálogos
  features/<name>/   # scripts + escenas juntas, con sus .tres
  shared/            # componentes, y shaders y materiales que usan varias features
  balance/           # match_config.tres y otros .tres de balance
addons/              # kits (cero gameplay)
docs/                # architecture.md, tuning.md
```

Nombres de archivo y sufijos: [godot-code-quality](../godot-code-quality/SKILL.md) §1. `docs/tuning.md` es obligatorio acá también.

### Domain

Las reglas del núcleo puro de [SKILL.md](SKILL.md) §2, en la carpeta `src/domain/`. Usa `type.damage`, no textos de tipo. No decide cómo se ve nada.

### Core

- **GameSession**: el estado de la partida y `start` / `abort`. Autoload **solo** si tiene que sobrevivir al cambio de escena; si no, un nodo bajo `Main`. Si tiene valores que se ajustan, se registra como `.tscn` o lee `balance/match_config.tres`.
- **Events**: bus de eventos, solo declaraciones `signal` tipadas (sin estado ni métodos). HUD y efectos escuchan; el actor no guarda el puntaje.
- **SceneDirector**: cambia de escena. Preferí cambiar los hijos de `World` y dejar `GUI` viva. No puntúa.

Solo si hay red: `GameSession` suma `submit_*` y `to_snapshot` / `apply_snapshot`; el cliente apaga su tick al aplicar un snapshot; un jugador solo es un host local con las mismas reglas. Sin red, nada de eso existe.

### Features

Nodos, física, spawners. `@export var type: EnemyType`. No `match kind`.
