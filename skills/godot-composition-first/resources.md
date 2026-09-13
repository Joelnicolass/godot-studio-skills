# Resources — data templates (Godot 4)

Engine docs: [Resources](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html), [Node alternatives](https://docs.godotengine.org/en/stable/tutorials/best_practices/node_alternatives.html).

Nodes do (draw, simulate, fire). Resources **are data**. Godot loads each file once and shares it: that is why they work as a catalog.

## When to use Resource (priority)

If there are **several types** that share the same scene and change numbers, refs, or PackedScenes:

- Bullets / projectiles (`damage`, `speed`, `lifetime`, `scene`)
- Enemies / NPCs (`max_hp`, `speed`, `loot`, `scene`)
- Power-ups / items (`id`, `duration`, `icon`)
- Weapons / abilities (`fire_rate`, `projectile`, `sfx`)
- Tables (spawn weights, waves, loot)

One `bullet.tscn`. Ten `.tres`. Zero `if kind ==`.

If the tree **structure** changes (another collider, another child), a different packed scene or composition — not a Resource with 40 “enable_wing” flags.

An inner `class` that extends Resource **does not serialize**. Always a file script + `class_name`.

## Recipe

1. Script `extends Resource` + `class_name BulletData`.
2. `@export` / `@export_group` / `@export_range`. Every `_init` parameter needs a default (otherwise the inspector fails).
3. FileSystem → Create Resource → `BulletData` → `plasma.tres`, `spread.tres` (text `.tres` for git).
4. On the actor: `@export var data: BulletData`. Drag the `.tres`.
5. Runtime reads `data.speed`. Live state (`hp` now) on the node, not the `.tres`.

```gdscript
class_name BulletData
extends Resource

@export var display_name: String = "Plasma"
@export var damage: int = 1
@export var speed: float = 520.0
@export var lifetime_sec: float = 1.4
@export var scene: PackedScene  # if the type changes visuals
```

```gdscript
# bullet.gd — one script for every type
@export var data: BulletData

func _ready() -> void:
	assert(data != null)
```

The weapon/spawner holds the Resource (or the Resource holds the `PackedScene`) and does `data.scene.instantiate()` + assigns `data`.

## External vs built-in

| | When |
|--|--------|
| External `.tres` | Shared by several scenes (player, enemy, UI). **Default for templates.** |
| Built-in in the `.tscn` | Data for one instance, not reusable. |

## Do not mutate the template

`load("res://resources/bullets/plasma.tres")` returns **the same** instance. `data.damage = 3` at runtime dirties every bullet (and in the editor may write the asset).

- Definition: read-only.
- Working copy: `data.duplicate()` (buffs, rolls).
- Scene instance: `resource_local_to_scene` if the override belongs to that `.tscn`.

Max HP on the Resource; current HP on the node (or `duplicate()` on spawn).

## Where they live

Clean: `src/resources/<family>/`. Standard: `resources/<family>/` or next to the actor. The class `.gd` next to the `.tres` files.

Tables: a Resource that exports `Array[EnemyData]` or a `Dictionary` of Resources — not hand-parsed JSON if the inspector can edit it.

## Relation to constants

`GameConstants` / `MatchRules.tres`: few **round** values.  
Content catalog: Resources.  
Look of a glow in *this* scene: `@export` on the node.

## Anti-patterns

- `enum BulletKind` + `match` of stats on the projectile.
- One `.tres` per *live instance* (that is the node).
- Inner class `class Foo extends Resource`.
- Overwriting `@export var data` from code in `_ready` to force a design number.
- Heavy PackedScenes and deep `duplicate(true)` without need (share the definition, instance the scene).
