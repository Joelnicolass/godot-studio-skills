# Resources — data templates (Godot 4)

Docs: [Resources](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html), [Node alternatives](https://docs.godotengine.org/en/stable/tutorials/best_practices/node_alternatives.html).

Nodes do. Resources **are data**. Godot loads each file once and shares it.

## When to use a Resource

Several types, same scene, numbers / refs / PackedScenes change: projectiles, enemies, items, weapons, spawn tables.

One `projectile.tscn`. Ten `.tres`. Zero `if kind ==`.

If the tree **structure** changes: a different packed scene, not a Resource with 40 flags.

An inner `class` that extends Resource **does not serialize**. File script + `class_name`.

## Recipe

1. `extends Resource` + `class_name ProjectileData`.
2. `@export` with defaults (otherwise the inspector fails).
3. Create Resource → `projectile_fast.tres`, `projectile_slow.tres` (text `.tres` for git).
4. On the actor: `@export var data: ProjectileData`.
5. If `data == null`: `_get_configuration_warnings()`; `assert` only as extra debug.

```gdscript
class_name ProjectileData
extends Resource

@export var display_name: String = "Default"
@export var damage: int = 1
@export var speed: float = 400.0
@export var lifetime_sec: float = 1.5
@export var scene: PackedScene
```

```gdscript
@export var data: ProjectileData

func _get_configuration_warnings() -> PackedStringArray:
	if data == null:
		return PackedStringArray(["Assign a ProjectileData resource."])
	return PackedStringArray()
```

## External vs built-in

External `.tres` = default for shared templates. Built-in = data for a single instance.

## Do not mutate the template

`load("res://resources/projectiles/projectile_fast.tres")` is **the same** instance. `data.damage = 3` dirties every user.

- Definition: read-only.
- Working copy: `data.duplicate()`.
- Max HP on the Resource; current HP on the node.

## Where they live

Clean: `src/resources/<family>/`. Standard: `resources/<family>/`.

`MatchRules.tres`: few **round** values. Catalog: Resources. Instance look: node `@export`.

## Anti-patterns

- `enum Kind` + `match` of stats on the projectile.
- One `.tres` per live instance.
- Inner class `class Foo extends Resource`.
- Overwriting `@export var data` in `_ready` to force a design number.
