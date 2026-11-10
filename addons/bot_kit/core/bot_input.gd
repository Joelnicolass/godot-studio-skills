class_name BotInput
extends RefCounted

## The keys a Bot3D presses, read like Godot's `Input`: your character reads `bot.input` where a person's reads
## `Input`, with the same method names (is_action_pressed, get_action_strength, get_axis, get_vector,
## is_action_just_pressed, is_action_just_released). Each action has a strength from 0 to 1. Values carry the rest:
## where the bot looks (`get_value(&"yaw")`, `get_value(&"pitch")`, in radians).
## Signals, for a game that sends the keys somewhere else (a network input): `pressed` on a press and on a change of
## strength, `released`, `value_changed`. Each fires only when something changed.
## "Just pressed" lasts the physics frame of the press: the bot presses before your character's _physics_process.

signal pressed(action: StringName, strength: float)
signal released(action: StringName)
signal value_changed(name: StringName, value: Variant)

var _strength: Dictionary[StringName, float] = {}
var _pressed_frame: Dictionary[StringName, int] = {}
var _released_frame: Dictionary[StringName, int] = {}
var _values: Dictionary[StringName, Variant] = {}


## Holds `action` down at `strength` (0 to 1; 0 lets it go).
func press(action: StringName, strength := 1.0) -> void:
	strength = clampf(strength, 0.0, 1.0)
	if strength <= 0.0:
		release(action)
		return
	var was: float = _strength.get(action, 0.0)
	if is_equal_approx(was, strength):
		return
	if was <= 0.0:
		_pressed_frame[action] = Engine.get_physics_frames()
	_strength[action] = strength
	pressed.emit(action, strength)


func release(action: StringName) -> void:
	if not _strength.has(action):
		return
	_strength.erase(action)
	_released_frame[action] = Engine.get_physics_frames()
	released.emit(action)


## Lets go of every action (the values stay).
func release_all() -> void:
	for action: StringName in _strength.keys():
		release(action)


## Sets a value your character reads with `get_value(name)`.
func set_value(name: StringName, value: Variant) -> void:
	if _values.has(name) and _values[name] == value:
		return
	_values[name] = value
	value_changed.emit(name, value)


func get_value(name: StringName, default: Variant = null) -> Variant:
	return _values.get(name, default)


func is_action_pressed(action: StringName, _exact_match := false) -> bool:
	return _strength.has(action)


func get_action_strength(action: StringName, _exact_match := false) -> float:
	return _strength.get(action, 0.0)


func get_action_raw_strength(action: StringName, _exact_match := false) -> float:
	return _strength.get(action, 0.0)


func get_axis(negative_action: StringName, positive_action: StringName) -> float:
	return get_action_strength(positive_action) - get_action_strength(negative_action)


func get_vector(
	negative_x: StringName, positive_x: StringName, negative_y: StringName, positive_y: StringName, _deadzone := -1.0
) -> Vector2:
	return Vector2(get_axis(negative_x, positive_x), get_axis(negative_y, positive_y)).limit_length(1.0)


func is_action_just_pressed(action: StringName, _exact_match := false) -> bool:
	return _strength.has(action) and _pressed_frame.get(action, -1) == Engine.get_physics_frames()


func is_action_just_released(action: StringName, _exact_match := false) -> bool:
	return not _strength.has(action) and _released_frame.get(action, -1) == Engine.get_physics_frames()


## The actions held now.
func held() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(_strength.keys())
	return out
