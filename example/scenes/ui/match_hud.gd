extends CanvasLayer

@export var match_node: DemoMatch

@onready var _status: Label = %Status
@onready var _tunnel: Label = %Tunnel
@onready var _leave: Button = %Leave


func _ready() -> void:
	if match_node == null:
		match_node = get_parent().get_node_or_null("DemoMatch") as DemoMatch
	_leave.text = DemoCopy.LEAVE
	_tunnel.text = DemoCopy.HUD_TUNNEL_EMPTY
	_leave.pressed.connect(_on_leave_pressed)
	MpKit.custom_received.connect(_on_custom)
	if MpKit.is_dedicated():
		_leave.visible = false


func _process(_delta: float) -> void:
	var mode := DemoCopy.HUD_MODE_1P
	if MpKit.is_dedicated():
		mode = DemoCopy.HUD_MODE_DEDICATED
	elif MpKit.is_listen_host():
		mode = DemoCopy.HUD_MODE_LISTEN
	elif MpKit.is_networked():
		mode = DemoCopy.HUD_MODE_CLIENT % MpKit.local_slot()
	var t := 0.0
	if match_node:
		t = match_node.elapsed
	_status.text = "%s | t=%.1f | slots=%s" % [mode, t, str(MpKit.occupied_slots())]


func _on_custom(channel: StringName, data: Dictionary, from_peer: int) -> void:
	_tunnel.text = "%s ← peer %d: %s" % [String(channel), from_peer, str(data)]


func _on_leave_pressed() -> void:
	NetGlue.return_to_boot()
