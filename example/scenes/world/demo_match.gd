class_name DemoMatch
extends Node

## Spawn + handshake + elapsed snapshot. No scores.

@export var pawn_scene: PackedScene
@export var actors: Node
@export var spawn_points: Node
@export var looks: Array[ActorLook] = []
@export var snapshot_hz: float = 5.0

var elapsed: float = 0.0
var _pawns: Dictionary = {}
var _snap_accum: float = 0.0


func _ready() -> void:
	_resolve_nodes()
	_register_spawnable()
	MpKit.client_world_ready.connect(_on_client_world_ready)
	MpKit.peer_left.connect(_on_peer_left)
	MpKit.snapshot_received.connect(_on_snapshot)
	if not MpKit.is_networked():
		ensure_pawn(MpKit.local_slot())
		return
	if MpKit.is_server():
		if MpKit.is_listen_host():
			ensure_pawn(MpKit.local_slot())
		return
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


func ensure_pawn(slot: int) -> void:
	_resolve_nodes()
	if slot <= 0 or _pawns.has(slot):
		return
	if pawn_scene == null or actors == null:
		push_warning("DemoMatch: assign pawn_scene and actors")
		return
	var pawn := pawn_scene.instantiate()
	pawn.name = "Pawn_%d" % slot
	if "player_slot" in pawn:
		pawn.player_slot = slot
	if looks.size() > 0 and "look" in pawn:
		pawn.look = looks[(slot - 1) % looks.size()]
	_place(pawn, slot)
	actors.add_child(pawn, true)
	_pawns[slot] = pawn


func _resolve_nodes() -> void:
	var root := get_parent()
	if root == null:
		return
	if actors == null:
		actors = root.get_node_or_null("Actors")
	if spawn_points == null:
		spawn_points = root.get_node_or_null("SpawnPoints")
	if looks.is_empty():
		var packed: Array[ActorLook] = []
		for path in [
			"res://resources/looks/look_a.tres",
			"res://resources/looks/look_b.tres",
			"res://resources/looks/look_c.tres",
			"res://resources/looks/look_d.tres",
		]:
			var look := load(path) as ActorLook
			if look:
				packed.append(look)
		looks = packed


func _register_spawnable() -> void:
	if pawn_scene == null or pawn_scene.resource_path.is_empty():
		return
	var spawner := get_parent().get_node_or_null("MpSpawner") as MultiplayerSpawner
	if spawner == null:
		return
	spawner.add_spawnable_scene(pawn_scene.resource_path)


func _place(pawn: Node, slot: int) -> void:
	if spawn_points == null or actors == null:
		return
	var markers := spawn_points.get_children()
	if markers.is_empty():
		return
	var marker: Node = markers[(slot - 1) % markers.size()]
	if pawn is Node2D and marker is Node2D and actors is Node2D:
		(pawn as Node2D).position = (actors as Node2D).to_local((marker as Node2D).global_position)
	elif pawn is Node3D and marker is Node3D and actors is Node3D:
		(pawn as Node3D).position = (actors as Node3D).to_local((marker as Node3D).global_position)


func _on_client_world_ready(peer_id: int) -> void:
	if not MpKit.is_server():
		return
	ensure_pawn(MpKit.slot_for_peer(peer_id))


func _on_peer_left(_peer_id: int, slot: int) -> void:
	if not _pawns.has(slot):
		return
	var pawn: Node = _pawns[slot]
	_pawns.erase(slot)
	if is_instance_valid(pawn):
		pawn.queue_free()


func _on_snapshot(data: Dictionary) -> void:
	if MpKit.is_server():
		return
	elapsed = float(data.get("elapsed", elapsed))
	set_physics_process(false)
