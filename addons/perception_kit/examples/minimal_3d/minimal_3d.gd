extends Node3D

## PerceptionKit's smallest example (F6): a guard turns its head toward what its sensor perceives.
## Arrows walk you; Space makes a noise where you are. Behind the wall it does not see you; walk
## out of its view and it keeps looking at where it saw you last until it forgets you.
##
## The guard's head has a PerceptionSensor3D (`show_in_game`: grey, amber, red); you have a
## PerceptionTarget3D at your chest. The whole game side is this script.

const SPEED := 5.0
## How far your noise is heard.
const NOISE_RADIUS_M := 12.0
const TURN_DEG_S := 220.0

@onready var sensor: PerceptionSensor3D = $Guard/Head/Sensor
@onready var head: Node3D = $Guard/Head
@onready var player: CharacterBody3D = $Player
@onready var label: Label = $Label

var _last := "Arrows walk, Space makes a noise."


func _ready() -> void:
	sensor.perceived.connect(func(stimulus: PerceptionStimulus) -> void: _last = "Perceived: %s" % stimulus.kind)
	sensor.forgotten.connect(func(_stimulus: PerceptionStimulus) -> void: _last = "Forgotten.")


func _physics_process(delta: float) -> void:
	var walk := Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	player.velocity = Vector3(walk.x, 0.0, walk.y) * SPEED
	player.move_and_slide()
	# The head turns toward the youngest thing it remembers.
	var latest := sensor.latest()
	if latest != null:
		var to := latest.position - head.global_position
		var yaw := atan2(-to.x, -to.z)
		head.rotation.y = rotate_toward(head.rotation.y, yaw, deg_to_rad(TURN_DEG_S) * delta)
	var state := "sees you" if sensor.sees_any() else ("remembers" if sensor.is_aware() else "calm")
	label.text = "The guard %s. %s" % [state, _last]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept"):
		sensor.hear(player.global_position, NOISE_RADIUS_M, player.get_instance_id())
