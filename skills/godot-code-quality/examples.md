# Before / after — code quality (generic)

Nothing from a concrete title. Each case names the rule of [SKILL.md](SKILL.md) it applies.

## 1. A number behind a chain of `.tres` files (rule 0)

Before: changing the bat's fury damage means opening 4 files.

```text
bat.tres          on_hit_ability = bat_fury_ability.tres    # nothing says "fury"
bat_fury_ability.tres                                        # empty ability
bat_fury.tres     ability = bat_fury_ability.tres, factor = 1.5
enemy.tscn        PassiveRunner.types = [bat_fury.tres, …]   # looks for the one pointing at on_hit_ability
```

After: the number lives on the type that uses it, and the component reads it directly.

```gdscript
# enemy_type.gd
## Damage multiplier while the enemy is below half health. 1.0 = no fury.
@export_range(1.0, 3.0, 0.05) var fury_damage_factor := 1.0
```

Open: 1 file (`bat.tres`). If only one enemy has that passive, even better: a `Fury` component only in its scene, with its own `@export`.

## 2. A string that picks a scene (rule 0, §1)

```gdscript
# Before
@export var projectile_kind := "Fireball"      # key of a dictionary on another node
# … in the spawner:
const SCENES := {"Fireball": preload("res://projectiles/fireball.tscn"), …}

# After: the designer drags the scene
@export var projectile: PackedScene
```

## 3. A `Dictionary` whose keys live in a comment (§4)

```gdscript
# Before: the contract only exists in a comment in another file
func launch(data: Dictionary) -> void:
	position = Vector3(data["x"], data["y"], data["z"])
	_damage = float(data["damage"])

# After: a typed class; the Dictionary only at the network edge
class_name ProjectileLaunch
extends RefCounted
## What a projectile is told when it leaves.

var from: Vector3
var target: NodePath
var damage: float


func to_dict() -> Dictionary:
	return {"from": from, "target": target, "damage": damage}


static func from_dict(data: Dictionary) -> ProjectileLaunch:
	var launch := ProjectileLaunch.new()
	launch.from = data.get("from", Vector3.ZERO)
	launch.target = data.get("target", NodePath())
	launch.damage = data.get("damage", 0.0)
	return launch
```

## 4. Reflection on a known type (§4)

```gdscript
# Before
var pool := _player.get_node_or_null("Mana")
var mana := float(pool.get("current")) if pool else 0.0
if target.has_method("is_targetable") and target.call("is_targetable"):
	pass

# After: a typed @export and a typed contract
@export var player: Player              # Player declares `@export var mana: ManaPool`
var mana := player.mana.current
var body := target as Body
if body and body.is_targetable():
	pass
```

`Body` is the one-level base the bodies share (`class_name Body extends CharacterBody2D`); a common child component is the other option.

## 5. A child that calls its parent (§2, signal up / call down)

```gdscript
# Before: health.gd knows its owner
func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		get_parent().on_died()

# After: the child reports; the parent decides
signal died


func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		died.emit()

# enemy.gd (the parent)
func _ready() -> void:
	health.died.connect(_on_health_died)
```

## 6. An event between systems that do not know each other (§2, `Events` bus)

```gdscript
# events.gd, autoload "Events". No class_name: it would clash with the autoload name.
extends Node
## Game-wide events between systems that do not know each other. Signals only.

signal enemy_died(enemy: Enemy)
signal score_changed(slot: int, score: int)
```

```gdscript
# enemy.gd emits the fact it owns
Events.enemy_died.emit(self)

# hud.gd listens without knowing the enemy or the spawner
func _ready() -> void:
	Events.score_changed.connect(_on_score_changed)
```

A `health_changed` that only the same enemy's health bar listens to stays a `Health` signal, not a bus signal.

## 7. Comments that are not documentation (§5)

```gdscript
# Before
## Ref: original_game/combat.c:9011-9015 (RFC-042).
@export var armor_factor := 0.5

func hit(amount: float) -> float:
	## Armor halves the damage.
	return amount * armor_factor

# After: the tooltip says what it does; notes use #; the citation moves to a separate doc
## Fraction of incoming damage that goes through the armor.
@export_range(0.0, 1.0, 0.05) var armor_factor := 0.5


func hit(amount: float) -> float:
	return amount * armor_factor
```

## 8. Code compressed to fit a line cap (§4)

```gdscript
# Before
func _tick() -> void:
	for t in tracks: if t.alive and t.seen(now) and t.relation == 2: _hostile.append(t)

# After: one statement per line and an enum instead of the 2
func _tick() -> void:
	for track in tracks:
		if track.alive and track.seen(now) and track.relation == Relation.HOSTILE:
			_hostile.append(track)
```

When the script grows, split it by responsibility (another component), not to lower the line count.
