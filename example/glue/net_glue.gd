extends MpFlow

## Demo-only: emote tunnel reflect. Worlds live on MpFlow (`2d` / `3d`).

const CHANNEL_EMOTE := &"emote"
const WORLD_2D := "res://scenes/world/match_2d.tscn"
const WORLD_3D := "res://scenes/world/match_3d.tscn"

var world_kind: String:
	get:
		return String(world_id)
	set(value):
		select_world(StringName(value))


func _ready() -> void:
	boot_path = "res://scenes/ui/boot.tscn"
	add_world(&"2d", WORLD_2D)
	add_world(&"3d", WORLD_3D)
	max_players = 4
	room_name = "MpKit demo"
	advertise_lan = true
	custom_channels = PackedStringArray(["emote"])
	start_when = StartWhen.DEDICATED_FIRST_CLIENT
	host_fail_status = DemoCopy.STATUS_HOST_FAIL
	join_fail_status = DemoCopy.STATUS_JOIN_FAIL
	bad_ip_status = DemoCopy.STATUS_BAD_IP
	joining_status = DemoCopy.STATUS_JOINING
	server_lost_status = DemoCopy.STATUS_SERVER_LOST
	dedicated_status = DemoCopy.STATUS_DEDICATED
	super._ready()
	MpKit.custom_received.connect(_on_custom)


func _on_custom(channel: StringName, _data: Dictionary, from_peer: int) -> void:
	if channel != CHANNEL_EMOTE:
		return
	if MpKit.is_server() and from_peer != 1:
		MpKit.broadcast_custom(channel, _data)
