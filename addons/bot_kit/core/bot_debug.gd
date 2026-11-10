class_name BotDebug
extends Node3D

## What a Bot3D with `show_in_game` draws while the game runs: a line to its enemy (red while it may fire, orange
## while it aims), its path (blue), its goal (yellow) and, above its head, what it does and with which weapon. An
## internal child of the bot: never saved, gone when `show_in_game` is turned off.

const AIMING := Color(1.0, 0.6, 0.15)
const FIRING := Color(1.0, 0.2, 0.15)
const PATH := Color(0.3, 0.7, 1.0)
const GOAL := Color(1.0, 0.85, 0.2)

var _lines: MeshInstance3D
var _mesh := ImmediateMesh.new()
var _label: Label3D


func _ready() -> void:
	top_level = true
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	_lines = MeshInstance3D.new()
	_lines.mesh = _mesh
	_lines.material_override = material
	_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_lines)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.pixel_size = 0.006
	_label.outline_size = 6
	add_child(_label)


## Draws `bot` as it is now.
func show_bot(bot: Bot3D, firing: bool) -> void:
	global_transform = Transform3D.IDENTITY
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var eye := bot.eye_position()
	if bot.target != null:
		_line(eye, bot.target.global_position + Vector3.UP * bot.aim_height_m, FIRING if firing else AIMING)
	var path := bot.path_points()
	for i in range(1, path.size()):
		_line(path[i - 1] + Vector3.UP * 0.1, path[i] + Vector3.UP * 0.1, PATH)
	if bot.goal != Vector3.INF:
		for axis: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
			_line(bot.goal - axis * 0.4 + Vector3.UP * 0.1, bot.goal + axis * 0.4 + Vector3.UP * 0.1, GOAL)
		_line(bot.goal, bot.goal + Vector3.UP * 1.2, GOAL)
	# ImmediateMesh refuses an empty surface.
	_line(eye, eye, AIMING)
	_mesh.surface_end()
	_label.global_position = eye + Vector3.UP * 0.6
	var weapon := String(bot.weapon.name) if bot.weapon != null and not bot.weapon.name.is_empty() else ""
	_label.text = String(bot.mode) + (" · " + weapon if not weapon.is_empty() else "")


func _line(a: Vector3, b: Vector3, color: Color) -> void:
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(a)
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(b)
