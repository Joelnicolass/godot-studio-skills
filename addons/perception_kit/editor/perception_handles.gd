extends RefCounted

## The handles' math, the same for the 3D gizmo and the 2D view, without the editor (the tests use
## it): where each handle sits on the view's plane (forward +X, side +Y) and what value a drag to a
## point of that plane gives. Handles: 0 sight radius, 1 lose radius, 2 view angle (on the sight
## arc's edge), 3 near radius (behind), and in 3D 4 eye height.

enum { SIGHT, LOSE, ANGLE, NEAR, EYE }

const NAMES := ["Sight radius", "Lose radius", "View angle", "Near radius", "Eye height"]
const PROPERTIES_3D: Array[StringName] = [
	&"sight_radius_m", &"lose_radius_m", &"view_angle_deg", &"near_radius_m", &"eye_height_m"
]
const PROPERTIES_2D: Array[StringName] = [&"sight_radius_px", &"lose_radius_px", &"view_angle_deg", &"near_radius_px"]


## The four handles on the view's plane.
static func points(sight: float, lose: float, angle_deg: float, near: float) -> PackedVector2Array:
	var half := deg_to_rad(clampf(angle_deg, 0.0, 360.0)) * 0.5
	return PackedVector2Array([
		Vector2(sight, 0.0),
		Vector2(maxf(lose, sight), 0.0),
		Vector2.from_angle(half) * maxf(sight, 0.5 * maxf(lose, sight)),
		Vector2(-near, 0.0),
	])


## The value handle `id` (SIGHT to NEAR) takes when dragged to `at` on the view's plane, snapped to
## `step` (the angle to 1°). The sight radius stays under the lose radius and the lose radius over
## the sight radius.
static func value_at(id: int, at: Vector2, sight: float, lose: float, step: float) -> float:
	var distance := snappedf(at.length(), step)
	match id:
		SIGHT:
			return clampf(distance, 0.0, maxf(lose, sight))
		LOSE:
			return maxf(distance, sight)
		ANGLE:
			return clampf(snappedf(rad_to_deg(absf(at.angle())) * 2.0, 1.0), 0.0, 360.0)
	return maxf(distance, 0.0)


## Where a ray (`from`, `dir`) meets the view's plane, `frame` being the view (its origin at the
## eyes, -Z forward, the plane its x and z): as a point of the plane, or null when it misses.
static func on_plane(frame: Transform3D, from: Vector3, dir: Vector3) -> Variant:
	var inverse := frame.affine_inverse()
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(inverse * from, inverse.basis * dir)
	if hit == null:
		return null
	var local: Vector3 = hit
	return Vector2(-local.z, local.x)


## The plane's point `at` in 3D, in the view `frame`.
static func to_space(frame: Transform3D, at: Vector2) -> Vector3:
	return frame * Vector3(at.y, 0.0, -at.x)


## How high above `origin` a ray (`from`, `dir`) passes the vertical line through it, for the eye
## height handle: NAN when the ray looks straight up or down.
static func height_at(origin: Vector3, from: Vector3, dir: Vector3) -> float:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		return NAN
	var hit: Variant = Plane(flat.normalized(), origin).intersects_ray(from, dir)
	if hit == null:
		return NAN
	return (hit as Vector3).y - origin.y
