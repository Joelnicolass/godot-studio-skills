# Examples — composición (genéricos)

Nada de un título concreto. Copiá y adaptá.

## Actor como contenedor

```
Actor (CharacterBody2D)
├── Visual         Sprite2D
├── Health         packed scene
├── States         StateMachine
│   ├── Idle
│   ├── Move
│   └── Hurt
└── MultiplayerSynchronizer
```

```gdscript
class_name StateMachine
extends Node

@export var initial_state: State
@export var actor: Node

var _current: State


func _ready() -> void:
	_current = initial_state
	if _current != null:
		_current.enter()


func transition(state_name: StringName) -> void:
	var next := get_node_or_null(NodePath(state_name)) as State
	if next == null or next == _current:
		return
	_current.exit()
	_current = next
	_current.enter()
```

## Socket `@export` + UniqueName

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
class_name ProjectileData
extends Resource

@export var display_name: String = "Default"
@export var damage: int = 1
@export var speed: float = 400.0
```

Un `projectile_fast.tres` y un `projectile_slow.tres` apuntan a la misma `projectile.tscn`.
