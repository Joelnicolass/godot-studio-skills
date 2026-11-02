@tool
class_name PerceptionTarget3D
extends Area3D

## Something a PerceptionSensor3D can see: put it where it is seen from (a character's chest, a
## lamp's bulb). Its own sphere is internal (not saved with the scene).
##
## Its collision layer is its side: a sensor sees the targets on the layers of its collision mask.
## Out of the box both are on layer 32, so every sensor sees every target; give each side of the
## game a layer of its own (Project Settings › Layer Names › 3D Physics) and set the sensors' masks.

## Off, no sensor sees it (it keeps being remembered until forgotten).
@export var enabled := true:
	set(value):
		enabled = value
		set_deferred(&"monitorable", value)
## How visible it is now, from 0 (unseen but up close) to 1: the game lowers it in the dark, in
## cover, crouched. It scales the sensors' sight radius for this target.
@export_range(0.0, 1.0, 0.01) var visibility := 1.0
## What seeing it gives: SIGHT, or the game's own kind (a lit lamp as &"light", which a sensor may
## see from farther with `reach_by_kind`).
@export var kind: StringName = PerceptionStimulus.SIGHT
## Its sphere's radius.
@export_range(0.01, 10.0, 0.01, "or_greater", "suffix:m") var radius_m := 0.3:
	set(value):
		radius_m = maxf(value, 0.01)
		if _sphere != null:
			_sphere.radius = radius_m
## Its own body, which never hides it from a sensor. Empty: the nearest body above it.
@export var body: CollisionObject3D

var _sphere: SphereShape3D


func _init() -> void:
	collision_layer = 1 << 31
	collision_mask = 0
	monitoring = false
	monitorable = true


func _ready() -> void:
	_sphere = SphereShape3D.new()
	_sphere.radius = radius_m
	var shape := CollisionShape3D.new()
	shape.shape = _sphere
	add_child(shape, false, INTERNAL_MODE_FRONT)
	if body == null and not Engine.is_editor_hint():
		body = PerceptionTarget3D.body_above(self)


## The nearest physics body above `node` (a character, a prop), or null.
static func body_above(node: Node) -> CollisionObject3D:
	var up := node.get_parent()
	while up != null:
		if up is PhysicsBody3D:
			return up as CollisionObject3D
		up = up.get_parent()
	return null
