@tool
class_name SpillPool3D
extends Node3D

## Draws every spill of its world: the drops of each spray, the marks they leave on the floor (they
## stay; past marks_per_type the oldest of a type is reused) and the puddles that grow under the
## dead. One per world (a level): every SpillSource3D of that world finds it, and makes one with the
## default values if there is none. Everything is built once per type and reused; nothing is made
## per hit. Right after it builds a type, it draws one drop, mark and puddle of it for two frames,
## under a pixel wide in front of the camera, so their shaders compile while the level loads and not
## on the first hit. A dedicated server builds and draws nothing.
##
## It spills without a source too: spill(type, at, away, heavy) and puddle(type, at), for a barrel
## that leaks oil or a pen that breaks.

const Shape := SpillShapes.Shape
## Keys of a floor ray's hit (PhysicsDirectSpaceState3D.intersect_ray).
const HIT_POSITION := "position"
const HIT_NORMAL := "normal"
## The lay a sought puddle spot was checked with.
const SPOT_LAY := "lay"
## A puddle's flatness probes look this far over and under its plane.
const PROBE_M := 0.5
## Marks stack in this many heights, mark_lift_step_m apart, and start over.
const LIFT_LAYERS := 64
## A drop's speed varies this much either way.
const SPEED_SPREAD := 0.25
## A mark that would land behind a wall lands this far in front of it.
const WALL_GAP_M := 0.05
## The warm-up: frames it is drawn, how small, how far past the camera's near plane, and how many
## frames it waits for a camera.
const WARM_FRAMES := 2
const WARM_SCALE := 0.00005
const WARM_AHEAD_M := 0.1
const WARM_WAIT_FRAMES := 120


## The nodes built for one type.
class Built:
	var sprays: Array[CPUParticles3D] = []
	var heavy_sprays: Array[CPUParticles3D] = []
	var next_spray := 0
	var next_heavy := 0
	var sprays_played := 0
	var marks: MultiMesh
	var transforms: Array[Transform3D] = []
	var written := 0
	var puddle_material: Material


## One puddle of the ring.
class Puddle:
	var mesh: MeshInstance3D
	var type: SpillType
	var start_m := 0.0
	var side_m := 0.0
	var grow_s := 0.0
	var age_s := 0.0


## False: new spills are not drawn (a player's "blood" option); what is on the floor stays.
@export var shown := true
## The types built when the pool starts, so the first hit of each costs nothing. A source builds its
## own type when it enters, listed or not.
@export var types: Array[SpillType] = []:
	set(value):
		types = value
		update_configuration_warnings()
## What counts as floor for the marks and the puddles: keep the bodies out of it.
@export_flags_3d_physics var floor_mask := 1:
	set(value):
		floor_mask = value
		update_configuration_warnings()
## The floor is looked for down to this far under the spill; farther (in the air), no mark.
@export_range(0.0, 20.0, 0.05, "suffix:m") var floor_reach_m := 2.0
@export_group("Sprays")
## Sprays kept per type and weight (light, heavy); more at once reuse the oldest.
@export_range(1, 32) var sprays_per_type := 6
@export_group("Marks")
## Marks kept per type; past this the oldest is reused.
@export_range(1, 4096) var marks_per_type := 64
## Each mark's shade goes from this (darker) to 1, so the marks do not repeat.
@export_range(0.0, 1.0, 0.01) var mark_shade_min := 0.8
## Off the floor along its normal, so a mark does not sink into it.
@export_range(0.0, 0.1, 0.001, "suffix:m") var mark_lift_m := 0.01
## Extra lift per mark, so two marks that overlap never sit at the same height (no flicker); 64
## heights, then over.
@export_range(0.0, 0.01, 0.0001, "suffix:m") var mark_lift_step_m := 0.0002
@export_group("Puddles")
## Puddles kept, every type together; more reuse the oldest.
@export_range(1, 128) var puddles := 12
## Side of a puddle when it starts growing.
@export_range(0.01, 5.0, 0.01, "suffix:m") var puddle_start_m := 0.1
## Off the floor along its normal: under the marks, so they stay on top.
@export_range(0.0, 0.1, 0.001, "suffix:m") var puddle_lift_m := 0.006
## Probes around a puddle's edge before it grows: where the floor is not flat that far (a curb, a
## step), the puddle is smaller.
@export_range(4, 32) var puddle_probes := 8
## Where the probes go, as a share of the puddle's side (the kit's puddle is a bit smaller than its
## square).
@export_range(0.1, 0.71, 0.01) var puddle_edge_share := 0.45
## A probe farther than this off the middle's floor means the puddle is too big.
@export_range(0.0, 0.5, 0.005, "suffix:m") var puddle_flat_m := 0.03
## Each try that does not fit shrinks the puddle by this.
@export_range(0.1, 0.95, 0.05) var puddle_shrink := 0.8
## Smallest side a puddle shrinks to; below this, no puddle there.
@export_range(0.05, 5.0, 0.05, "suffix:m") var puddle_min_m := 0.4
## Where the floor under the body is not flat enough even for puddle_min_m (by a curb, on its bevel),
## the puddle looks for flat floor this far around, away from the slope first, never higher than
## where the body lies (a liquid runs down, not up a curb). 0: no puddle there.
@export_range(0.0, 3.0, 0.05, "suffix:m") var puddle_seek_m := 0.75
@export_group("Try it")
## Takes every mark and puddle off the floor.
@export_tool_button("Clear the floor", "Clear") var clear_button := clear

static var _by_world: Dictionary[World3D, SpillPool3D] = {}

var _built: Dictionary[SpillType, Built] = {}
var _puddles: Array[Puddle] = []
var _next_puddle := 0
## Types to draw once so their shaders compile, and the nodes drawing them now.
var _to_warm: Array[SpillType] = []
var _warm_nodes: Array[Node3D] = []
var _warm_frames_left := 0
var _warm_wait_left := 0
var _rng := RandomNumberGenerator.new()
var _ray := PhysicsRayQueryParameters3D.new()
# Made by for_node() because the world had none: a pool put in the world later takes its place.
var _made := false


## The pool of [param world] (null: none yet).
static func of(world: World3D) -> SpillPool3D:
	var found: Variant = _by_world.get(world)
	return found as SpillPool3D if is_instance_valid(found) else null


## The pool of [param node]'s world; if there is none, one with the default values, made in the
## node's scene (the edited one in the editor, where it is not saved). A SpillPool3D put in the world
## later (a level loaded after its bodies) takes the made one's place. Null on a dedicated server.
static func for_node(node: Node3D) -> SpillPool3D:
	if not node.is_inside_tree() or not draws_here():
		return null
	var world := node.get_world_3d()
	var found := of(world)
	if found != null:
		return found
	var tree := node.get_tree()
	var scene := tree.edited_scene_root if Engine.is_editor_hint() else tree.current_scene
	if scene == null:
		scene = tree.root
	found = SpillPool3D.new()
	found.name = "SpillPool3D"
	found._made = true
	_by_world[world] = found
	if scene.is_node_ready():
		scene.add_child(found, false, Node.INTERNAL_MODE_BACK)
	else:
		# The scene is setting up its children (a source asks from its _ready): right after.
		scene.add_child.call_deferred(found, false, Node.INTERNAL_MODE_BACK)
	if not Engine.is_editor_hint():
		push_warning("SpillKit: no SpillPool3D in this world, so one with the default values was made. Add one to the level to set them.")
	return found


## False on a dedicated server (an export with the dedicated_server feature, or an exported game run
## headless): nothing is built or drawn there.
static func draws_here() -> bool:
	return not is_server(OS.has_feature("dedicated_server"), DisplayServer.get_name(), OS.has_feature("editor"))


## True for a dedicated server: [param dedicated] (the export's feature), or a [param display] of
## "headless" out of the [param editor] (the editor's own headless runs, the tests, still draw).
static func is_server(dedicated: bool, display: String, editor: bool) -> bool:
	return dedicated or (display == "headless" and not editor)


func _enter_tree() -> void:
	var world := get_world_3d()
	var current := of(world)
	if current == null:
		_by_world[world] = self
	elif current._made and not _made:
		# A pool of the world's own takes the place of the one made for want of it.
		_by_world[world] = self
		current.queue_free()


func _exit_tree() -> void:
	var world := get_world_3d()
	if _by_world.get(world) == self:
		_by_world.erase(world)


func _ready() -> void:
	# A source may have built its type already (it was ready first): its warm-up is pending.
	set_process(not _to_warm.is_empty())
	_rng.randomize()
	if Engine.is_editor_hint():
		return
	for type in types:
		prepare(type)


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if floor_mask == 0:
		out.append("floor_mask is empty: no mark or puddle finds a floor.")
	if is_inside_tree() and of(get_world_3d()) != self:
		out.append("Another SpillPool3D draws this world already; this one draws nothing.")
	for type in types:
		if type == null:
			out.append("types has an empty slot.")
			continue
		var named := type.resource_path.get_file() if not type.resource_path.is_empty() else "a type"
		for problem in type.problems():
			out.append("%s: %s" % [named, problem])
		if type.puddle_size_m < puddle_min_m:
			out.append("%s: puddle_size_m is under puddle_min_m: it grows no puddle." % named)
	return out


## Builds [param type]'s sprays, marks and materials now, once (a source does it when it enters).
func prepare(type: SpillType) -> void:
	if type == null or _built.has(type) or not draws_here():
		return
	var built := Built.new()
	for i in sprays_per_type:
		built.sprays.append(_new_spray())
		built.heavy_sprays.append(_new_spray())
	built.marks = MultiMesh.new()
	built.marks.transform_format = MultiMesh.TRANSFORM_3D
	built.marks.use_colors = true
	built.marks.instance_count = marks_per_type
	built.marks.visible_instance_count = 0
	built.transforms.resize(marks_per_type)
	var holder := MultiMeshInstance3D.new()
	holder.multimesh = built.marks
	holder.top_level = true
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(holder, false, Node.INTERNAL_MODE_BACK)
	_built[type] = built
	_dress(type, built)
	if _puddles.is_empty():
		_build_puddles()
	if not Engine.is_editor_hint():
		_to_warm.append(type)
		_warm_wait_left = WARM_WAIT_FRAMES
		set_process(true)


## Takes [param type]'s values again (its sizes, colours, textures, materials); the marks and puddles
## on the floor stay. The "Try it" buttons do it, after you change the type.
func refresh(type: SpillType) -> void:
	if _built.has(type):
		_dress(type, _built[type])


## Plays a spray of [param type] at [param at], flying along the flat [param away] (zero: any way),
## and leaves its marks on the floor under it. [param heavy]: the heavy spray. [param exclude]: the
## bodies the floor rays go through (the body that spills). [param reach_m]: how far under [param at]
## the floor may be (0: floor_reach_m).
func spill(type: SpillType, at: Vector3, away := Vector3.ZERO, heavy := false, exclude: Array[RID] = [], reach_m := 0.0) -> void:
	if not shown or type == null or not is_inside_tree():
		return
	prepare(type)
	var built: Built = _built.get(type)
	if built == null:
		return
	_play(built, type, at, away, heavy)
	for i in (type.marks_per_heavy if heavy else type.marks_per_spray):
		var point := _inside_walls(at, _around(at, type.mark_radius_m), exclude)
		var hit := _floor_under(point, exclude, reach_m)
		if not hit.is_empty():
			_place_mark(built, type, hit[HIT_POSITION], hit[HIT_NORMAL])


## Starts a puddle of [param type] growing on the floor under [param at], as big as the floor is
## flat (at most the type's puddle_size_m). [param exclude]: the bodies the floor rays go through.
## [param reach_m]: how far under [param at] the floor may be (0: floor_reach_m).
func puddle(type: SpillType, at: Vector3, exclude: Array[RID] = [], reach_m := 0.0) -> void:
	if not shown or type == null or not is_inside_tree():
		return
	prepare(type)
	var built: Built = _built.get(type)
	if built == null:
		return
	var hit := _floor_under(at, exclude, reach_m)
	if hit.is_empty():
		return
	var point: Vector3 = hit[HIT_POSITION]
	var normal: Vector3 = hit[HIT_NORMAL]
	var lay := _flat_on(normal)
	var side := _flat_side(point, lay, type.puddle_size_m, exclude)
	if side <= 0.0:
		var spot := _seek_flat(at, point, lay, type.puddle_size_m, exclude, reach_m)
		if spot.is_empty():
			return
		point = spot[HIT_POSITION]
		normal = spot[HIT_NORMAL]
		lay = spot[SPOT_LAY]
		# At least puddle_min_m fits there: the search checked it with this very lay.
		side = maxf(_flat_side(point, lay, type.puddle_size_m, exclude), puddle_min_m)
	var next := _puddles[_next_puddle]
	_next_puddle = (_next_puddle + 1) % _puddles.size()
	next.type = type
	next.side_m = side
	next.start_m = minf(puddle_start_m, side)
	next.grow_s = type.puddle_grow_s
	next.age_s = 0.0
	next.mesh.material_override = built.puddle_material
	next.mesh.global_transform = Transform3D(lay, point + normal * puddle_lift_m)
	next.mesh.scale = Vector3.ONE * (next.start_m if next.grow_s > 0.0 else side)
	next.mesh.visible = true
	set_process(true)


## Takes every mark and puddle off the floor and the drops out of the air (a new round).
func clear() -> void:
	for built: Built in _built.values():
		built.written = 0
		built.marks.visible_instance_count = 0
		for spray in built.sprays + built.heavy_sprays:
			spray.emitting = false
			spray.visible = false
	for each in _puddles:
		each.mesh.visible = false
		each.age_s = each.grow_s


## How many marks of [param type] are on the floor.
func mark_count(type: SpillType) -> int:
	return _built[type].marks.visible_instance_count if _built.has(type) else 0


## Where the marks of [param type] lie (each one's transform: its basis is its size and the floor's
## slope), oldest first until the ring starts over.
func marks_of(type: SpillType) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	if _built.has(type):
		out.assign(_built[type].transforms.slice(0, mark_count(type)))
	return out


## Where the puddles of [param type] lie (each one's transform, scaled as it is now).
func puddles_of(type: SpillType) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for each in _puddles:
		if each.type == type and each.mesh.visible:
			out.append(each.mesh.global_transform)
	return out


## The material [param type]'s drops, marks or puddle ([param shape]) are drawn with (null: not
## built yet). Change it at runtime and every one of them changes; refresh() builds it again.
func material_of(type: SpillType, shape: Shape) -> Material:
	if not _built.has(type):
		return null
	var built := _built[type]
	match shape:
		Shape.DROP:
			return built.sprays[0].mesh.surface_get_material(0)
		Shape.MARK:
			return built.marks.mesh.surface_get_material(0)
	return built.puddle_material


## How many sprays of [param type] have been played.
func sprays_played(type: SpillType) -> int:
	return _built[type].sprays_played if _built.has(type) else 0


## What this pool keeps for the types it knows (types, and those built since): "types", "drops" (in
## all its sprays), "marks", "puddles", and "draw_calls", the most at once (each spray in the air and
## each puddle is one, each type's marks one).
func cost() -> Dictionary:
	var known: Array[SpillType] = []
	for type in types:
		if type != null and not known.has(type):
			known.append(type)
	for type: SpillType in _built.keys():
		if not known.has(type):
			known.append(type)
	var drops := 0
	for type in known:
		drops += sprays_per_type * (type.drops + type.heavy_drops)
	return {
		"types": known.size(),
		"drops": drops,
		"marks": marks_per_type * known.size(),
		"puddles": puddles,
		"draw_calls": known.size() * (2 * sprays_per_type + 1) + puddles,
	}


## The cost, as the inspector shows it.
func cost_text() -> String:
	var known := cost()
	if known["types"] == 0:
		return "Cost: no types yet. List this world's types in types (or each is built when its first source enters)."
	return "Cost: %d %s, %d drops in %d sprays, %d marks, %d puddles; at most %d draw calls at once." % [
		known["types"], "type" if known["types"] == 1 else "types", known["drops"],
		known["types"] * 2 * sprays_per_type, known["marks"], known["puddles"], known["draw_calls"]]


func _process(delta: float) -> void:
	var busy := _warm()
	for each in _puddles:
		if each.age_s >= each.grow_s:
			continue
		each.age_s = minf(each.age_s + delta, each.grow_s)
		var t := sin(each.age_s / each.grow_s * PI * 0.5)
		each.mesh.scale = Vector3.ONE * lerpf(each.start_m, each.side_m, t)
		busy = busy or each.age_s < each.grow_s
	if not busy:
		set_process(false)


# Draws the types in _to_warm once, tiny, in front of the camera: a drop, a mark and a puddle of each,
# with the very meshes and materials the pool draws them with. True while it is not done.
func _warm() -> bool:
	if _warm_frames_left > 0:
		_warm_frames_left -= 1
		if _warm_frames_left == 0:
			for node in _warm_nodes:
				node.queue_free()
			_warm_nodes.clear()
		return true
	if _to_warm.is_empty():
		return false
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		_warm_wait_left -= 1
		if _warm_wait_left <= 0:
			_to_warm.clear()
		return not _to_warm.is_empty()
	var at := Transform3D(
		Basis.from_scale(Vector3.ONE * WARM_SCALE),
		camera.global_position - camera.global_basis.z * (camera.near + WARM_AHEAD_M))
	for type in _to_warm:
		var built := _built[type]
		var drop := _new_spray()
		_tune(drop, type, false, built.sprays[0].mesh.surface_get_material(0))
		# Its own tiny quad (the same material): a particle's size is its mesh's, not the node's. It
		# flies as any spray (stopped, it would emit nothing), a few centimetres in two frames.
		(drop.mesh as QuadMesh).size = Vector2.ONE * WARM_SCALE
		drop.emission_sphere_radius = WARM_SCALE
		drop.global_transform = at
		drop.visible = true
		drop.restart()
		var marks := MultiMesh.new()
		marks.transform_format = MultiMesh.TRANSFORM_3D
		marks.use_colors = true
		marks.instance_count = 1
		marks.mesh = built.marks.mesh
		marks.set_instance_transform(0, at)
		var mark := MultiMeshInstance3D.new()
		mark.multimesh = marks
		mark.top_level = true
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mark, false, Node.INTERNAL_MODE_BACK)
		var puddle_mesh := MeshInstance3D.new()
		puddle_mesh.mesh = _puddles[0].mesh.mesh
		puddle_mesh.material_override = built.puddle_material
		puddle_mesh.top_level = true
		puddle_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(puddle_mesh, false, Node.INTERNAL_MODE_BACK)
		puddle_mesh.global_transform = at
		_warm_nodes.append_array([drop, mark, puddle_mesh])
	_to_warm.clear()
	_warm_frames_left = WARM_FRAMES
	return true


func _new_spray() -> CPUParticles3D:
	var spray := CPUParticles3D.new()
	# Before it enters: a new CPUParticles3D emits at once.
	spray.emitting = false
	spray.one_shot = true
	spray.explosiveness = 1.0
	spray.local_coords = false
	spray.top_level = true
	spray.visible = false
	spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(spray, false, Node.INTERNAL_MODE_BACK)
	return spray


func _build_puddles() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	for i in puddles:
		var each := Puddle.new()
		each.mesh = MeshInstance3D.new()
		each.mesh.mesh = plane
		each.mesh.top_level = true
		each.mesh.visible = false
		each.mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(each.mesh, false, Node.INTERNAL_MODE_BACK)
		_puddles.append(each)


# Gives a type's nodes its values and materials.
func _dress(type: SpillType, built: Built) -> void:
	var drop := SpillMaterials.build(type, Shape.DROP)
	for spray in built.sprays:
		_tune(spray, type, false, drop)
	for spray in built.heavy_sprays:
		_tune(spray, type, true, drop)
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	plane.material = SpillMaterials.build(type, Shape.MARK)
	built.marks.mesh = plane
	built.puddle_material = SpillMaterials.build(type, Shape.PUDDLE)
	for each in _puddles:
		if each.type == type:
			each.mesh.material_override = built.puddle_material


func _tune(spray: CPUParticles3D, type: SpillType, heavy: bool, material: Material) -> void:
	var size := type.heavy_drop_size_m if heavy else type.drop_size_m
	spray.amount = maxi(1, type.heavy_drops if heavy else type.drops)
	spray.lifetime = type.heavy_drop_life_s if heavy else type.drop_life_s
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	quad.material = material
	spray.mesh = quad
	spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	spray.emission_sphere_radius = size
	var rise := deg_to_rad(type.heavy_rise_deg if heavy else type.rise_deg)
	# The spray's way is its -Z, risen over the horizon.
	spray.direction = Vector3(0.0, sin(rise), -cos(rise))
	spray.spread = minf(type.heavy_spread_deg if heavy else type.spread_deg, 180.0)
	spray.gravity = _gravity()
	var speed := type.heavy_drop_speed_m_s if heavy else type.drop_speed_m_s
	spray.initial_velocity_min = speed * (1.0 - SPEED_SPREAD)
	spray.initial_velocity_max = speed * (1.0 + SPEED_SPREAD)
	spray.scale_amount_min = type.heavy_drop_scale_min if heavy else type.drop_scale_min
	spray.scale_amount_max = type.heavy_drop_scale_max if heavy else type.drop_scale_max
	spray.color = type.color


func _play(built: Built, type: SpillType, at: Vector3, away: Vector3, heavy: bool) -> void:
	if (type.heavy_drops if heavy else type.drops) <= 0:
		return
	var spray: CPUParticles3D
	if heavy:
		spray = built.heavy_sprays[built.next_heavy]
		built.next_heavy = (built.next_heavy + 1) % built.heavy_sprays.size()
	else:
		spray = built.sprays[built.next_spray]
		built.next_spray = (built.next_spray + 1) % built.sprays.size()
	var flat := Vector3(away.x, 0.0, away.z)
	var facing := Basis(Vector3.UP, _rng.randf() * TAU)
	if not flat.is_zero_approx():
		facing = Basis.looking_at(flat.normalized(), Vector3.UP)
	spray.global_transform = Transform3D(facing, at)
	spray.visible = true
	spray.restart()
	built.sprays_played += 1


func _place_mark(built: Built, type: SpillType, point: Vector3, normal: Vector3) -> void:
	var size := _rng.randf_range(minf(type.mark_min_m, type.mark_max_m), type.mark_max_m)
	var lay := _flat_on(normal) * Basis.from_scale(Vector3(size, 1.0, size))
	var index := built.written % built.marks.instance_count
	built.written += 1
	built.marks.visible_instance_count = mini(built.written, built.marks.instance_count)
	var lift := mark_lift_m + mark_lift_step_m * float(index % LIFT_LAYERS)
	built.transforms[index] = Transform3D(lay, point + normal * lift)
	built.marks.set_instance_transform(index, built.transforms[index])
	var shade := _rng.randf_range(mark_shade_min, 1.0)
	built.marks.set_instance_color(index, Color(shade, shade, shade))


# A point anywhere on the flat disc of [param radius_m] around [param at].
func _around(at: Vector3, radius_m: float) -> Vector3:
	var distance := sqrt(_rng.randf()) * radius_m
	var turn := _rng.randf() * TAU
	return at + Vector3(cos(turn) * distance, 0.0, sin(turn) * distance)


# [param point], or short of the first wall between it and [param at], so no mark lands behind one.
func _inside_walls(at: Vector3, point: Vector3, exclude: Array[RID]) -> Vector3:
	if at.is_equal_approx(point):
		return point
	var hit := _cast(at, point, exclude)
	if hit.is_empty():
		return point
	var wall: Vector3 = hit[HIT_POSITION]
	return wall - (point - at).normalized() * WALL_GAP_M


# Lies flat on a floor of [param normal], turned at random about it.
func _flat_on(normal: Vector3) -> Basis:
	var turn := Basis(Vector3.UP, _rng.randf() * TAU)
	return Basis(Quaternion(Vector3.UP, normal.normalized())) * turn


# The floor under [param point], down to [param reach_m] (0: floor_reach_m); empty when there is none
# (in the air).
func _floor_under(point: Vector3, exclude: Array[RID], reach_m: float) -> Dictionary:
	return _cast(point, point + Vector3.DOWN * (reach_m if reach_m > 0.0 else floor_reach_m), exclude)


# The biggest side (from [param size_m], shrunk by puddle_shrink down to puddle_min_m) whose edge
# probes all find the floor within puddle_flat_m of the middle's plane; 0 if none.
func _flat_side(at: Vector3, lay: Basis, size_m: float, exclude: Array[RID]) -> float:
	var side := size_m
	while side >= puddle_min_m:
		if _is_flat(at, lay, side * puddle_edge_share, exclude):
			return side
		side *= puddle_shrink
	return 0.0


# Flat floor near [param base] (the floor under [param at], too steep or broken for a puddle): in
# rings puddle_min_m / 2 apart out to puddle_seek_m, the side away from the slope first. A spot is
# taken when no wall stands between it and [param at], its floor is no higher than base (plus
# puddle_flat_m) and a puddle_min_m puddle fits there. Its floor ray hit with the lay it was checked
# with (SPOT_LAY), or empty.
func _seek_flat(at: Vector3, base: Vector3, lay: Basis, size_m: float, exclude: Array[RID], reach_m: float) -> Dictionary:
	if puddle_seek_m <= 0.0:
		return {}
	var away := Vector3(lay.y.x, 0.0, lay.y.z) - _uphill(base, lay, size_m * puddle_edge_share, exclude)
	var ways: Array[Vector3] = []
	for i in puddle_probes:
		var turn := TAU * float(i) / float(puddle_probes)
		ways.append(Vector3(cos(turn), 0.0, sin(turn)))
	if away.length() > 0.001:
		var downhill := away.normalized()
		ways.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.dot(downhill) > b.dot(downhill))
	var step := maxf(puddle_min_m * 0.5, 0.05)
	var radius := step
	while radius <= puddle_seek_m + 0.001:
		for way in ways:
			var spot := at + way * radius
			if not _cast(at, spot, exclude).is_empty():
				continue
			var hit := _floor_under(spot, exclude, reach_m)
			if hit.is_empty():
				continue
			var floor_at: Vector3 = hit[HIT_POSITION]
			if floor_at.y > base.y + puddle_flat_m:
				continue
			var spot_lay := _flat_on(hit[HIT_NORMAL])
			if _is_flat(floor_at, spot_lay, puddle_min_m * puddle_edge_share, exclude):
				hit[SPOT_LAY] = spot_lay
				return hit
		radius += step
	return {}


# Which way the floor rises around [param base], flat: each probe of the ring at [param radius_m]
# pulls toward its side by how high its floor stands over base's plane.
func _uphill(base: Vector3, lay: Basis, radius_m: float, exclude: Array[RID]) -> Vector3:
	var normal := lay.y.normalized()
	var out := Vector3.ZERO
	for i in puddle_probes:
		var turn := TAU * float(i) / float(puddle_probes)
		var way := lay * Vector3(cos(turn), 0.0, sin(turn))
		var edge := base + way * radius_m
		var hit := _cast(edge + normal * PROBE_M, edge - normal * PROBE_M, exclude)
		if not hit.is_empty():
			var floor_at: Vector3 = hit[HIT_POSITION]
			out += way * normal.dot(floor_at - base)
	return Vector3(out.x, 0.0, out.z)


func _is_flat(at: Vector3, lay: Basis, radius_m: float, exclude: Array[RID]) -> bool:
	var normal := lay.y.normalized()
	for i in puddle_probes:
		var turn := TAU * float(i) / float(puddle_probes)
		var edge := at + lay * (Vector3(cos(turn), 0.0, sin(turn)) * radius_m)
		var hit := _cast(edge + normal * PROBE_M, edge - normal * PROBE_M, exclude)
		if hit.is_empty():
			return false
		var floor_at: Vector3 = hit[HIT_POSITION]
		if absf(normal.dot(floor_at - at)) > puddle_flat_m:
			return false
	return true


func _cast(from: Vector3, to: Vector3, exclude: Array[RID]) -> Dictionary:
	_ray.from = from
	_ray.to = to
	_ray.collision_mask = floor_mask
	_ray.exclude = exclude
	return get_world_3d().direct_space_state.intersect_ray(_ray)


func _gravity() -> Vector3:
	var strength: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	var way: Vector3 = ProjectSettings.get_setting("physics/3d/default_gravity_vector", Vector3.DOWN)
	return way * strength
