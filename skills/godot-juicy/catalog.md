# Juicy recipes (Godot 4)

`@export` knobs. IDs in English. The parent calls `play()` / `play_hit()`.

## Camera shake (2D)

Child of `Camera2D`. Trauma 0–1, decay per second, noise on `offset`.

```gdscript
class_name CameraShake
extends Node

@export var decay: float = 1.6
@export var max_offset: Vector2 = Vector2(12, 10)
@export var max_roll: float = 0.04

var trauma: float = 0.0
var _noise := FastNoiseLite.new()
var _cam: Camera2D


func _ready() -> void:
	_cam = get_parent() as Camera2D
	_noise.seed = randi()
	_noise.frequency = 18.0


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	if _cam == null:
		return
	if trauma <= 0.0:
		_cam.offset = Vector2.ZERO
		_cam.rotation = 0.0
		return
	trauma = maxf(trauma - decay * delta, 0.0)
	var t := trauma * trauma
	var n := Time.get_ticks_msec() * 0.001
	_cam.offset = Vector2(
		max_offset.x * t * _noise.get_noise_2d(n, 0.0),
		max_offset.y * t * _noise.get_noise_2d(0.0, n)
	)
	_cam.rotation = max_roll * t * _noise.get_noise_2d(n, n)
```

3D: same trauma on `Camera3D` `h_offset` / `v_offset`, or a `Node3D` pivot parent of the camera.

## Hit squash

See [godot-animation](../godot-animation/SKILL.md). Tween for a scale punch; `AnimationPlayer` if the hit moves several sprites.

## One-shot particles

`GPUParticles2D`: `one_shot = true`, high `explosiveness`, `emitting = false` in the editor. On hit: `restart()`. `@export` amount / lifetime. Do not leave `emitting` infinite on an impact.

## Screen flash

`CanvasLayer` + full-rect `ColorRect`, `mouse_filter = IGNORE`, modulate.a 0. Tween to `@export flash_alpha` and back to 0.

## Post pass

[patterns.md](../godot-composition-first/patterns.md) PostFx stack. One effect = one packed scene. Search [Godot Shaders](https://godotshaders.com/shader/?orderby=date&order=DESC) before writing a `.gdshader`. Gameplay tweens the pass `shader_parameter`; it does not copy the shader.

## Visual hit-stop

```gdscript
@export var freeze_duration: float = 0.05

func play_freeze(anim: AnimationPlayer) -> void:
	anim.pause()
	await get_tree().create_timer(freeze_duration).timeout
	anim.play()
```

`Engine.time_scale` only in 1P, restore in the same method. Not the MP default.

## How to call it

Damage emits `damaged` / input calls `apply_attack`. A juicy child listens, or the container calls `juicy_hit.play()`. Juicy does **not** decide whether the hit is valid.
