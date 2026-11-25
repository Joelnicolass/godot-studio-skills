# Resources — data templates (Godot 4)

Docs: [Resources](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html), [Node alternatives](https://docs.godotengine.org/en/stable/tutorials/best_practices/node_alternatives.html).

Nodes do. Resources **are data**. Godot loads each file once and shares it.

## When to use a Resource

The full rule (one owner per number, the three conditions for a `.tres`, catalogs) is rule 0 of [godot-code-quality](../godot-code-quality/SKILL.md). Here, how to do it.

Several types, same scene, numbers, references, or PackedScenes change: projectiles, enemies, items, weapons, waves. One `projectile.tscn`. Ten `_type.tres`. Zero `if kind ==`.

## Variants: numbers or structure

- **Other numbers:** another `_type.tres` (duplicate the file in the FileSystem and change its values).
- **Another structure or other art:** *New Inherited Scene* of the base scene. Only what differs changes. One level of inheritance, no more.
- Not a Resource with 40 flags, and not a scene copied node by node.
- Registering the variant: in the catalog that offers it (the spawner's `@export var types: Array[EnemyType]`, or a `_catalog.tres`).

An inner `class` that extends Resource **does not serialize**. File script + `class_name`.

## Recipe

1. `extends Resource` + `class_name ProjectileType`.
2. `@export` with defaults (otherwise the inspector fails).
3. Create Resource → `fast_projectile_type.tres`, `slow_projectile_type.tres` (text `.tres` for git).
4. On the actor: `@export var type: ProjectileType`.
5. Each `@export` with its `##`, range, and unit: it is the only thing whoever tunes will read.
6. If `type == null`: `_get_configuration_warnings()`; `assert` only as extra debug.

```gdscript
class_name ProjectileType
extends Resource
## One kind of projectile. One file per variant.

## Name shown in the HUD (a translation key).
@export var display_name: String = "PROJECTILE_DEFAULT"
## Damage per hit.
@export_range(0, 100) var damage: int = 1
## Travel speed.
@export_range(0.0, 2000.0, 10.0, "suffix:px/s") var speed: float = 400.0
## How long it lives without hitting anything.
@export_range(0.1, 10.0, 0.1, "suffix:s") var lifetime_s: float = 1.5
## Scene to spawn, if this variant looks different.
@export var scene: PackedScene
```

```gdscript
@export var type: ProjectileType

func _get_configuration_warnings() -> PackedStringArray:
	if type == null:
		return PackedStringArray(["Assign a ProjectileType resource."])
	return PackedStringArray()
```

## External or embedded

External `.tres`, with a name and a suffix: types, balance config, catalogs, and every look someone will tweak. Embedded in the scene: what carries no design or art decision (a collision shape).

## Do not mutate the template

`load("res://projectiles/fast/fast_projectile_type.tres")` is **the same** instance. `type.damage = 3` dirties every user.

- Definition: read-only.
- Working copy: `type.duplicate()`.
- Max HP on the Resource; current HP on the node.

## Where they live

Next to the scene that uses them, in the entity's folder (`projectiles/projectile.tscn`, `projectile_type.gd`, `fast/fast_projectile_type.tres`). What several entities share: `shared/` (or `content/` in systems + content). Folders and suffixes: [godot-code-quality](../godot-code-quality/SKILL.md) §1.

One file per element, with a name you can read (`terrains/plain_type.tres`, `terrains/forest_type.tres`), not an array of anonymous sub-resources (`Resource_umusd`) inside a set.

## Catalogs

A list of types to pick from (the terrains of a board, waves, orders) is a catalog: `Array[TerrainType]`, with each entry in its own file.

```gdscript
class_name TerrainType
extends Resource
## One terrain of the board. One file per terrain.

## Key painted on the cells. Declared here and nowhere else.
@export var id: StringName
## Tile scene drawn for this terrain.
@export var tile: PackedScene
## Steps it costs to enter. 0 = cannot be crossed.
@export_range(0, 10) var move_cost: int = 1
```

The cost of crossing a forest is a number in `forest_type.tres`, not a `match` in code. With many variants (about 15 or more), a table view helps compare them (rule 0).

## Anti-patterns

- `enum Kind` + `match` of stats on the projectile.
- One `.tres` per live instance.
- A `.tres` → `.tres` → node chain to find one number.
- A blind table: an untyped `Dictionary`, or anonymous sub-resources inside a set.
- A `.tres` with no type suffix.
- Inner class `class Foo extends Resource`.
- Overwriting `@export var type` in `_ready` to force a design number.
