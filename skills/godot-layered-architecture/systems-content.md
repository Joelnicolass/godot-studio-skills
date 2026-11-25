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
│   ├── match/             match.gd, match_rules.gd (pure core), match_config.gd
│   └── spawning/          spawner.gd
├── content/               everything design and art edit
│   ├── units/
│   │   ├── soldier/       soldier.tscn (inherited from unit.tscn), soldier_type.tres, model/, textures/
│   │   └── archer/
│   ├── levels/forest/     forest.tscn (the match, with match.gd), forest_env.tres, forest_layout.tres
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

### Cases that trip people up

- **The pure core of the rules** (what Clean called `domain/`) goes in `systems/<name>/`, with no nodes: `RefCounted` and `static func`, like `systems/rules/` or `systems/combat/damage_rules.gd`. Tests use it directly.
- **The scene that puts the content together** (the level, the match with its board, its tiles and its materials) lives in `content/` (`content/levels/<level>/<level>.tscn`), even when its script is in `systems/`. `systems/` only holds scenes that name nothing in `content`: the base of a family, a component.
- **A config has no default loaded from `content`.** The system receives it from outside: the scene assigns it through an `@export`, and tests and tools load it themselves.

  ```gdscript
  # systems/match/match.gd: the level scene assigns the config; the system never loads it.
  @tool
  extends Node

  @export var config: MatchConfig


  func _get_configuration_warnings() -> PackedStringArray:
  	if config == null:
  		return PackedStringArray(["Assign a MatchConfig (a _config.tres in content/balance/)."])
  	return PackedStringArray()
  ```

  A test does `load("res://content/balance/match_config.tres")` from `tests/`, not from `systems/`.
- **A component that owns its shader** (a `PixelSprite` that builds its material) keeps it next to it, in `systems/<component>/`, as [godot-composition-first](../godot-composition-first/SKILL.md) §6 says. `content/shaders/` is for the content's shaders: an effect, a level's material.

Inside `content/` the folder rules of [godot-code-quality](../godot-code-quality/SKILL.md) §1 apply: a folder per entity, subfolders by type past about 8 files, and what several entities share in `content/materials/`, `content/vfx/`, `content/shaders/` (except a component's own shader, which stays with it). There is no `shared/`: shared code is in `systems/` and shared art in `content/`.

## What it gains and what it loses

- Gains: whoever tunes the game works almost only inside `content/`. All the balance and all the look sit under one root.
- Loses: a unit's base script and its variant end up in different folders, so the programmer makes one more hop. It takes discipline (the three `rg` checks above). It is too much for a jam game.
