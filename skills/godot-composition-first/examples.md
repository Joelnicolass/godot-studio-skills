# Examples — composition (generic)

Nothing from a concrete title. Copy and adapt.

## Actor as container

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

Prefer the `fsm_kit` addon (`./install.sh --addon … fsm_kit`) over copying a class. `/add-state-machine`.

```gdscript
class_name IdleState
extends FsmState


func physics_update(_delta: float) -> void:
	if absf(actor.velocity.x) > 8.0:
		transition(&"Move")
```

## `@export` reference + UniqueName

```gdscript
@export var health: Health
@onready var sprite: Sprite2D = %Sprite2D


func _get_configuration_warnings() -> PackedStringArray:
	if health == null:
		return PackedStringArray(["Assign a Health component."])
	return PackedStringArray()
```

## Type Resource + one scene

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

A `fast_projectile_type.tres` and a `slow_projectile_type.tres` point at the same `projectile.tscn`.

## Juicy with Tween + inspector

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

A shape that is not one of `Tween`'s: `@export var curve: Curve`, and a `tween_method` that reads it with `curve.sample(t)`. It is drawn in the inspector.

Twelve principles: [godot-animation](../godot-animation/SKILL.md). This clip is a parametric one-shot → Tween. Several tracks or an authored loop → `AnimationPlayer`. Neither the numbers nor the curve go in code.
