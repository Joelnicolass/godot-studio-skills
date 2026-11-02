extends Node3D

## PerceptionKit's fuller example (F5 in the lab): two guards in a yard, and you.
## - Arrows walk you. Space makes a noise: every guard within 12 m hears it and goes to look.
## - L lights your lamp: a PerceptionTarget3D of kind &"light" that the guards see from 2.5 times
##   farther (their `reach_by_kind`).
## - N makes it night: the guards' `sight_scale` drops to 0.5.
## - The dark patch is shade: in it your target's `visibility` drops to 0.3.
## Each guard is guard.gd: watch, look at you, search where it saw or heard you, walk back home.

const SPEED := 5.0
## How far your noise is heard.
const NOISE_RADIUS_M := 12.0
## Your target's visibility in the shade.
const SHADE_VISIBILITY := 0.3

@export var guards: Array[CharacterBody3D] = []

@onready var player: CharacterBody3D = $Player
@onready var target: PerceptionTarget3D = $Player/Target
@onready var lamp: PerceptionTarget3D = $Player/Lamp
@onready var lamp_light: OmniLight3D = $Player/Lamp/Light
@onready var shade: Area3D = $Shade
@onready var label: Label = $Label

var night := false


func _ready() -> void:
	set_lamp(false)


func _physics_process(_delta: float) -> void:
	var walk := Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	player.velocity = Vector3(walk.x, 0.0, walk.y) * SPEED
	player.move_and_slide()
	target.visibility = SHADE_VISIBILITY if shade.overlaps_body(player) else 1.0
	var lines := PackedStringArray()
	for guard in guards:
		lines.append("%s: %s" % [guard.name, guard.call(&"state_name")])
	label.text = "Arrows walk · Space noise · L lamp (%s) · N night (%s) · in the shade: %s\n%s" % [
		"on" if lamp.enabled else "off", "on" if night else "off", "yes" if target.visibility < 1.0 else "no",
		"   ".join(lines)
	]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept"):
		make_noise(player.global_position)
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_L:
		set_lamp(not lamp.enabled)
	elif key.physical_keycode == KEY_N:
		set_night(not night)


## A noise at `at`: every guard's sensor decides whether it hears it.
func make_noise(at: Vector3) -> void:
	for guard in guards:
		_sensor_of(guard).hear(at, NOISE_RADIUS_M, player.get_instance_id())


func set_lamp(on: bool) -> void:
	lamp.enabled = on
	lamp_light.visible = on


func set_night(on: bool) -> void:
	night = on
	for guard in guards:
		_sensor_of(guard).sight_scale = 0.5 if on else 1.0


func _sensor_of(guard: Node) -> PerceptionSensor3D:
	return guard.get(&"sensor") as PerceptionSensor3D
