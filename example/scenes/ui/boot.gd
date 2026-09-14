extends Control

@onready var _title: Label = %Title
@onready var _play: Button = %PlaySolo
@onready var _host: Button = %HostLan
@onready var _join: Button = %Join
@onready var _ip: LineEdit = %Ip
@onready var _status: Label = %Status
@onready var _lan: Label = %LanIp
@onready var _btn_2d: Button = %World2D
@onready var _btn_3d: Button = %World3D


func _ready() -> void:
	_title.text = DemoCopy.TITLE
	_play.text = DemoCopy.PLAY_SOLO
	_host.text = DemoCopy.HOST_LAN
	_join.text = DemoCopy.JOIN
	_btn_2d.text = DemoCopy.WORLD_2D
	_btn_3d.text = DemoCopy.WORLD_3D
	_ip.placeholder_text = DemoCopy.IP_HINT
	_ip.text = DemoCopy.IP_HINT
	var lan := MpLan.get_local_ipv4()
	_lan.text = DemoCopy.LAN_IP % (lan if not lan.is_empty() else "—")
	_play.pressed.connect(NetGlue.play_solo)
	_host.pressed.connect(NetGlue.host_lan)
	_join.pressed.connect(func() -> void: NetGlue.join_lan(_ip.text))
	_btn_2d.pressed.connect(func() -> void: _set_world("2d"))
	_btn_3d.pressed.connect(func() -> void: _set_world("3d"))
	NetGlue.status_changed.connect(_on_status)
	_on_status(DemoCopy.STATUS_IDLE)
	_set_world(NetGlue.world_kind)
	if MpBoot.is_dedicated_process():
		visible = false


func _set_world(kind: String) -> void:
	NetGlue.world_kind = kind
	_btn_2d.disabled = kind == "2d"
	_btn_3d.disabled = kind == "3d"


func _on_status(text: String) -> void:
	_status.text = text
