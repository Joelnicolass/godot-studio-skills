extends RefCounted

## The handles' math, without the editor (the tests use it): what a drag from a camera ray gives.
## Bot3D: 0 eye height, 1 aim height (both on the vertical line through its feet). BotGoal3D: 0 reach (on the
## level plane through it).

enum { EYE, AIM }

const BOT_NAMES := ["Eye height", "Aim height"]
const BOT_PROPERTIES: Array[StringName] = [&"eye_height_m", &"aim_height_m"]


## How high above `origin` a ray (`from`, `dir`) passes the vertical line through it: NAN when the ray looks straight
## up or down.
static func height_at(origin: Vector3, from: Vector3, dir: Vector3) -> float:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		return NAN
	var hit: Variant = Plane(flat.normalized(), origin).intersects_ray(from, dir)
	if hit == null:
		return NAN
	return (hit as Vector3).y - origin.y


## How far from `origin`, on the level plane through it, a ray (`from`, `dir`) meets that plane: NAN when it misses.
static func reach_at(origin: Vector3, from: Vector3, dir: Vector3) -> float:
	var hit: Variant = Plane(Vector3.UP, origin.y).intersects_ray(from, dir)
	if hit == null:
		return NAN
	var at: Vector3 = hit
	return Vector2(at.x - origin.x, at.z - origin.z).length()


## A level circle of `radius` around `center`, as line pairs.
static func circle(center: Vector3, radius: float, segments := 48) -> PackedVector3Array:
	var out := PackedVector3Array()
	if radius <= 0.0:
		return out
	for i in segments:
		var a := TAU * i / segments
		var b := TAU * (i + 1) / segments
		out.append(center + Vector3(cos(a), 0.0, sin(a)) * radius)
		out.append(center + Vector3(cos(b), 0.0, sin(b)) * radius)
	return out
