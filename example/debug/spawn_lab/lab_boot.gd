extends Node

## Lab entry (all roles). The demo flow (NetSession) must not change scenes here:
## its MpKit signals are dropped and LabSession drives host/join/load.


func _ready() -> void:
	NetSession._exit_tree()
	var session := preload("res://debug/spawn_lab/lab_session.gd").new()
	session.name = "LabSession"
	get_tree().root.add_child.call_deferred(session)
