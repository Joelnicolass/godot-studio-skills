@tool
class_name PlatMotor
extends Node

## 2D platformer forgiveness on a CharacterBody2D. No levels, score, dash, or stamina.
## Celeste-style windows: coyote, jump buffer, apex gravity, jump corner, lift remember.
## Ref: https://maddymakesgames.com/articles/celeste_and_forgiveness/index.html

@export var body: CharacterBody2D
@export var auto_process: bool = true
@export var read_input: bool = true

@export_group("InputMap")
@export var jump_action: StringName = &"jump"
@export var left_action: StringName = &"move_left"
@export var right_action: StringName = &"move_right"

@export_group("Run")
@export var max_speed: float = 180.0
@export var accel: float = 1400.0
@export var friction: float = 1600.0

@export_group("Jump")
@export var jump_speed: float = 320.0
@export var gravity: float = 980.0
@export var fall_gravity_mult: float = 1.35
@export var cut_jump_mult: float = 0.45
@export var coyote_time: float = 0.08
@export var jump_buffer: float = 0.12

@export_group("Apex")
@export var apex_gravity_mult: float = 0.5
@export var apex_speed_threshold: float = 40.0

@export_group("Corner")
@export var jump_corner_pixels: int = 4
@export var side_corner_pixels: int = 0

@export_group("Lift")
@export var lift_remember: float = 0.08

@export_group("Wall jump")
@export var wall_jump_enabled: bool = false
@export var wall_extra_pixels: int = 2
@export var wall_jump_velocity: Vector2 = Vector2(220.0, -300.0)

var axis: float = 0.0

var _buffer: float = 0.0
var _coyote: float = 0.0
var _lift: Vector2 = Vector2.ZERO
var _lift_timer: float = 0.0
var _holding_jump: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not read_input or jump_action == &"":
		return
	if event.is_action_pressed(jump_action) and not event.is_echo():
		request_jump()
	if event.is_action_released(jump_action):
		_holding_jump = false
		_cut_jump()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not auto_process:
		return
	if read_input:
		_poll_hold()
	tick(delta)


func _poll_hold() -> void:
	if left_action != &"" and right_action != &"":
		axis = Input.get_axis(left_action, right_action)
	_holding_jump = jump_action != &"" and Input.is_action_pressed(jump_action)


func request_jump() -> void:
	_buffer = jump_buffer
	_holding_jump = true


func tick(delta: float) -> void:
	var b := _resolve_body()
	if b == null:
		return
	_buffer = maxf(_buffer - delta, 0.0)
	_update_ground(b, delta)
	_run(b, delta)
	_try_jump(b)
	_apply_gravity(b, delta)
	_correct_jump_corner(b, delta)
	if side_corner_pixels > 0:
		try_side_corner_correct(delta)
	b.move_and_slide()
	_update_lift(b, delta)


func try_side_corner_correct(delta: float) -> void:
	var b := _resolve_body()
	if b == null or side_corner_pixels <= 0:
		return
	if is_zero_approx(b.velocity.x):
		return
	var motion := Vector2(b.velocity.x * delta, 0.0)
	if not b.test_move(b.global_transform, motion):
		return
	for pixel in range(1, side_corner_pixels + 1):
		var t := b.global_transform.translated(Vector2(0.0, -float(pixel)))
		if not b.test_move(t, motion):
			b.global_position.y -= float(pixel)
			return


func wall_dir() -> int:
	var b := _resolve_body()
	if b == null:
		return 0
	if b.is_on_wall():
		var n := b.get_wall_normal()
		if n.x > 0.0:
			return -1
		if n.x < 0.0:
			return 1
	if wall_extra_pixels <= 0:
		return 0
	for dir in [-1, 1]:
		if b.test_move(b.global_transform, Vector2(float(dir * wall_extra_pixels), 0.0)):
			return dir
	return 0


func _resolve_body() -> CharacterBody2D:
	if body != null:
		return body
	return get_parent() as CharacterBody2D


func _update_ground(b: CharacterBody2D, delta: float) -> void:
	if b.is_on_floor():
		_coyote = coyote_time
	else:
		_coyote = maxf(_coyote - delta, 0.0)


func _run(b: CharacterBody2D, delta: float) -> void:
	var target := axis * max_speed
	var rate := accel if absf(axis) > 0.01 else friction
	b.velocity.x = move_toward(b.velocity.x, target, rate * delta)


func _try_jump(b: CharacterBody2D) -> void:
	if _buffer <= 0.0:
		return
	var floor_ok := b.is_on_floor() or _coyote > 0.0
	var wall := 0
	if wall_jump_enabled:
		wall = wall_dir()
	if not floor_ok and wall == 0:
		return
	_buffer = 0.0
	_coyote = 0.0
	if wall != 0 and not b.is_on_floor():
		b.velocity.x = -float(wall) * absf(wall_jump_velocity.x)
		b.velocity.y = wall_jump_velocity.y
		b.velocity.x += _lift.x
		return
	b.velocity.y = -jump_speed
	b.velocity.x += _lift.x


func _apply_gravity(b: CharacterBody2D, delta: float) -> void:
	if b.is_on_floor() and b.velocity.y > 0.0:
		return
	var g := gravity
	if b.velocity.y > 0.0:
		g *= fall_gravity_mult
	elif _holding_jump and absf(b.velocity.y) < apex_speed_threshold:
		g *= apex_gravity_mult
	b.velocity.y += g * delta


func _cut_jump() -> void:
	var b := _resolve_body()
	if b == null:
		return
	if b.velocity.y < 0.0:
		b.velocity.y *= cut_jump_mult


func _correct_jump_corner(b: CharacterBody2D, delta: float) -> void:
	if jump_corner_pixels <= 0 or b.velocity.y >= 0.0:
		return
	var motion := Vector2(0.0, b.velocity.y * delta)
	if not b.test_move(b.global_transform, motion):
		return
	for pixel in range(1, jump_corner_pixels + 1):
		for dir in [-1, 1]:
			var t := b.global_transform.translated(Vector2(float(dir * pixel), 0.0))
			if not b.test_move(t, motion):
				b.global_position.x += float(dir * pixel)
				return


func _update_lift(b: CharacterBody2D, delta: float) -> void:
	if b.is_on_floor():
		_lift = b.get_platform_velocity()
		_lift_timer = lift_remember
		return
	_lift_timer = maxf(_lift_timer - delta, 0.0)
	if _lift_timer <= 0.0:
		_lift = Vector2.ZERO


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if _resolve_body() == null:
		out.append("Assign body, or parent this node to a CharacterBody2D.")
	if read_input and (jump_action == &"" or left_action == &"" or right_action == &""):
		out.append("Set InputMap actions, or disable read_input and feed axis / request_jump().")
	return out
