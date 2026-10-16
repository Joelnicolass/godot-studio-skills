extends Node2D

## Lab actor. The server counts `tick`; a peer that receives sync sees it grow.

@export var tick: int = 0
## Adds a second synchronizer one frame after _ready (after the spawn was queued).
@export var add_sync_deferred: bool = false


func _ready() -> void:
	if add_sync_deferred:
		_add_sync.call_deferred()


func _physics_process(_delta: float) -> void:
	if MpKit.is_server():
		tick += 1


func _add_sync() -> void:
	var cfg := SceneReplicationConfig.new()
	cfg.add_property(NodePath(".:tick"))
	var sync := MultiplayerSynchronizer.new()
	sync.name = "DeferredSync"
	sync.replication_config = cfg
	add_child(sync)
