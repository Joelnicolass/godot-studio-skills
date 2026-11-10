extends Node3D

## Four bots fight in an arena. Each is a Bot3D on a fighter (fighter.gd) with two BotWeapons: a rifle, and grenades it
## lobs over cover from 6 to 16 m. They walk to health when hurt and to grenades when short (BotGoal3D on the
## pickups), flee to health below 35 (a BotMode of the game, flee.gd), and chase where they last saw an enemy.
## Keys: 1, 2, 3: easy, normal, hard. F: draw what each one thinks. Left and right: turn round the arena.

const DIFFICULTIES: Array[BotDifficulty] = [
	preload("res://addons/bot_kit/presets/easy.tres"),
	preload("res://addons/bot_kit/presets/normal.tres"),
	preload("res://addons/bot_kit/presets/hard.tres"),
]
const TURN_DEG_S := 60.0

@onready var label: Label = $Label
@onready var pivot: Node3D = $CameraPivot

var _difficulty := 1
var _shown := false
var _fx := ImmediateMesh.new()
## [from, to, seconds left, color]
var _lines: Array[Array] = []


func _ready() -> void:
	var drawn := MeshInstance3D.new()
	drawn.mesh = _fx
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	drawn.material_override = material
	add_child(drawn)
	for fighter in fighters():
		fighter.connect(&"died", _on_died)
	_set_difficulty(_difficulty)


func fighters() -> Array[Node]:
	return get_tree().get_nodes_in_group(&"arena_fighter")


## A rifle shot (fighter.gd calls it).
func tracer(from: Vector3, to: Vector3) -> void:
	_lines.append([from, to, 0.05, Color(1.0, 0.9, 0.5)])


## A grenade burst (grenade.gd calls it).
func burst(at: Vector3) -> void:
	for i in 12:
		var a := TAU * i / 12.0
		_lines.append([at, at + Vector3(cos(a), 0.4, sin(a)) * 3.0, 0.3, Color(1.0, 0.5, 0.1)])


func _process(delta: float) -> void:
	if Input.is_action_pressed(&"ui_left"):
		pivot.rotate_y(deg_to_rad(TURN_DEG_S) * delta)
	if Input.is_action_pressed(&"ui_right"):
		pivot.rotate_y(-deg_to_rad(TURN_DEG_S) * delta)
	_fx.clear_surfaces()
	var alive: Array[Array] = []
	for line in _lines:
		line[2] = float(line[2]) - delta
		if float(line[2]) > 0.0:
			alive.append(line)
	_lines = alive
	if not _lines.is_empty():
		_fx.surface_begin(Mesh.PRIMITIVE_LINES)
		for line in _lines:
			_fx.surface_set_color(line[3])
			_fx.surface_add_vertex(line[0])
			_fx.surface_set_color(line[3])
			_fx.surface_add_vertex(line[1])
		_fx.surface_end()
	var text := "1 2 3: easy, normal, hard (now %s)   F: what they think   Left, right: turn\n" % DIFFICULTIES[_difficulty].display_name
	for fighter in fighters():
		var bot := fighter.get_node(^"Bot3D") as Bot3D
		text += "\n%-7s health %3d  grenades %d  kills %d  %s" % [
			fighter.name, int(fighter.get(&"health")), int(fighter.get(&"grenades")), int(fighter.get(&"kills")),
			"dead" if fighter.get(&"dead") else "%s, %s" % [bot.mode, fighter.get(&"weapon_name")],
		]
	label.text = text


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1, KEY_2, KEY_3:
			_set_difficulty(key.keycode - KEY_1)
		KEY_F:
			_shown = not _shown
			for fighter in fighters():
				(fighter.get_node(^"Bot3D") as Bot3D).show_in_game = _shown


func _set_difficulty(index: int) -> void:
	_difficulty = index
	for fighter in fighters():
		(fighter.get_node(^"Bot3D") as Bot3D).difficulty = DIFFICULTIES[index]


func _on_died(_fighter: Node, by: Node) -> void:
	if by != null and by != _fighter and by.get(&"kills") != null:
		by.set(&"kills", int(by.get(&"kills")) + 1)
