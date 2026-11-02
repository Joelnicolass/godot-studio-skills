@tool
class_name PerceptionTarget2D
extends Area2D

## Something a PerceptionSensor2D can see: put it where it is seen from. Its own circle is
## internal (not saved with the scene).
##
## Its collision layer is its side: a sensor sees the targets on the layers of its collision mask.
## Out of the box both are on layer 32, so every sensor sees every target; give each side of the
## game a layer of its own (Project Settings › Layer Names › 2D Physics) and set the sensors' masks.

## Off, no sensor sees it (it keeps being remembered until forgotten).
@export var enabled := true:
	set(value):
		enabled = value
		set_deferred(&"monitorable", value)
## How visible it is now, from 0 (unseen but up close) to 1: the game lowers it in the dark, in
## cover. It scales the sensors' sight radius for this target.
@export_range(0.0, 1.0, 0.01) var visibility := 1.0
## What seeing it gives: SIGHT, or the game's own kind (a lit lamp as &"light", which a sensor may
## see from farther with `reach_by_kind`).
@export var kind: StringName = PerceptionStimulus.SIGHT
## Its circle's radius.
@export_range(0.1, 200.0, 0.1, "or_greater", "suffix:px") var radius_px := 8.0:
	set(value):
		radius_px = maxf(value, 0.1)
		if _circle != null:
			_circle.radius = radius_px
## Its own body, which never hides it from a sensor. Empty: the nearest body above it.
@export var body: CollisionObject2D

var _circle: CircleShape2D


func _init() -> void:
	collision_layer = 1 << 31
	collision_mask = 0
	monitoring = false
	monitorable = true


func _ready() -> void:
	_circle = CircleShape2D.new()
	_circle.radius = radius_px
	var shape := CollisionShape2D.new()
	shape.shape = _circle
	add_child(shape, false, INTERNAL_MODE_FRONT)
	if body == null and not Engine.is_editor_hint():
		body = PerceptionTarget2D.body_above(self)


## The nearest physics body above `node` (a character, a prop), or null.
static func body_above(node: Node) -> CollisionObject2D:
	var up := node.get_parent()
	while up != null:
		if up is PhysicsBody2D:
			return up as CollisionObject2D
		up = up.get_parent()
	return null
