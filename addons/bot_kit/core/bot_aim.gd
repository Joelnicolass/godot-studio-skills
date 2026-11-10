class_name BotAim
extends RefCounted

## The aim's math, without nodes (the tests use it): angles of a direction, the facing of angles, where to aim ahead of
## a walking target and the pitch that lobs a throw onto a point. Yaw turns around +Y with 0 facing -Z (Godot's
## forward); pitch is positive looking up. All angles in radians.

## The pitch of a throw that cannot reach: the farthest one.
const OUT_OF_REACH_PITCH := PI / 4.0


## The yaw that faces `direction` (its flat part).
static func yaw_of(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)


## The pitch that looks along `direction`.
static func pitch_of(direction: Vector3) -> float:
	return atan2(direction.y, Vector2(direction.x, direction.z).length())


## Where `yaw` and `pitch` look.
static func facing(yaw: float, pitch: float) -> Vector3:
	return -Basis.from_euler(Vector3(pitch, yaw, 0.0)).z


## The degrees between looking at `yaw`, `pitch` and looking at `want_yaw`, `want_pitch`.
static func degrees_off(yaw: float, pitch: float, want_yaw: float, want_pitch: float) -> float:
	return rad_to_deg(facing(yaw, pitch).angle_to(facing(want_yaw, want_pitch)))


## Where to aim at a target at `point` walking at `velocity` (only its flat part counts), for a shot flying at
## `speed_m_s` from `from`: ahead by the flight time, at most `most_s` of its walk. Speed 0: a hit at once, no lead.
static func lead(from: Vector3, point: Vector3, velocity: Vector3, speed_m_s: float, most_s: float) -> Vector3:
	if speed_m_s <= 0.0:
		return point
	var flight := from.distance_to(point) / speed_m_s
	return point + Vector3(velocity.x, 0.0, velocity.z) * minf(flight, most_s)


## The pitch that throws at `speed_m_s` under `gravity_m_s2` onto a point `flat_m` away and `rise_m` higher (the low
## arc, the faster one). A point out of reach: OUT_OF_REACH_PITCH.
static func lob_pitch(speed_m_s: float, gravity_m_s2: float, flat_m: float, rise_m: float) -> float:
	if gravity_m_s2 <= 0.0:
		return atan2(rise_m, flat_m)
	var v2 := speed_m_s * speed_m_s
	var root := v2 * v2 - gravity_m_s2 * (gravity_m_s2 * flat_m * flat_m + 2.0 * rise_m * v2)
	if root < 0.0 or flat_m < 0.01:
		return OUT_OF_REACH_PITCH
	return atan((v2 - sqrt(root)) / (gravity_m_s2 * flat_m))


## `from` turned toward `to` by at most `step` (yaw: the short way round, wrapped to -PI..PI).
static func turn_yaw(from: float, to: float, step: float) -> float:
	return wrapf(from + clampf(angle_difference(from, to), -step, step), -PI, PI)
