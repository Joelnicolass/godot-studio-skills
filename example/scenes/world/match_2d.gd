extends Node2D


func _ready() -> void:
	var cam := get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.enabled = true
		cam.make_current()
