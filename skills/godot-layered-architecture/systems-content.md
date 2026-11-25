# Tamaño grande — sistemas + contenido

Para un juego con mucho contenido (más de unos 10 tipos de entidad, varios niveles), con alguien que ajusta valores sin leer código, o cuando los sistemas se quieren reusar en otro juego. Es la estructura que usa un estudio de unas 30 personas con Godot ([GDQuest: Modular Game Architecture](https://www.gdquest.com/library/modular_game_architecture/)).

Valen los lineamientos comunes de [SKILL.md](SKILL.md) y todo lo de [by-entity.md](by-entity.md) sobre escenas autónomas, responsabilidades y autoloads. Cambian las carpetas.

## Forma del proyecto

```
res://
├── addons/                kits; no conocen el juego
├── systems/               reglas y mecánicas; no conocen el contenido
│   ├── combat/            health.gd, hitbox.tscn, damage_rules.gd   # núcleo puro
│   ├── units/             unit.tscn (la base), unit.gd, unit_type.gd
│   ├── match/             match.tscn, match.gd, match_rules.gd, match_config.gd
│   └── spawning/          spawner.gd
├── content/               todo lo que editan diseño y arte
│   ├── units/
│   │   ├── soldier/       soldier.tscn (heredada de unit.tscn), soldier_type.tres, model/, textures/
│   │   └── archer/
│   ├── levels/forest/     forest.tscn, forest_env.tres, forest_layout.tres
│   ├── balance/           match_config.tres, waves/
│   ├── materials/         stone_material.tres
│   ├── vfx/               hit_flash.tscn, hit_flash.gdshader
│   └── locale/            texts.csv
├── ui/                    lee de systems; no cambia el estado del juego
├── autoloads/             events.gd
├── debug/                 escenas de prueba (fuera del export)
└── docs/                  architecture.md, tuning.md, .gdignore
```

## Quién conoce a quién

- `content` usa `systems`. `systems` **no nombra** ninguna ruta de `content`: recibe escenas y `.tres` por `@export`.
- `ui` lee de `systems` y emite pedidos. No tiene reglas.
- `addons` no nombra nada del juego.
- Nadie nombra `res://debug`.

Se revisa con `rg`, sin un lint propio:

```bash
rg -n "res://content" systems/                # must be empty
rg -n "res://(content|systems|ui)" addons/    # must be empty
rg -n "res://debug" --glob '!debug/**'        # must be empty
```

## Qué va en cada lado

| Va en `systems/` | Va en `content/` |
|---|---|
| El script y la escena base de una familia (`unit.tscn`, `unit.gd`) | Cada variante: su escena heredada, su `_type.tres`, su arte |
| La clase del tipo (`unit_type.gd`) | Los `.tres` de ese tipo |
| Componentes (`Health`, `Hitbox`) y núcleos puros | Niveles, materiales, `Environment`, efectos, curvas |
| La clase de la configuración (`match_config.gd`) | `balance/match_config.tres`, las tablas de oleadas |

Dentro de `content/` valen las reglas de carpeta de [godot-code-quality](../godot-code-quality/SKILL.md) §1: carpeta por entidad, subcarpetas por tipo al pasar unos 8 archivos, y lo que comparten varias entidades en `content/materials/`, `content/vfx/`, `content/shaders/`. No hay `shared/`: lo común de código está en `systems/` y lo común de arte en `content/`.

## Qué gana y qué pierde

- Gana: quien ajusta el juego trabaja casi solo dentro de `content/`. Todo el balance y todo el look están bajo una raíz.
- Pierde: el script base de una unidad y su variante quedan en carpetas distintas, así que quien programa hace un salto más. Pide disciplina (los tres `rg` de arriba). Es demasiado para un juego de jam.
