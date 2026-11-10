extends Node3D

## BotKit's smallest example: a robot (a Bot3D on Godot's character template) hunts you round the walls.
## Arrows: walk. F: draw what the robot thinks.

@onready var robot: CharacterBody3D = $Robot
@onready var you: CharacterBody3D = $You
@onready var label: Label = $Label

var hits := 0
var _tracer := ImmediateMesh.new()
var _tracer_left_s := 0.0


func _ready() -> void:
	robot.connect(&"shot", _on_shot)
	var line := MeshInstance3D.new()
	line.mesh = _tracer
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.9, 0.4)
	line.material_override = material
	add_child(line)


func _process(delta: float) -> void:
	_tracer_left_s -= delta
	if _tracer_left_s <= 0.0:
		_tracer.clear_surfaces()
	var bot := robot.get_node(^"Bot3D") as Bot3D
	label.text = "Arrows: walk   F: what it thinks\nThe robot %s. It hit you %d times." % [bot.mode, hits]


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F:
		var bot := robot.get_node(^"Bot3D") as Bot3D
		bot.show_in_game = not bot.show_in_game


func _on_shot(from: Vector3, to: Vector3, hit: Object) -> void:
	_tracer.clear_surfaces()
	_tracer.surface_begin(Mesh.PRIMITIVE_LINES)
	_tracer.surface_add_vertex(from)
	_tracer.surface_add_vertex(to)
	_tracer.surface_end()
	_tracer_left_s = 0.05
	if hit == you:
		hits += 1
