class_name PerceptionGeometry
extends RefCounted

## The pure rules the sensors use, for a game's own checks and tests: is a point inside a view, how
## strong is it at a distance, and the lines that draw a view. No nodes, no physics.
##
## In 3D a view looks along its basis's -Z and its angle is measured around its basis's up axis
## (the height does not count). In 2D it looks along +X, rotated by `rotation`.

## Points per full circle in the drawn lines.
const SEGMENTS := 48


## True when `point` is within `half_angle` (radians) of the view's forward, as seen from `eye`.
## Straight above or below the eye counts as inside.
static func in_view_3d(eye: Vector3, basis: Basis, point: Vector3, half_angle: float) -> bool:
	if half_angle >= PI:
		return true
	var local := basis.orthonormalized().transposed() * (point - eye)
	if Vector2(local.x, local.z).length_squared() < 0.000001:
		return true
	return absf(atan2(local.x, -local.z)) <= half_angle


static func in_view_2d(eye: Vector2, rotation: float, point: Vector2, half_angle: float) -> bool:
	if half_angle >= PI:
		return true
	var local := (point - eye).rotated(-rotation)
	if local.length_squared() < 0.000001:
		return true
	return absf(local.angle()) <= half_angle


## 1 at the eye, 0 at `radius` and past it.
static func strength_at(distance: float, radius: float) -> float:
	if radius <= 0.0:
		return 0.0
	return clampf(1.0 - distance / radius, 0.0, 1.0)


## A view's lines on its own plane (x, z; forward is -Z), as pairs of points: the sight fan, the
## lose arc and the near circle. A full angle draws circles.
static func view_lines_3d(sight: float, lose: float, angle_deg: float, near: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in view_lines_2d(sight, lose, angle_deg, near):
		# 2D forward is +X; on the 3D plane it is -Z.
		out.append(Vector3(p.y, 0.0, -p.x))
	return out


## The same in 2D (forward is +X).
static func view_lines_2d(sight: float, lose: float, angle_deg: float, near: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var half := deg_to_rad(clampf(angle_deg, 0.0, 360.0)) * 0.5
	if half < PI:
		for side in [-half, half]:
			out.append(Vector2.ZERO)
			out.append(Vector2.from_angle(side) * sight)
	_arc(out, sight, half)
	if lose > sight:
		_arc(out, lose, half)
	if near > 0.0:
		_arc(out, near, PI)
	return out


static func _arc(out: PackedVector2Array, radius: float, half: float) -> void:
	if radius <= 0.0:
		return
	var steps := maxi(ceili(SEGMENTS * half / PI), 2)
	for k in steps:
		out.append(Vector2.from_angle(lerpf(-half, half, float(k) / steps)) * radius)
		out.append(Vector2.from_angle(lerpf(-half, half, float(k + 1) / steps)) * radius)
