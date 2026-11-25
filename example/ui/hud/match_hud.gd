@tool
extends CanvasLayer

## Required: the match whose clock the HUD shows.
@export var match_node: DemoMatch

@onready var _status: Label = %Status
@onready var _tunnel: Label = %Tunnel
@onready var _leave: Button = %Leave


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if match_node == null:
		push_error("MatchHUD '%s': assign match_node." % name)
	_leave.pressed.connect(_on_leave_pressed)
	MpKit.custom_received.connect(_on_custom)
	if MpKit.is_dedicated():
		_leave.visible = false


func _get_configuration_warnings() -> PackedStringArray:
	if match_node == null:
		return PackedStringArray(["Assign match_node (the DemoMatch of this level)."])
	return PackedStringArray()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var mode := tr("HUD_MODE_1P")
	if MpKit.is_dedicated():
		mode = tr("HUD_MODE_DEDICATED")
	elif MpKit.is_listen_host():
		mode = tr("HUD_MODE_LISTEN")
	elif MpKit.is_networked():
		mode = tr("HUD_MODE_CLIENT") % MpKit.local_slot()
	var t := 0.0
	if match_node:
		t = match_node.elapsed
	_status.text = tr("HUD_STATUS") % [mode, t, str(MpKit.occupied_slots())]


func _on_custom(channel: StringName, data: Dictionary, from_peer: int) -> void:
	_tunnel.text = tr("HUD_TUNNEL_MSG") % [String(channel), from_peer, str(data)]


func _on_leave_pressed() -> void:
	NetSession.return_to_boot()
