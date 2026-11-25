extends MpFlow

## Demo-only: emote tunnel reflect. Worlds live on MpFlow (`2d` / `3d`).
## Registered as autoloads/net_session.tscn: the numbers of the session (players, room, channels) are in its inspector.

const CHANNEL_EMOTE := &"emote"

## Scene of the 2D world.
@export_file("*.tscn") var world_2d_path: String = ""
## Scene of the 3D world.
@export_file("*.tscn") var world_3d_path: String = ""


func _ready() -> void:
	add_world(&"2d", world_2d_path)
	add_world(&"3d", world_3d_path)
	host_fail_status = tr("STATUS_HOST_FAIL")
	join_fail_status = tr("STATUS_JOIN_FAIL")
	bad_ip_status = tr("STATUS_BAD_IP")
	joining_status = tr("STATUS_JOINING")
	server_lost_status = tr("STATUS_SERVER_LOST")
	dedicated_status = tr("STATUS_DEDICATED")
	super._ready()
	MpKit.custom_received.connect(_on_custom)


func _on_custom(channel: StringName, _data: Dictionary, from_peer: int) -> void:
	if channel != CHANNEL_EMOTE:
		return
	if MpKit.is_server() and from_peer != 1:
		MpKit.broadcast_custom(channel, _data)
