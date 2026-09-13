# Examples — composición (genéricos)

Nada de un título concreto. Copiá y adaptá.

## Pawn como contenedor

```
Pawn (RigidBody2D)
├── Hull          Polygon2D / Sprite2D
├── Trail         packed scene reusable
├── Feedback      preview de fuerza / aim
├── States        StateMachine
│   ├── Coasting
│   ├── Aiming
│   └── Eliminated
└── MultiplayerSynchronizer
```

```gdscript
# states/state_machine.gd
class_name StateMachine
extends Node

@export var initial_state: State

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

## Resource de tipo + una escena

```gdscript
class_name BulletData
extends Resource

@export var display_name: String = "Plasma"
@export var damage: int = 1
@export var speed: float = 520.0
@export var lifetime_sec: float = 1.4
```

```gdscript
# bullet.gd
extends Area2D

@export var data: BulletData


func _ready() -> void:
	assert(data != null)
```

Un `plasma.tres` y un `spread.tres` apuntan a la misma `bullet.tscn`.
