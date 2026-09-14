extends Node

## Flow + lobby policy. No scores. MpKit stays a transport.

const CHANNEL_EMOTE := &"emote"
const BOOT_SCENE := "res://scenes/ui/boot.tscn"
const WORLD_2D := "res://scenes/world/match_2d.tscn"
const WORLD_3D := "res://scenes/world/match_3d.tscn"
const MAX_PLAYERS := 4

signal status_changed(text: String)

var world_kind: String = "2d"
var match_running: bool = false
var _lan_beacon: MpLanBeacon


func _ready() -> void:
	var port := int(MpBoot.user_value("mp-port", "7777"))
	MpKit.configure(port, MAX_PLAYERS, 1, PackedStringArray(["emote"]))
	MpKit.load_world.connect(goto_world)
	MpKit.peer_joined.connect(_on_peer_joined)
	MpKit.join_failed.connect(_on_join_failed)
	MpKit.server_lost.connect(_on_server_lost)
	MpKit.custom_received.connect(_on_custom)
	MpKit.snapshot_received.connect(_on_snapshot)
	var kind := MpBoot.user_value("world", "")
	if kind == "2d" or kind == "3d":
		world_kind = kind
	if MpBoot.is_dedicated_process():
		var err := MpKit.host_dedicated()
		if err != OK:
			push_error("MpKit.host_dedicated failed: %s" % err)
			get_tree().quit(1)
			return
		status_changed.emit(DemoCopy.STATUS_DEDICATED % MpKit.port)


func play_solo() -> void:
	_stop_lan()
	MpKit.leave()
	match_running = true
	goto_world()


func host_lan() -> void:
	var err := MpKit.host()
	if err != OK:
		status_changed.emit(DemoCopy.STATUS_HOST_FAIL)
		return
	match_running = true
	MpKit.broadcast_load_world()
	_stop_lan()
	_lan_beacon = MpLan.advertise(self, "MpKit demo")
	goto_world()


func join_lan(ip: String) -> void:
	var trimmed := ip.strip_edges()
	if not MpLan.is_valid_ipv4(trimmed):
		status_changed.emit(DemoCopy.STATUS_BAD_IP)
		return
	var err := MpKit.join(trimmed)
	if err != OK:
		status_changed.emit(DemoCopy.STATUS_JOIN_FAIL)
		return
	status_changed.emit(DemoCopy.STATUS_JOINING % trimmed)


func goto_world() -> void:
	var path := WORLD_2D if world_kind != "3d" else WORLD_3D
	get_tree().change_scene_to_file(path)


func return_to_boot() -> void:
	match_running = false
	_stop_lan()
	MpKit.leave()
	get_tree().change_scene_to_file(BOOT_SCENE)


func _on_peer_joined(peer_id: int, _slot: int) -> void:
	if match_running:
		MpKit.push_snapshot_to(peer_id, {"world_kind": world_kind})
		MpKit.load_world_to(peer_id)
		return
	if MpKit.is_dedicated():
		match_running = true
		MpKit.broadcast_load_world()
		goto_world()


func _on_snapshot(data: Dictionary) -> void:
	var kind := str(data.get("world_kind", ""))
	if kind == "2d" or kind == "3d":
		world_kind = kind


func _on_join_failed() -> void:
	match_running = false
	status_changed.emit(DemoCopy.STATUS_JOIN_FAIL)


func _on_server_lost() -> void:
	match_running = false
	_stop_lan()
	status_changed.emit(DemoCopy.STATUS_SERVER_LOST)
	get_tree().change_scene_to_file(BOOT_SCENE)


func _on_custom(channel: StringName, _data: Dictionary, from_peer: int) -> void:
	if channel != CHANNEL_EMOTE:
		return
	if MpKit.is_server() and from_peer != 1:
		MpKit.broadcast_custom(channel, _data)


func _stop_lan() -> void:
	if _lan_beacon == null:
		return
	if is_instance_valid(_lan_beacon):
		_lan_beacon.stop()
		_lan_beacon.queue_free()
	_lan_beacon = null
