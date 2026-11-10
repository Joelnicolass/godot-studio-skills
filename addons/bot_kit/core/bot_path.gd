class_name BotPath
extends RefCounted

## A path on the navigation mesh, followed point by point (the bot's own walking: no NavigationAgent3D to place).
## It asks the NavigationServer3D again when the goal moves, every `repath_s` and when the mesh changes.

## A goal that moved less than this keeps its path.
const SAME_GOAL_M := 0.25

var goal := Vector3.INF
var points := PackedVector3Array()
var index := 0
var _map_iteration := -1
var _age_s := 0.0


## The world's navigation mesh is baked (a map with something on it).
static func map_ready(map: RID) -> bool:
	return map.is_valid() and NavigationServer3D.map_get_iteration_id(map) != 0


## The path from `from` to `to` on `map` (its `layers`); empty when there is none.
static func find(map: RID, from: Vector3, to: Vector3, layers: int) -> PackedVector3Array:
	var start := NavigationServer3D.map_get_closest_point(map, from)
	return NavigationServer3D.map_get_path(map, start, to, true, layers)


## Whether a walk from `from` reaches `to` to within `slack_m`.
static func reaches(map: RID, from: Vector3, to: Vector3, layers: int, slack_m: float) -> bool:
	var path := find(map, from, to, layers)
	return not path.is_empty() and path[path.size() - 1].distance_to(to) <= slack_m


func clear() -> void:
	goal = Vector3.INF
	points = PackedVector3Array()
	index = 0


## The next point to walk toward from `from` on the way to `to` (Vector3.INF: there, or no way).
func next(map: RID, from: Vector3, to: Vector3, layers: int, arrive_m: float, repath_s: float, delta: float) -> Vector3:
	_age_s += delta
	var iteration := NavigationServer3D.map_get_iteration_id(map)
	if goal == Vector3.INF or goal.distance_to(to) > SAME_GOAL_M or _age_s >= repath_s or iteration != _map_iteration:
		goal = to
		points = find(map, from, to, layers)
		index = 0
		_age_s = 0.0
		_map_iteration = iteration
	while index < points.size() and _flat(points[index] - from) <= arrive_m:
		index += 1
	if index >= points.size():
		return Vector3.INF
	return points[index]


static func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()
