# Examples — composición (genéricos)

Nada de un título concreto. Copiá y adaptá.

## Actor como contenedor

```
Actor (CharacterBody2D)
├── Visual         Sprite2D
├── Health         packed scene
├── States         FsmMachine
│   ├── Idle
│   ├── Move
│   └── Hurt
└── MultiplayerSynchronizer
```

Preferí el addon `fsm_kit` (`./install.sh --addon … fsm_kit`) a copiar una clase. `/add-state-machine`.

```gdscript
class_name IdleState
extends FsmState


func physics_update(_delta: float) -> void:
	if absf(actor.velocity.x) > 8.0:
		transition(&"Move")
```

## Referencia `@export` + UniqueName

```gdscript
@export var health: Health
@onready var sprite: Sprite2D = %Sprite2D


func _get_configuration_warnings() -> PackedStringArray:
	if health == null:
		return PackedStringArray(["Assign a Health component."])
	return PackedStringArray()
```

## Resource de tipo + una escena

```gdscript
class_name ProjectileType
extends Resource

## Name shown in the HUD (a translation key).
@export var display_name: String = "PROJECTILE_DEFAULT"
## Damage per hit.
@export_range(0, 100) var damage: int = 1
## Travel speed.
@export_range(0.0, 2000.0, 10.0, "suffix:px/s") var speed: float = 400.0
```

Un `fast_projectile_type.tres` y un `slow_projectile_type.tres` apuntan a la misma `projectile.tscn`.

## Juicy con Tween + inspector

```gdscript
@export_group("Land squash")
## Scale at the bottom of the squash.
@export var squash_scale: Vector2 = Vector2(1.2, 0.8)
## Time to reach the squash.
@export_range(0.0, 1.0, 0.01, "suffix:s") var squash_duration: float = 0.08
## Time to get back to normal.
@export_range(0.0, 1.0, 0.01, "suffix:s") var recover_duration: float = 0.12
## Shape of the motion. Pick it here, not in the code.
@export var transition: Tween.TransitionType = Tween.TRANS_QUAD
@export var ease_type: Tween.EaseType = Tween.EASE_OUT


func play_land() -> void:
	var tw := create_tween().set_trans(transition).set_ease(ease_type)
	tw.tween_property(%Visual, "scale", squash_scale, squash_duration)
	tw.tween_property(%Visual, "scale", Vector2.ONE, recover_duration)
```

Una forma que no es una de las de `Tween`: `@export var curve: Curve`, y `tween_method` que la lee con `curve.sample(t)`. Se dibuja en el inspector.

Doce principios: [godot-animation](../godot-animation/SKILL.md). Este clip es one-shot paramétrico → Tween. Varios tracks / loop authorado → `AnimationPlayer`. Ni los números ni la curva van en el código.
