# Small size — by entity

The default. For one or two programmers and up to about 10 entity types. It follows Godot's recommendation: each thing as close as possible to the scene that uses it ([project organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html)).

The shared guidelines of [SKILL.md](SKILL.md) apply: simple and predictable, composition, editor, optional pure core, one responsibility per script, signals up and calls down.

## Project shape

One folder per subject at the root, with no `scenes/` folder wrapping everything.

```
res://
├── main/                  main.tscn, main.gd            # entry: World + GUI
├── player/                player.tscn, player.gd
│   ├── model/             player.glb, player_material.tres
│   └── audio/
├── enemies/
│   ├── enemy.tscn         # the base scene
│   ├── enemy.gd
│   ├── enemy_type.gd      # class_name EnemyType extends Resource
│   ├── bat/               bat_type.tres, bat.png
│   └── tank/              tank_type.tres, tank.tscn (inherited from enemy.tscn)
├── levels/
│   └── forest/            forest.tscn, forest_env.tres
├── match/                 match.tscn, match.gd, match_rules.gd   # node + pure core
├── ui/
│   ├── hud/               hud.tscn, hud.gd
│   └── game_theme.tres
├── shared/                what two or more entities use, by type
│   ├── components/        health.gd, hitbox.tscn
│   ├── shaders/           hit_flash.gdshader
│   ├── materials/         stone_material.tres
│   └── vfx/               hit_flash.tscn
├── locale/                texts.csv                     # the player-facing text
├── autoloads/             events.gd
├── debug/                 test scenes (left out of the export)
├── addons/                kits
└── docs/                  architecture.md, tuning.md, .gdignore
```

Folder rules and suffixes (`_type.tres`, `_material.tres`, …): [godot-code-quality](../godot-code-quality/SKILL.md) §1. In short:

- What a single entity uses lives in its folder.
- When the folder goes past about 8 files, the art moves down to subfolders by type **inside the entity** (`model/`, `textures/`, `audio/`, `vfx/`). The scene, its script, and its type `.tres` stay on top.
- What two or more entities use goes to `shared/`, and there it is by type.
- The code that connects a kit to the game (starting the network, loading the world) is an autoload in `autoloads/` or a node of `main/`. There is no `glue/`, `scripts/`, `resources/`, or `assets/` folder.

Invalid: a thousand-line `player.gd` with `match weapon`.

## Autonomous scenes

Each `.tscn` should open with **F6** and work (or warn). Docs: [scene organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html).

- It does not depend on what surrounds it. What is missing, the parent hands over: `@export var health: Health`, a `Callable`, or a node.
- Signals in the **past tense** and typed. The **parent** does `child.died.connect(...)`. The child does not call `get_parent().on_died()`.
- Nodes of *this* scene: `%UniqueName` (`%Sprite`). Between scenes: an `@export` reference, not `get_node("../../Audio")`.
- If a required reference is empty: `@tool` + `_get_configuration_warnings()`.
- Relational, not spatial: should deleting the parent delete the child? If not, sibling. Relative position: `RemoteTransform2D` / `RemoteTransform3D`.
- `Main` (entry) → `World` (levels replace) + `GUI` (sibling; does not die with the level).

## One responsibility per script

- One node = one job. Movement ≠ health ≠ shooting ≠ HUD.
- Extract a child packed scene when the script implements two systems.
- Shallow script inheritance: `State extends Node`. Not `EliteFlyingEnemy extends FlyingEnemy extends Enemy`.
- The world **composes** spawners, camera, and effects. It does not score in the same file that spawns enemies.
- No line cap: a cohesive 400-line script is fine; two systems in 120 lines are not.

## Match state

- The `match/match.tscn` scene, with a small `Match` node, instanced in the world. Its rules (duration, lives) are `@export`s on its root: a file with an obvious name.
- The rules that deserve a test go to the pure core next to it (`match_rules.gd`).
- Autoload **only if** the state survives a scene change.
- If networked: only the host changes that state.

## Autoloads

Yes: the `Events` bus (typed signals only), `MpKit`, the network startup.
No: `EnemyManager`, a global projectile factory, the run inventory if it can live in the tree. Audio: `AudioStreamPlayer` or a component in the scene; a sound autoload only if it is an isolated service.

## Extra checklist

- [ ] Does the scene run with F6? Does what it needs arrive through `@export`? Does it warn when a reference is missing?
- [ ] Is each new file in its entity's folder or in `shared/`, with its suffix?
- [ ] Does changing a number open 2 files at most, and does `docs/tuning.md` say which?
- [ ] Did `scenes/`, `scripts/`, `resources/`, `assets/`, or `domain/` not show up?
