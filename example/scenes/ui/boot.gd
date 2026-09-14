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
@onready var _rooms_header: Label = %RoomsHeader
@onready var _rooms: ItemList = %Rooms

var _room_rows: Array[Dictionary] = []


func _ready() -> void:
	_title.text = DemoCopy.TITLE
	_play.text = DemoCopy.PLAY_SOLO
	_host.text = DemoCopy.HOST_LAN
	_join.text = DemoCopy.JOIN
	_btn_2d.text = DemoCopy.WORLD_2D
	_btn_3d.text = DemoCopy.WORLD_3D
	_rooms_header.text = DemoCopy.ROOMS_HEADER
	_ip.placeholder_text = DemoCopy.IP_HINT
	_ip.text = DemoCopy.IP_HINT
	var lan := MpLan.get_local_ipv4()
	_lan.text = DemoCopy.LAN_IP % (lan if not lan.is_empty() else "—")
	_play.pressed.connect(NetGlue.play_solo)
	_host.pressed.connect(NetGlue.host_lan)
	_join.pressed.connect(func() -> void: NetGlue.join_lan(_ip.text))
	_btn_2d.pressed.connect(func() -> void: _set_world("2d"))
	_btn_3d.pressed.connect(func() -> void: _set_world("3d"))
	_rooms.item_selected.connect(_on_room_selected)
	NetGlue.status_changed.connect(_on_status)
	_on_status(DemoCopy.STATUS_IDLE)
	_set_world(String(NetGlue.world_id))
	var beacon := MpLan.browse(self)
	beacon.rooms_changed.connect(_on_rooms)
	if MpBoot.is_dedicated_process():
		visible = false


func _set_world(kind: String) -> void:
	NetGlue.select_world(StringName(kind))
	_btn_2d.disabled = kind == "2d"
	_btn_3d.disabled = kind == "3d"


func _on_status(text: String) -> void:
	_status.text = text


func _on_rooms(found: Array) -> void:
	_room_rows.clear()
	_rooms.clear()
	for item in found:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item
		_room_rows.append(row)
		_rooms.add_item("%s  %s:%d  (%d/%d)" % [
			str(row.get("name", "MpKit")),
			str(row.get("address", "")),
			int(row.get("port", 0)),
			int(row.get("players", 0)),
			int(row.get("max_players", 0)),
		])


func _on_room_selected(index: int) -> void:
	if index < 0 or index >= _room_rows.size():
		return
	_ip.text = str(_room_rows[index].get("address", ""))
