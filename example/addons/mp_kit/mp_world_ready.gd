class_name MpWorldReady
extends Node

## Place in the match scene after spawners (later sibling or deeper).
## Clients: request_world_ready after the rest of this scene has _ready
## (so extra_scenes / add_spawnable_scene on siblings are registered).
## Server / offline: no-op. Listen and dedicated: same node.

func _ready() -> void:
	if not MpKit.is_networked() or MpKit.is_server():
		return
	call_deferred("_request")


func _request() -> void:
	if not is_inside_tree():
		return
	if not MpKit.is_networked() or MpKit.is_server():
		return
	MpKit.request_world_ready()
