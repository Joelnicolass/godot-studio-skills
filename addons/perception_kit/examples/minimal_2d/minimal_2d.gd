extends Node2D

## PerceptionKit's smallest example in 2D (F6): a guard turns toward what its sensor perceives.
## Arrows walk you; Space makes a noise where you are. The wall hides you; walk out of its view
## and it keeps facing where it saw you last until it forgets you.
##
## The guard has a PerceptionSensor2D (`show_in_game`); you have a PerceptionTarget2D. The whole
## game side is this script.

const SPEED := 220.0
## How far your noise is heard.
const NOISE_RADIUS_PX := 260.0
const TURN_DEG_S := 220.0

@onready var sensor: PerceptionSensor2D = $Guard/Sensor
@onready var guard: Node2D = $Guard
@onready var player: CharacterBody2D = $Player
@onready var label: Label = $Label

var _last := "Arrows walk, Space makes a noise."


func _ready() -> void:
	sensor.perceived.connect(func(stimulus: PerceptionStimulus) -> void: _last = "Perceived: %s" % stimulus.kind)
	sensor.forgotten.connect(func(_stimulus: PerceptionStimulus) -> void: _last = "Forgotten.")


func _physics_process(delta: float) -> void:
	player.velocity = Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down") * SPEED
	player.move_and_slide()
	var latest := sensor.latest()
	if latest != null:
		var aim := (latest.position_2d - guard.global_position).angle()
		guard.rotation = rotate_toward(guard.rotation, aim, deg_to_rad(TURN_DEG_S) * delta)
	var state := "sees you" if sensor.sees_any() else ("remembers" if sensor.is_aware() else "calm")
	label.text = "The guard %s. %s" % [state, _last]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept"):
		sensor.hear(player.global_position, NOISE_RADIUS_PX, player.get_instance_id())
