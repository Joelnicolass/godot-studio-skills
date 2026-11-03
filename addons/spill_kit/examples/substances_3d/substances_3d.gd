extends Node3D

## Six substances side by side (F5 in the lab), one type each, the same source on every dummy:
## - blood: a type with only its colour, the kit's own wet look;
## - oil: black and glossy, a big slow puddle;
## - slime: green, translucent and soft-edged, by a curb (its puddle shrinks to stay off it);
## - mercury: a metal, on a slope (its puddle lies along it);
## - paint: a PBR type of its own, with albedo, normal and ORM textures;
## - ink: the game's own shader (a flat, banded look), as a game puts its PS1 material.
##
## Click a dummy, or 1 to 6: hit it (right click: a heavy hit). Space: hit them all. K: they all die.
## R: a new round. L: a lamp from the camera. N: night. Left and right: turn around them.

const MAX_HP := 100.0
const HIT := 20.0
const HEAVY_HIT := 50.0
const TURN_DEG_S := 60.0
const BODIES_LAYER := 2
const CLICK_REACH_M := 50.0

## The dummies' sources, in the order of the keys 1 to 6.
@export var spills: Array[SpillSource3D] = []
@export var pivot: Node3D
@export var camera: Camera3D
@export var lamp: SpotLight3D
@export var sun: DirectionalLight3D
@export var environment: WorldEnvironment
@export var label: Label

var _hp: Array[float] = []
var _night := false


func _ready() -> void:
	reset()
	_show()


func _process(delta: float) -> void:
	var turn := Input.get_axis(&"ui_left", &"ui_right")
	pivot.rotate_y(-turn * deg_to_rad(TURN_DEG_S) * delta)


## A hit of [param damage] on dummy [param index]: the drops fly away from the camera.
func strike(index: int, damage: float) -> void:
	if _hp[index] <= 0.0:
		return
	_hp[index] = maxf(_hp[index] - damage, 0.0)
	spills[index].hit(damage, MAX_HP, camera.global_position)
	if _hp[index] <= 0.0:
		spills[index].die()


func strike_all(damage: float) -> void:
	for i in spills.size():
		strike(i, damage)


func kill_all() -> void:
	for i in spills.size():
		strike(i, _hp[i])


## A new round: full HP and a clean floor.
func reset() -> void:
	_hp.resize(spills.size())
	_hp.fill(MAX_HP)
	if not spills.is_empty():
		spills[0].current_pool().clear()


func set_lamp(on: bool) -> void:
	lamp.visible = on
	_show()


func set_night(on: bool) -> void:
	_night = on
	sun.light_energy = 0.05 if on else 1.0
	environment.environment.ambient_light_energy = 0.08 if on else 0.4
	environment.environment.background_energy_multiplier = 0.05 if on else 1.0
	_show()


func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		var index := _dummy_at(click.position)
		if index >= 0:
			strike(index, HEAVY_HIT if click.button_index == MOUSE_BUTTON_RIGHT else HIT)
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode >= KEY_1 and key.keycode < KEY_1 + spills.size():
		strike(key.keycode - KEY_1, HEAVY_HIT if key.shift_pressed else HIT)
	match key.keycode:
		KEY_SPACE:
			strike_all(HIT)
		KEY_K:
			kill_all()
		KEY_R:
			reset()
		KEY_L:
			set_lamp(not lamp.visible)
		KEY_N:
			set_night(not _night)
	_show()


# The dummy under the mouse (-1: none).
func _dummy_at(screen: Vector2) -> int:
	var from := camera.project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(from, from + camera.project_ray_normal(screen) * CLICK_REACH_M, 1 << (BODIES_LAYER - 1))
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return -1
	for i in spills.size():
		if spills[i].get_parent() == hit["collider"]:
			return i
	return -1


func _show() -> void:
	label.text = "Click a dummy or 1-6: hit (right click or Shift: heavy). Space: all. K: all die. R: new round. L: lamp %s. N: %s. Left / right: turn." % [
		"on" if lamp.visible else "off", "night" if _night else "day"]
