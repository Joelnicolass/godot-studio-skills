extends Node3D

## A map whose script uses an autoload (PropLabGlobals) by name, as a game's maps do. It compiles
## only where the project's autoloads are loaded.

@export var floor_shape: BoxShape3D


func _ready() -> void:
	floor_shape.size = Vector3(PropLabGlobals.floor_size, 1.0, PropLabGlobals.floor_size)
