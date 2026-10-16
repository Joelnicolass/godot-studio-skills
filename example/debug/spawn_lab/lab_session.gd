extends Node

## Lives under /root for the whole run. Server: dedicated, sends load_world on join.
## Client: joins, waits on the "lobby" for lab-lobby-ms after load_world, then loads the world.
## Args (after --): --lab-role=server|client --lab-lobby-ms=1500 --lab-leave-ms=0 --lab-quit-ms=12000
## Server only: --lab-unseat-ms=N (slot 1 leaves its room), --lab-rematch-ms=N (reload the world for everyone).

const WORLD := "res://debug/spawn_lab/lab_world.tscn"

var _lobby_ms: int = 1500
## How many times this process entered the lab world (report tags: t3, w2t3, …).
var entries: int = 0


func _ready() -> void:
	var role := MpBoot.user_value("lab-role", "server")
	_lobby_ms = int(MpBoot.user_value("lab-lobby-ms", "1500"))
	var quit_ms := int(MpBoot.user_value("lab-quit-ms", "12000"))
	var leave_ms := int(MpBoot.user_value("lab-leave-ms", "0"))
	get_tree().create_timer(quit_ms / 1000.0).timeout.connect(get_tree().quit)
	if leave_ms > 0:
		get_tree().create_timer(leave_ms / 1000.0).timeout.connect(_leave)
	if role == "server":
		var err := MpKit.host_dedicated()
		print("LAB|server|host err=%d port=%d" % [err, MpKit.port])
		MpKit.peer_joined.connect(_on_peer_joined)
		MpKit.peer_left.connect(_on_peer_left)
		_after(int(MpBoot.user_value("lab-unseat-ms", "0")), _unseat_slot_1)
		_after(int(MpBoot.user_value("lab-rematch-ms", "0")), _rematch)
		_enter_world()
		return
	MpKit.load_world.connect(_on_load_world)
	MpKit.join_failed.connect(func() -> void: print("LAB|client|join_failed"))
	multiplayer.connected_to_server.connect(func() -> void: print("LAB|client|connected"))
	var err := MpKit.join("127.0.0.1")
	print("LAB|client|join err=%d port=%d" % [err, MpKit.port])


func _on_peer_joined(peer_id: int, slot: int) -> void:
	print("LAB|server|joined peer=%d slot=%d" % [peer_id, slot])
	MpKit.load_world_to(peer_id)


func _on_peer_left(peer_id: int, slot: int) -> void:
	print("LAB|server|left peer=%d slot=%d" % [peer_id, slot])


func _on_load_world() -> void:
	print("LAB|slot=%d|load_world (lobby %d ms)" % [MpKit.local_slot(), _lobby_ms])
	await get_tree().create_timer(_lobby_ms / 1000.0).timeout
	print("LAB|slot=%d|enter world" % MpKit.local_slot())
	_enter_world()


func _enter_world() -> void:
	entries += 1
	get_tree().change_scene_to_file(WORLD)


func _after(ms: int, callback: Callable) -> void:
	if ms > 0:
		get_tree().create_timer(ms / 1000.0).timeout.connect(callback)


func _unseat_slot_1() -> void:
	var peer_id := MpKit.peer_id_for(1)
	print("LAB|server|unseat slot=1 peer=%d" % peer_id)
	MpKit.rooms.leave_room(peer_id)


func _rematch() -> void:
	print("LAB|server|rematch")
	MpKit.broadcast_load_world()
	_enter_world()


func _leave() -> void:
	print("LAB|slot=%d|leave" % MpKit.local_slot())
	MpKit.leave()
