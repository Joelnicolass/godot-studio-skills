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

## `@export` socket + UniqueName

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
class_name ProjectileData
extends Resource

@export var display_name: String = "Default"
@export var damage: int = 1
@export var speed: float = 400.0
```

A `projectile_fast.tres` and a `projectile_slow.tres` point at the same `projectile.tscn`.
