# Antes / después — calidad de código (genéricos)

Nada de un título concreto. Cada caso dice qué regla de [SKILL.md](SKILL.md) aplica.

## 1. Un número detrás de una cadena de `.tres` (regla 0)

Antes: para cambiar el daño de la furia del murciélago hay que abrir 4 archivos.

```text
bat.tres          on_hit_ability = bat_fury_ability.tres    # nothing says "fury"
bat_fury_ability.tres                                        # empty ability
bat_fury.tres     ability = bat_fury_ability.tres, factor = 1.5
enemy.tscn        PassiveRunner.types = [bat_fury.tres, …]   # looks for the one pointing at on_hit_ability
```

Después: el número vive en el tipo que lo usa, y el componente lo lee directo.

```gdscript
# enemy_type.gd
## Damage multiplier while the enemy is below half health. 1.0 = no fury.
@export_range(1.0, 3.0, 0.05) var fury_damage_factor := 1.0
```

Abrir: 1 archivo (`bat.tres`). Si un solo enemigo tiene esa pasiva, mejor todavía: un componente `Fury` solo en su escena, con su `@export`.

## 2. Un texto que elige una escena (regla 0, §1)

```gdscript
# Before
@export var projectile_kind := "Fireball"      # key of a dictionary on another node
# … in the spawner:
const SCENES := {"Fireball": preload("res://projectiles/fireball.tscn"), …}

# After: the designer drags the scene
@export var projectile: PackedScene
```

## 3. Un `Dictionary` con las claves en un comentario (§4)

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

## 4. Reflexión sobre un tipo conocido (§4)

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

`Body` es la base de un nivel que comparten los cuerpos (`class_name Body extends CharacterBody2D`); otra opción es un componente hijo común.

## 5. Un hijo que llama a su padre (§2, signal up / call down)

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

## 6. Un evento entre sistemas que no se conocen (§2, bus `Events`)

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

Un `health_changed` que solo escucha la barra de vida del mismo enemigo sigue siendo una señal de `Health`, no del bus.

## 7. Comentarios que no son documentación (§5)

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

## 8. Código comprimido para entrar en un tope de líneas (§4)

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

Si el script crece, se parte por responsabilidad (otro componente), no para bajar el número de líneas.
