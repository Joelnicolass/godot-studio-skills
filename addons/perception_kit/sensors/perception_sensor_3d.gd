@tool
class_name PerceptionSensor3D
extends Area3D

## What an actor perceives: put it on the actor's head. It looks along its -Z.
## - **Sight.** It sees the PerceptionTarget3D within `sight_radius_m` and `view_angle_deg`, and
##   keeps seeing one until `lose_radius_m`. Within `near_radius_m` it notices one all around it.
##   Walls on `occlusion_mask` hide them.
## - **Hearing.** `hear(position, radius_m, source)` for the game's noises.
## - **Other senses.** `sense(kind, position)` for any other kind.
## - **Memory.** It remembers each one for `memory_s` after it last perceived it.
##
## Signals: `perceived` when something new is seen (once, until forgotten), and on every noise;
## `forgotten` when the memory of one ends, with where it was last. States read `latest()`,
## `sees_any()`, `is_aware()`.
##
## It looks `sense_hz` times a second, each sensor at its own moment. It sees the targets on the
## layers of its collision mask (layer 1 out of the box, like any area); its own sphere is internal
## (not saved), sized by `reach_m()`. Off (`enabled = false`: a networked game's clients) it does
## nothing.
##
## In the editor its view is drawn with handles to drag (the PerceptionKit plugin). In the game,
## `show_in_game` draws it in grey, amber (remembers something it does not see) or red (sees).

## Something new is perceived: a target it starts seeing, every noise heard, every `sense()`.
signal perceived(stimulus: PerceptionStimulus)
## The memory of one ended: `stimulus.position` is where it was last; `stimulus.target` may be null.
signal forgotten(stimulus: PerceptionStimulus)

## Off, it perceives nothing and forgets everything, without signals.
@export var enabled := true:
	set(value):
		enabled = value
		if not value:
			_memory.clear()
		set_deferred(&"monitoring", value)

@export_group("Sight")
## It starts seeing a target within this distance (and the view's angle).
@export_range(0.0, 200.0, 0.1, "or_greater", "suffix:m") var sight_radius_m := 15.0:
	set(value):
		sight_radius_m = maxf(value, 0.0)
		_changed()
## It keeps seeing one it sees until this distance. Under `sight_radius_m`, `sight_radius_m`.
@export_range(0.0, 200.0, 0.1, "or_greater", "suffix:m") var lose_radius_m := 20.0:
	set(value):
		lose_radius_m = maxf(value, 0.0)
		_changed()
## The whole view's angle, around its up axis (360: all around).
@export_range(0.0, 360.0, 0.1, "suffix:°") var view_angle_deg := 120.0:
	set(value):
		view_angle_deg = clampf(value, 0.0, 360.0)
		_changed()
## Within this distance it notices a target behind it too.
@export_range(0.0, 50.0, 0.1, "or_greater", "suffix:m") var near_radius_m := 2.5:
	set(value):
		near_radius_m = maxf(value, 0.0)
		_changed()
## The eyes, this far above the sensor (0: the sensor is at the eyes).
@export_range(-5.0, 5.0, 0.01, "or_less", "or_greater", "suffix:m") var eye_height_m := 0.0:
	set(value):
		eye_height_m = value
		_changed()
## What hides a target: the world's layers.
@export_flags_3d_physics var occlusion_mask := 1
## Its own body, which never blocks its view. Empty: the nearest body above it.
@export var body: CollisionObject3D
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
		if is_inside_tree() and not Engine.is_editor_hint():
			_show_view(value)
@export var idle_color := Color(0.65, 0.65, 0.65)
@export var aware_color := Color(1.0, 0.7, 0.2)
@export var seeing_color := Color(1.0, 0.25, 0.2)

var _memory := PerceptionMemory.new()
var _sphere: SphereShape3D
var _ray := PhysicsRayQueryParameters3D.new()
## Seconds to its next look.
var _wait := 0.0
var _view: MeshInstance3D
var _view_material: StandardMaterial3D


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
	_sphere = SphereShape3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = _sphere
	add_child(shape, false, INTERNAL_MODE_FRONT)
	_changed()
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	if body == null:
		body = PerceptionTarget3D.body_above(self)
	_ray.collide_with_areas = false
	# Each sensor at its own moment, the same every run.
	_wait = _period() * fposmod(float(get_instance_id() % 1000003) * 0.6180339887, 1.0)
	_show_view(show_in_game)


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
	if _view != null:
		_place_view()


## A noise at `at`, heard up to `radius_m` away (times `hearing_scale`), from `source`: any id of the
## game's (a player's slot, a node's instance id; 0 for any). Heard, it is remembered and
## `perceived` is emitted. True when heard.
func hear(at: Vector3, radius_m: float, source := 0) -> bool:
	if not enabled:
		return false
	var reach := radius_m * hearing_scale
	var distance := eye_position().distance_to(at)
	if reach <= 0.0 or distance > reach:
		return false
	sense(PerceptionStimulus.HEARING, at, PerceptionGeometry.strength_at(distance, reach), source)
	return true


## Perceives `kind` at `at` now, with no geometry: the game's own senses (an alarm, a smell, a hit).
## Remembered by kind and `source`; `perceived` is emitted.
func sense(kind: StringName, at: Vector3, strength := 1.0, source := 0) -> void:
	if not enabled:
		return
	var stimulus := PerceptionStimulus.new(kind, at, clampf(strength, 0.0, 1.0), source)
	stimulus.sensing = true
	_memory.remember(stimulus)
	perceived.emit(_memory.find(kind, source))


## The youngest thing it remembers (of `kind`, or of any); on a tie, a seen one. Null: nothing.
func latest(kind: StringName = &"") -> PerceptionStimulus:
	return _memory.latest(kind)


## What it remembers of `target`, or null.
func stimulus_of(target: Node) -> PerceptionStimulus:
	var id := target.get_instance_id()
	var as_target := target as PerceptionTarget3D
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


func eye_position() -> Vector3:
	return global_position + Vector3.UP * eye_height_m


## How far it may perceive anything: its sphere's radius (around the eyes). Override it with
## `_sight_radius()` when that returns more.
func reach_m() -> float:
	var far := 1.0
	for kind in reach_by_kind:
		far = maxf(far, reach_by_kind[kind])
	return maxf(maxf(sight_radius_m, lose_radius_m) * sight_scale * far, near_radius_m)


## The radius it sees `target` within, before `_sight_radius()`: `lose_radius_m` if it sees it
## already (`seen`), else `sight_radius_m`, times `sight_scale`, `reach_by_kind` and the target's
## `visibility`.
func sight_radius_for(target: PerceptionTarget3D, seen: bool) -> float:
	var radius := maxf(lose_radius_m, sight_radius_m) if seen else sight_radius_m
	return radius * sight_scale * float(reach_by_kind.get(target.kind, 1.0)) * target.visibility


## Override it in a script that extends PerceptionSensor3D for a rule of the game's own: `radius`
## is `sight_radius_for(target, seen)`; return the radius to see `target` within.
func _sight_radius(_target: PerceptionTarget3D, _seen: bool, radius: float) -> float:
	return radius


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if lose_radius_m < sight_radius_m:
		out.append("Lose Radius is under Sight Radius: it stops seeing a target at Sight Radius.")
	if collision_mask == 0:
		out.append("The collision mask is empty: it sees no target. Tick the layers its targets are on.")
	return out


func _period() -> float:
	return 1.0 / maxf(sense_hz, 0.01)


## One look: every target in its sphere, inside its view or near, not hidden.
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
	var eye := eye_position()
	var view := global_basis
	var half := deg_to_rad(view_angle_deg) * 0.5
	var space := get_world_3d().direct_space_state
	for area in get_overlapping_areas():
		var target := area as PerceptionTarget3D
		if target == null or not target.enabled:
			continue
		var point := target.global_position
		var seen := before.has(target.get_instance_id())
		var radius := _sight_radius(target, seen, sight_radius_for(target, seen))
		var distance := eye.distance_to(point)
		var near := distance <= near_radius_m
		if not near and (distance > radius or not PerceptionGeometry.in_view_3d(eye, view, point, half)):
			continue
		if not _clear(space, eye, point, target):
			continue
		# Out of the same radius however it came in, so it does not jump when the lose radius takes over.
		var full := radius if seen else _sight_radius(target, true, sight_radius_for(target, true))
		var strength := 1.0 if near else PerceptionGeometry.strength_at(distance, full)
		var stimulus := PerceptionStimulus.seeing(target, target.kind, point, strength)
		stimulus.sensing = true
		if _memory.remember(stimulus):
			found.append(stimulus)
	return found


func _clear(space: PhysicsDirectSpaceState3D, eye: Vector3, point: Vector3, target: PerceptionTarget3D) -> bool:
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
	if _sphere != null:
		_sphere.radius = maxf(reach_m() + absf(eye_height_m), 0.01)
	if _view != null:
		_draw_view()
	if Engine.is_editor_hint() and is_inside_tree():
		update_gizmos()
		update_configuration_warnings()


func _show_view(on: bool) -> void:
	if on and _view == null and DisplayServer.get_name() != "headless":
		_view_material = StandardMaterial3D.new()
		_view_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_view_material.no_depth_test = true
		_view = MeshInstance3D.new()
		_view.mesh = ImmediateMesh.new()
		_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_view, false, INTERNAL_MODE_BACK)
		_draw_view()
		_place_view()
	elif not on and _view != null:
		_view.queue_free()
		_view = null


func _draw_view() -> void:
	var mesh := _view.mesh as ImmediateMesh
	mesh.clear_surfaces()
	var lines := PerceptionGeometry.view_lines_3d(
		sight_radius_m * sight_scale, maxf(lose_radius_m, sight_radius_m) * sight_scale, view_angle_deg,
		near_radius_m
	)
	if lines.is_empty():
		return
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, _view_material)
	for point in lines:
		mesh.surface_add_vertex(point)
	mesh.surface_end()


func _place_view() -> void:
	_view.global_transform = Transform3D(global_basis.orthonormalized(), eye_position())
	var colour := idle_color
	if sees_any():
		colour = seeing_color
	elif is_aware():
		colour = aware_color
	_view_material.albedo_color = colour
