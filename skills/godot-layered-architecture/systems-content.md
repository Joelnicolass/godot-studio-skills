# Large size — systems + content

For a game with lots of content (more than about 10 entity types, several levels), with someone who tunes values without reading code, or when the systems are meant to be reused in another game. It is the structure a studio of about 30 people uses with Godot ([GDQuest: Modular Game Architecture](https://www.gdquest.com/library/modular_game_architecture/)).

The shared guidelines of [SKILL.md](SKILL.md) apply, and so does everything in [by-entity.md](by-entity.md) about autonomous scenes, responsibilities, and autoloads. The folders change.

## Project shape

```
res://
├── addons/                kits; they do not know the game
├── systems/               rules and mechanics; they do not know the content
│   ├── combat/            health.gd, hitbox.tscn, damage_rules.gd   # pure core
│   ├── units/             unit.tscn (the base), unit.gd, unit_type.gd
│   ├── match/             match.tscn, match.gd, match_rules.gd, match_config.gd
│   └── spawning/          spawner.gd
├── content/               everything design and art edit
│   ├── units/
│   │   ├── soldier/       soldier.tscn (inherited from unit.tscn), soldier_type.tres, model/, textures/
│   │   └── archer/
│   ├── levels/forest/     forest.tscn, forest_env.tres, forest_layout.tres
│   ├── balance/           match_config.tres, waves/
│   ├── materials/         stone_material.tres
│   ├── vfx/               hit_flash.tscn, hit_flash.gdshader
│   └── locale/            texts.csv
├── ui/                    reads from systems; does not change game state
├── autoloads/             events.gd
├── debug/                 test scenes (left out of the export)
└── docs/                  architecture.md, tuning.md, .gdignore
```

## Who knows whom

- `content` uses `systems`. `systems` **never names** a `content` path: it receives scenes and `.tres` files through `@export`.
- `ui` reads from `systems` and emits requests. It holds no rules.
- `addons` names nothing of the game.
- Nobody names `res://debug`.

Checked with `rg`, with no lint of its own:

```bash
rg -n "res://content" systems/                # must be empty
rg -n "res://(content|systems|ui)" addons/    # must be empty
rg -n "res://debug" --glob '!debug/**'        # must be empty
```

## What goes on each side

| Goes in `systems/` | Goes in `content/` |
|---|---|
| The script and base scene of a family (`unit.tscn`, `unit.gd`) | Each variant: its inherited scene, its `_type.tres`, its art |
| The type's class (`unit_type.gd`) | The `.tres` files of that type |
| Components (`Health`, `Hitbox`) and pure cores | Levels, materials, `Environment`, effects, curves |
| The config's class (`match_config.gd`) | `balance/match_config.tres`, the wave tables |

Inside `content/` the folder rules of [godot-code-quality](../godot-code-quality/SKILL.md) §1 apply: a folder per entity, subfolders by type past about 8 files, and what several entities share in `content/materials/`, `content/vfx/`, `content/shaders/`. There is no `shared/`: shared code is in `systems/` and shared art in `content/`.

## What it gains and what it loses

- Gains: whoever tunes the game works almost only inside `content/`. All the balance and all the look sit under one root.
- Loses: a unit's base script and its variant end up in different folders, so the programmer makes one more hop. It takes discipline (the three `rg` checks above). It is too much for a jam game.
