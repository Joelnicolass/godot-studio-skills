class_name DemoMatch
extends Node

## Elapsed snapshot only. Pawns come from MpSlotSpawner.

@export var snapshot_hz: float = 5.0

var elapsed: float = 0.0
var _snap_accum: float = 0.0


func _ready() -> void:
	MpKit.snapshot_received.connect(_on_snapshot)
	if MpKit.is_networked() and not MpKit.is_server():
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	elapsed += delta
	if not MpKit.is_server() or not MpKit.is_networked():
		return
	if snapshot_hz <= 0.0:
		return
	_snap_accum += delta
	if _snap_accum < 1.0 / snapshot_hz:
		return
	_snap_accum = 0.0
	MpKit.push_snapshot({"elapsed": elapsed, "world_kind": NetGlue.world_kind})


func _on_snapshot(data: Dictionary) -> void:
	if MpKit.is_server():
		return
	elapsed = float(data.get("elapsed", elapsed))
	set_physics_process(false)
