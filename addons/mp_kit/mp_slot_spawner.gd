class_name MpSlotSpawner
extends MpSpawner

## Optional: one packed pawn per occupied slot. Genre-neutral plumbing.
## Dedicated never spawns slot 0. Listen host spawns local slot in _ready.
## Joiners spawn on client_world_ready; peers already world-ready when this spawner enters spawn in _ready.
## Identity: node name Pawn_<slot>
## and `player_slot` if the actor exposes it.
## A pawn your game frees (MpActor.despawn: it died) is forgotten: pawn_for gives null and spawn_slot makes a new one, which
## keeps the name Pawn_<slot> even in the frame the old one leaves.

@export var pawn_scene: PackedScene
@export var spawn_points: NodePath
@export var actor_name_prefix: String = "Pawn_"
@export var despawn_on_leave: bool = true

var _pawns: Dictionary = {}


func _ready() -> void:
	if pawn_scene != null and not pawn_scene.resource_path.is_empty():
		if extra_scenes.find(pawn_scene) < 0:
			extra_scenes.append(pawn_scene)
	super._ready()
	if pawn_scene == null:
		push_warning("MpSlotSpawner '%s': assign pawn_scene" % name)
		return
	if not MpKit.is_networked():
		spawn_slot(MpKit.local_slot())
		return
	if not MpKit.is_server():
		return
	MpKit.client_world_ready.connect(_on_slot_world_ready)
	if despawn_on_leave:
		MpKit.peer_left.connect(_on_slot_peer_left)
	if MpKit.is_listen_host():
		spawn_slot(MpKit.local_slot())
	## Peers whose world was ready before this spawner entered (a spawner in a scene loaded later, a world loaded again):
	## client_world_ready already fired for them.
	for peer_id in multiplayer.get_peers():
		if MpKit.is_peer_world_ready(peer_id):
			spawn_slot(MpKit.slot_for_peer(peer_id))


func _exit_tree() -> void:
	## A pawn still waiting for its slot's last one to leave never enters now.
	for slot in _pawns.keys():
		var pawn: Variant = _pawns[slot]
		if is_instance_valid(pawn) and not (pawn as Node).is_inside_tree():
			_pawns.erase(slot)
			(pawn as Node).free()
	if MpKit.client_world_ready.is_connected(_on_slot_world_ready):
		MpKit.client_world_ready.disconnect(_on_slot_world_ready)
	if MpKit.peer_left.is_connected(_on_slot_peer_left):
		MpKit.peer_left.disconnect(_on_slot_peer_left)
	super._exit_tree()


func spawn_occupied() -> void:
	for slot in MpKit.occupied_slots():
		spawn_slot(slot)


## The pawn of `slot`: the one it has, or a new one under spawn_path. One that was freed or is being freed (MpActor.despawn)
## counts as none. A new pawn whose slot's last one is still leaving this frame enters right after it (from the next frame),
## so its name is Pawn_<slot> here and on every peer.
func spawn_slot(slot: int) -> Node:
	if slot <= 0:
		return null
	var known := pawn_for(slot)
	if known:
		return known
	if pawn_scene == null or _root == null:
		return null
	var pawn := pawn_scene.instantiate()
	pawn.name = "%s%d" % [actor_name_prefix, slot]
	if "player_slot" in pawn:
		pawn.player_slot = slot
	var net := MpActor.of(pawn)
	if net:
		net.owner_slot = slot
	_place(pawn, slot)
	_pawns[slot] = pawn
	var leaving := _root.get_node_or_null(NodePath(String(pawn.name)))
	if leaving != null and leaving.is_queued_for_deletion():
		leaving.tree_exited.connect(_enter_later.bind(slot, pawn.get_instance_id()), CONNECT_ONE_SHOT | CONNECT_DEFERRED)
	else:
		_root.add_child(pawn, true)
	return pawn


## The pawn of `slot`, or null: none yet, or the one it had was freed or is being freed (MpActor.despawn).
func pawn_for(slot: int) -> Node:
	var pawn: Variant = _pawns.get(slot)
	if is_instance_valid(pawn) and not (pawn as Node).is_queued_for_deletion():
		return pawn
	_pawns.erase(slot)
	return null


## The slot's last pawn is out of the tree: the new one goes in, under the same name.
func _enter_later(slot: int, pawn_id: int) -> void:
	var pawn := instance_from_id(pawn_id) as Node
	if pawn == null or pawn.is_inside_tree() or pawn.is_queued_for_deletion():
		return
	if not is_instance_valid(_root) or not _root.is_inside_tree() or _pawns.get(slot) != pawn:
		if _pawns.get(slot) == pawn:
			_pawns.erase(slot)
		pawn.free()
		return
	_root.add_child(pawn, true)


func _place(pawn: Node, slot: int) -> void:
	var points := _spawn_points_node()
	if points == null:
		return
	var markers := points.get_children()
	if markers.is_empty():
		return
	var marker: Node = markers[(slot - 1) % markers.size()]
	if pawn is Node2D and marker is Node2D and _root is Node2D:
		(pawn as Node2D).position = (_root as Node2D).to_local((marker as Node2D).global_position)
	elif pawn is Node3D and marker is Node3D and _root is Node3D:
		(pawn as Node3D).position = (_root as Node3D).to_local((marker as Node3D).global_position)


func _spawn_points_node() -> Node:
	if not spawn_points.is_empty():
		var node := get_node_or_null(spawn_points)
		if node:
			return node
	var parent := get_parent()
	if parent:
		return parent.get_node_or_null("SpawnPoints")
	return null


func _on_slot_world_ready(peer_id: int) -> void:
	if not MpKit.is_server():
		return
	spawn_slot(MpKit.slot_for_peer(peer_id))


func _on_slot_peer_left(_peer_id: int, slot: int) -> void:
	var pawn := pawn_for(slot)
	_pawns.erase(slot)
	if pawn:
		pawn.queue_free()
