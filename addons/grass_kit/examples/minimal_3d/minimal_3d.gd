extends Node3D

## GrassKit's minimal example: a GrassField3D over a floor with a collider, its ground read from that
## collider when the scene starts. In a game you press «Bake ground» in the editor instead (or add
## the field and let it set itself up), paint, and save: the ground then comes baked in its file and
## this script is not needed. The floor's shader includes grass_ground.gdshaderinc, so it meets the
## far grass without a seam. Space: the next look (uniforms only, nothing is rebuilt).

const LOOKS: Array[GrassLook] = [
	preload("res://addons/grass_kit/looks/meadow.tres"),
	preload("res://addons/grass_kit/looks/autumn.tres"),
	preload("res://addons/grass_kit/looks/steppe.tres"),
]

@onready var field: GrassField3D = $GrassField3D


func _ready() -> void:
	# A collider is in the physics space one frame after it enters the tree.
	await get_tree().physics_frame
	field.bake_ground()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept"):
		field.look = LOOKS[(LOOKS.find(field.look) + 1) % LOOKS.size()]
