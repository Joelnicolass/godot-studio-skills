# Examples — composition (generic)

No specific title. Copy and adapt.

## Pawn as container

```
Pawn (RigidBody2D)
├── Hull          Polygon2D / Sprite2D
├── Trail         reusable packed scene
├── Feedback      force / aim preview
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

## Type Resource + one scene

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

A `plasma.tres` and a `spread.tres` point at the same `bullet.tscn`.
