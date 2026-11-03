extends Node3D

## SpillKit's smallest example (F6): a dummy that bleeds. Click it: a hit of 20 % of its HP (the
## drops fly away from you; two clicks closer than every_s spray once). Right click: a hit of 50 %,
## heavy. K: it dies, a puddle grows under it. R: a new round.
##
## The dummy has a SpillSource3D at its chest with the blood type; the level has a SpillPool3D. The
## whole game side is this script.

const MAX_HP := 100.0
const HIT := 20.0
const HEAVY_HIT := 50.0

@onready var spill: SpillSource3D = $Dummy/Spill
@onready var camera: Camera3D = $Camera3D
@onready var label: Label = $Label

var hp := MAX_HP


func _ready() -> void:
	_show()


## A hit of [param damage] (the HP the game takes off): the source decides if it spills, and how much.
func strike(damage: float) -> void:
	if hp <= 0.0:
		return
	hp = maxf(hp - damage, 0.0)
	spill.hit(damage, MAX_HP, camera.global_position)
	if hp <= 0.0:
		spill.die()
	_show()


## A new round: full HP and a clean floor.
func reset() -> void:
	hp = MAX_HP
	spill.current_pool().clear()
	_show()


func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed:
		strike(HEAVY_HIT if click.button_index == MOUSE_BUTTON_RIGHT else HIT)
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.keycode:
			KEY_K:
				strike(hp)
			KEY_R:
				reset()


func _show() -> void:
	label.text = "HP %d. Click: hit (right click: heavy). K: die. R: new round." % hp
