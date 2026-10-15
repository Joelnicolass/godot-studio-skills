extends Node2D

## Spawn lab world. The server spawns the four actor kinds at known moments;
## a client prints which actors it has and whether their `tick` still grows.
## Batch names: b0 = before anyone joins, j<slot> = that peer is on the lobby,
## r<slot> = that peer is world-ready. ra/rb = actors of RoomA / RoomB.

const KINDS := {
	"S": preload("res://debug/spawn_lab/actor_synced.tscn"),
	"U": preload("res://debug/spawn_lab/actor_unsynced.tscn"),
	"L": preload("res://debug/spawn_lab/actor_late_sync.tscn"),
	"D": preload("res://debug/spawn_lab/actor_deferred_sync.tscn"),
}

var _room_ids: Dictionary = {}
## Server args: --lab-kinds=SULD (which actor kinds to spawn), --lab-static=1 (sync StaticProp).
var _kinds: String = "SULD"

@onready var _actors: Node2D = $Actors
@onready var _room_a: Node2D = $RoomA/Actors
@onready var _room_b: Node2D = $RoomB/Actors
@onready var _static: Node2D = $StaticProp


func _ready() -> void:
	if not MpKit.is_networked():
		return
	if not MpKit.is_server():
		_report_later()
		return
	_kinds = MpBoot.user_value("lab-kinds", "SULD")
	if MpBoot.user_value("lab-static", "1") != "1":
		$StaticProp/MultiplayerSynchronizer.queue_free()
	_room_ids["a"] = MpKit.rooms.create_room(4)
	_room_ids["b"] = MpKit.rooms.create_room(4)
	_room_bound($RoomA/MpSpawner, _room_ids["a"])
	_room_bound($RoomB/MpSpawner, _room_ids["b"])
	_spawn_batch(_actors, "b0", ["S", "U", "L", "D"])
	_spawn_batch(_room_a, "ra", ["S", "U"])
	_spawn_batch(_room_b, "rb", ["S", "U"])
	MpKit.peer_joined.connect(_on_peer_joined)
	MpKit.client_world_ready.connect(_on_world_ready)


func _exit_tree() -> void:
	if MpKit.is_server():
		for room_id in _room_ids.values():
			MpKit.rooms.close_room(room_id)


func _on_peer_joined(_peer_id: int, slot: int) -> void:
	_spawn_batch(_actors, "j%d" % slot, ["S", "U", "L"])


func _on_world_ready(peer_id: int) -> void:
	var slot := MpKit.slot_for_peer(peer_id)
	var room: StringName = _room_ids["a"] if slot % 2 == 1 else _room_ids["b"]
	MpKit.rooms.join_room(peer_id, room)
	print("LAB|server|seat slot=%d room=%s" % [slot, room])
	_spawn_batch(_actors, "r%d" % slot, ["S", "U", "L"])


## A room-aware spawner (if the addon has one) gets its room id here.
func _room_bound(spawner: Node, room_id: StringName) -> void:
	if "room_id" in spawner:
		spawner.set("room_id", room_id)


func _spawn_batch(parent: Node, tag: String, kinds: Array) -> void:
	var names: PackedStringArray = []
	for kind in kinds:
		if not _kinds.contains(kind):
			continue
		var actor: Node2D = (KINDS[kind] as PackedScene).instantiate()
		actor.name = "%s_%s" % [tag, kind]
		actor.position = Vector2(10, 10)
		parent.add_child(actor, true)
		names.append(actor.name)
	print("LAB|server|spawn %s" % " ".join(names))


func _report_later() -> void:
	# A Timer child dies with this world (rematch), so no await outlives it.
	var timer := Timer.new()
	add_child(timer)
	for step in [[3.0, "t3"], [2.0, "t5"], [4.0, "t9"]]:
		timer.start(step[0])
		await timer.timeout
		_report(step[1])


func _report(tag: String) -> void:
	var parts: PackedStringArray = []
	for root in [_actors, _room_a, _room_b]:
		for child in root.get_children():
			parts.append("%s:%d" % [child.name, int(child.get("tick"))])
	parts.append("static:%d" % _static.tick)
	var entries: int = get_node("/root/LabSession").entries
	if entries > 1:
		tag = "w%d%s" % [entries, tag]
	print("LAB|slot=%d|%s|%s" % [MpKit.local_slot(), tag, " ".join(parts)])
