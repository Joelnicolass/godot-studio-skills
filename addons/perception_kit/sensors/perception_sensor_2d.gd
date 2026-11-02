@tool
class_name PerceptionSensor2D
extends Area2D

## What an actor perceives, in 2D: it looks along its +X (rotate it to aim it).
## - **Sight.** It sees the PerceptionTarget2D within `sight_radius_px` and `view_angle_deg`, and
##   keeps seeing one until `lose_radius_px`. Within `near_radius_px` it notices one all around it.
##   Walls on `occlusion_mask` hide them.
## - **Hearing.** `hear(position, radius_px, source)` for the game's noises.
## - **Other senses.** `sense(kind, position)` for any other kind.
## - **Memory.** It remembers each one for `memory_s` after it last perceived it.
##
## Signals: `perceived` when something new is seen (once, until forgotten), and on every noise;
## `forgotten` when the memory of one ends, with where it was last (`stimulus.position_2d`).
##
## The same as PerceptionSensor3D, without eye height. In the editor it draws its view, with
## handles to drag (the PerceptionKit plugin); in the game, with `show_in_game`.

## Something new is perceived: a target it starts seeing, every noise heard, every `sense()`.
signal perceived(stimulus: PerceptionStimulus)
## The memory of one ended: `stimulus.position_2d` is where it was last; `stimulus.target` may be null.
signal forgotten(stimulus: PerceptionStimulus)

## Lines drawn in the editor.
const EDITOR_COLOR := Color(1.0, 0.7, 0.2, 0.9)

## Off, it perceives nothing and forgets everything, without signals.
@export var enabled := true:
	set(value):
		enabled = value
		if not value:
			_memory.clear()
		set_deferred(&"monitoring", value)

@export_group("Sight")
## It starts seeing a target within this distance (and the view's angle).
@export_range(0.0, 4000.0, 1.0, "or_greater", "suffix:px") var sight_radius_px := 320.0:
	set(value):
		sight_radius_px = maxf(value, 0.0)
		_changed()
## It keeps seeing one it sees until this distance. Under `sight_radius_px`, `sight_radius_px`.
@export_range(0.0, 4000.0, 1.0, "or_greater", "suffix:px") var lose_radius_px := 420.0:
	set(value):
		lose_radius_px = maxf(value, 0.0)
		_changed()
## The whole view's angle (360: all around).
@export_range(0.0, 360.0, 0.1, "suffix:°") var view_angle_deg := 120.0:
	set(value):
		view_angle_deg = clampf(value, 0.0, 360.0)
		_changed()
## Within this distance it notices a target behind it too.
@export_range(0.0, 1000.0, 1.0, "or_greater", "suffix:px") var near_radius_px := 48.0:
	set(value):
		near_radius_px = maxf(value, 0.0)
		_changed()
## What hides a target: the world's layers.
@export_flags_2d_physics var occlusion_mask := 1
## Its own body, which never blocks its view. Empty: the nearest body above it.
@export var body: CollisionObject2D
## Scales every sight radius: night, fog, a blinding flash (the game sets it).
@export_range(0.0, 4.0, 0.01, "or_greater") var sight_scale := 1.0:
	set(value):
		sight_scale = maxf(value, 0.0)
		_changed()
## Kinds it sees from farther: `{&"light": 2.5}` sees a target of kind light at 2.5 times the radius.
@export var reach_by_kind: Dictionary[StringName, float] = {}:
	set(value):
		reach_by_kind = value
		_changed()

@export_group("Hearing")
## Scales every noise's radius: 0 deaf, 2 keen.
@export_range(0.0, 4.0, 0.01, "or_greater") var hearing_scale := 1.0

@export_group("Memory")
## It forgets one this long after it last perceived it (at least one look).
@export_range(0.0, 60.0, 0.1, "or_greater", "suffix:s") var memory_s := 5.0
## Looks a second.
@export_range(0.5, 60.0, 0.5, "or_greater", "suffix:Hz") var sense_hz := 5.0

@export_group("Debug draw")
## Draws its view in the game (never headless).
@export var show_in_game := false:
	set(value):
		show_in_game = value
		queue_redraw()
@export var idle_color := Color(0.65, 0.65, 0.65)
@export var aware_color := Color(1.0, 0.7, 0.2)
@export var seeing_color := Color(1.0, 0.25, 0.2)

var _memory := PerceptionMemory.new()
var _circle: CircleShape2D
var _ray := PhysicsRayQueryParameters2D.new()
## Seconds to its next look.
var _wait := 0.0
## The colour drawn last in the game.
var _drawn := Color.TRANSPARENT


func _init() -> void:
	# Only what the kit owns: nothing detects a sensor. Its mask (the sides it sees) is the scene's:
	# Godot sets a node's own properties before its script, so this must not touch it.
	collision_layer = 0
	monitorable = false


## What the kit owns stays out of the inspector and of the scene's file.
func _validate_property(property: Dictionary) -> void:
	if property.name in ["collision_layer", "monitorable", "monitoring"]:
		property.usage = PROPERTY_USAGE_NONE


func _ready() -> void:
	_circle = CircleShape2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = _circle
	add_child(shape, false, INTERNAL_MODE_FRONT)
	_changed()
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	if body == null:
		body = PerceptionTarget2D.body_above(self)
	_ray.collide_with_areas = false
	# Each sensor at its own moment, the same every run.
	_wait = _period() * fposmod(float(get_instance_id() % 1000003) * 0.6180339887, 1.0)


func _physics_process(delta: float) -> void:
	if not enabled:
		return
	var gone := _memory.age(delta, maxf(memory_s, _period()))
	var found: Array[PerceptionStimulus] = []
	_wait -= delta
	if _wait <= 0.0:
		_wait = maxf(_wait + _period(), 0.0)
		found = _look()
	for stimulus in gone:
		forgotten.emit(stimulus)
	for stimulus in found:
		perceived.emit(stimulus)
	if show_in_game and _state_color() != _drawn:
		queue_redraw()


## A noise at `at`, heard up to `radius_px` away (times `hearing_scale`), from `source`: any id of
## the game's (0 for any). Heard, it is remembered and `perceived` is emitted. True when heard.
func hear(at: Vector2, radius_px: float, source := 0) -> bool:
	if not enabled:
		return false
	var reach := radius_px * hearing_scale
	var distance := global_position.distance_to(at)
	if reach <= 0.0 or distance > reach:
		return false
	sense(PerceptionStimulus.HEARING, at, PerceptionGeometry.strength_at(distance, reach), source)
	return true


## Perceives `kind` at `at` now, with no geometry: the game's own senses (an alarm, a smell, a hit).
## Remembered by kind and `source`; `perceived` is emitted.
func sense(kind: StringName, at: Vector2, strength := 1.0, source := 0) -> void:
	if not enabled:
		return
	var stimulus := PerceptionStimulus.new(kind, Vector3(at.x, at.y, 0.0), clampf(strength, 0.0, 1.0), source)
	stimulus.sensing = true
	_memory.remember(stimulus)
	perceived.emit(_memory.find(kind, source))


## The youngest thing it remembers (of `kind`, or of any); on a tie, a seen one. Null: nothing.
func latest(kind: StringName = &"") -> PerceptionStimulus:
	return _memory.latest(kind)


## What it remembers of `target`, or null.
func stimulus_of(target: Node) -> PerceptionStimulus:
	var id := target.get_instance_id()
	var as_target := target as PerceptionTarget2D
	var known := _memory.find(as_target.kind if as_target != null else PerceptionStimulus.SIGHT, id)
	if known != null:
		return known
	for stimulus in _memory.all():
		if stimulus.is_seen() and stimulus.key == id:
			return stimulus
	return null


## True when it saw `target` in its latest look.
func sees(target: Node) -> bool:
	var known := stimulus_of(target)
	return known != null and known.is_seen() and known.sensing


## True when it saw any target in its latest look.
func sees_any() -> bool:
	for stimulus in _memory.all():
		if stimulus.is_seen() and stimulus.sensing:
			return true
	return false


## True while it remembers anything.
func is_aware() -> bool:
	return not _memory.is_empty()


## Everything it remembers (of `kind`, or of any).
func remembered(kind: StringName = &"") -> Array[PerceptionStimulus]:
	return _memory.all(kind)


## Forgets everything, without signals.
func forget_all() -> void:
	_memory.clear()


## How far it may perceive anything: its circle's radius. Override it with `_sight_radius()` when
## that returns more.
func reach_px() -> float:
	var far := 1.0
	for kind in reach_by_kind:
		far = maxf(far, reach_by_kind[kind])
	return maxf(maxf(sight_radius_px, lose_radius_px) * sight_scale * far, near_radius_px)


## The radius it sees `target` within, before `_sight_radius()`: `lose_radius_px` if it sees it
## already (`seen`), else `sight_radius_px`, times `sight_scale`, `reach_by_kind` and the target's
## `visibility`.
func sight_radius_for(target: PerceptionTarget2D, seen: bool) -> float:
	var radius := maxf(lose_radius_px, sight_radius_px) if seen else sight_radius_px
	return radius * sight_scale * float(reach_by_kind.get(target.kind, 1.0)) * target.visibility


## Override it in a script that extends PerceptionSensor2D for a rule of the game's own: `radius`
## is `sight_radius_for(target, seen)`; return the radius to see `target` within.
func _sight_radius(_target: PerceptionTarget2D, _seen: bool, radius: float) -> float:
	return radius


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if lose_radius_px < sight_radius_px:
		out.append("Lose Radius is under Sight Radius: it stops seeing a target at Sight Radius.")
	if collision_mask == 0:
		out.append("The collision mask is empty: it sees no target. Tick the layers its targets are on.")
	return out


func _draw() -> void:
	var colour := EDITOR_COLOR
	if not Engine.is_editor_hint():
		if not show_in_game or DisplayServer.get_name() == "headless":
			return
		colour = _state_color()
		_drawn = colour
	var scale_now := global_scale
	if is_zero_approx(scale_now.x) or is_zero_approx(scale_now.y):
		return
	# The radii are in the world's pixels, whatever this node's scale.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE / scale_now)
	var in_game := 1.0 if Engine.is_editor_hint() else sight_scale
	var lines := PerceptionGeometry.view_lines_2d(
		sight_radius_px * in_game, maxf(lose_radius_px, sight_radius_px) * in_game, view_angle_deg,
		near_radius_px
	)
	if not lines.is_empty():
		draw_multiline(lines, colour, -1.0)


func _period() -> float:
	return 1.0 / maxf(sense_hz, 0.01)


func _state_color() -> Color:
	if sees_any():
		return seeing_color
	if is_aware():
		return aware_color
	return idle_color


## One look: every target in its circle, inside its view or near, not hidden.
func _look() -> Array[PerceptionStimulus]:
	var before: Dictionary[int, bool] = {}
	for stimulus in _memory.all():
		if stimulus.is_seen() and stimulus.sensing:
			before[stimulus.key] = true
	_memory.stop_sensing()
	var found: Array[PerceptionStimulus] = []
	# Just turned on: its sphere is back from the next physics frame.
	if not monitoring:
		return found
	var eye := global_position
	var aim := global_rotation
	var half := deg_to_rad(view_angle_deg) * 0.5
	var space := get_world_2d().direct_space_state
	for area in get_overlapping_areas():
		var target := area as PerceptionTarget2D
		if target == null or not target.enabled:
			continue
		var point := target.global_position
		var seen := before.has(target.get_instance_id())
		var radius := _sight_radius(target, seen, sight_radius_for(target, seen))
		var distance := eye.distance_to(point)
		var near := distance <= near_radius_px
		if not near and (distance > radius or not PerceptionGeometry.in_view_2d(eye, aim, point, half)):
			continue
		if not _clear(space, eye, point, target):
			continue
		# Out of the same radius however it came in, so it does not jump when the lose radius takes over.
		var full := radius if seen else _sight_radius(target, true, sight_radius_for(target, true))
		var strength := 1.0 if near else PerceptionGeometry.strength_at(distance, full)
		var stimulus := PerceptionStimulus.seeing(target, target.kind, Vector3(point.x, point.y, 0.0), strength)
		stimulus.sensing = true
		if _memory.remember(stimulus):
			found.append(stimulus)
	return found


func _clear(space: PhysicsDirectSpaceState2D, eye: Vector2, point: Vector2, target: PerceptionTarget2D) -> bool:
	if occlusion_mask == 0:
		return true
	_ray.from = eye
	_ray.to = point
	_ray.collision_mask = occlusion_mask
	var skip: Array[RID] = []
	if body != null:
		skip.append(body.get_rid())
	if target.body != null:
		skip.append(target.body.get_rid())
	_ray.exclude = skip
	return space.intersect_ray(_ray).is_empty()


func _changed() -> void:
	if _circle != null:
		_circle.radius = maxf(reach_px(), 0.1)
	queue_redraw()
	if Engine.is_editor_hint() and is_inside_tree():
		update_configuration_warnings()
