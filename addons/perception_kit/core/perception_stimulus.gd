class_name PerceptionStimulus
extends RefCounted

## One thing a sensor perceives or remembers: what kind it was, where it was last, how strong, how
## long ago. A sensor keeps one per seen target and one per noise source, and updates the same
## object while it keeps perceiving it, so a state that holds one reads it fresh.
##
## `kind` is any StringName: the kit gives SIGHT and HEARING, and a game adds its own without
## touching the kit (a target with `kind = &"light"`, or `sensor.sense(&"alarm", ...)`).

## Seeing a target (the default kind of a PerceptionTarget3D / 2D).
const SIGHT := &"sight"
## Hearing a noise (`sensor.hear()`).
const HEARING := &"hearing"

var kind: StringName = SIGHT
## Where it was perceived last (in 2D, x and y; read `position_2d`).
var position := Vector3.ZERO
## 1 at the eye (or at the noise), 0 at the edge: for sight, the radius it keeps seeing within
## (the lose radius), for a noise its radius.
var strength := 1.0
## Seconds since it was perceived last.
var age_s := 0.0
## Which one of its kind: a seen target's instance id, a noise's `source`.
var key := 0
## Perceived at the sensor's latest chance: seen in its latest look, or heard since it.
var sensing := false
## The seen target (null for a noise, or once the target is freed).
var target: Node:
	get:
		if _target_id == 0:
			return null
		var node := instance_from_id(_target_id) as Node
		return node if is_instance_valid(node) else null
## `position` in 2D.
var position_2d: Vector2:
	get:
		return Vector2(position.x, position.y)

var _target_id := 0


func _init(p_kind: StringName = SIGHT, p_position := Vector3.ZERO, p_strength := 1.0, p_key := 0) -> void:
	kind = p_kind
	position = p_position
	strength = p_strength
	key = p_key


## A stimulus from seeing `of`: its kind, keyed by its instance id.
static func seeing(of: Node, kind_seen: StringName, at: Vector3, p_strength: float) -> PerceptionStimulus:
	var stimulus := PerceptionStimulus.new(kind_seen, at, p_strength, of.get_instance_id())
	stimulus._target_id = of.get_instance_id()
	return stimulus


## True when it comes from seeing a target (not from a noise or `sense()`).
func is_seen() -> bool:
	return _target_id != 0


## Copies what `other` perceived now (same kind and key) into this one.
func refresh(other: PerceptionStimulus) -> void:
	position = other.position
	strength = other.strength
	age_s = other.age_s
	sensing = other.sensing
	_target_id = other._target_id


func _to_string() -> String:
	return "%s #%d at %s (%.2f, %.1f s%s)" % [kind, key, position, strength, age_s, ", now" if sensing else ""]
