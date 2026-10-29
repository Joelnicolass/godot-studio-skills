@tool
class_name GrassField3D
extends Node3D

## Grass around the camera, drawn on the GPU. Set `ground` (where it grows and how high the ground
## is: press «Bake ground» to read it from the colliders), `look` (the blades), `quality` (how many
## and how far) and `wind` (shared with any shader that reads it). The blades stand in square cells
## around where the camera looks; a cell is one MultiMeshInstance3D per kind of blade (internal,
## never saved), each showing one of a few shared MultiMeshes. Crossing a cell only moves cells,
## nothing is rebuilt, and each cell's bounds fit its ground so the renderer culls it. A new look,
## or new values in it, are uniforms only (a biome, a god's palette); only other meshes build the
## meshes again. `enabled` off frees every cell (the wind still blows for the rest of the world;
## it moves with this node's processing, so it holds while the tree is paused, by default).
## Nothing is drawn headless or on a dedicated server. In the editor it follows the viewport's
## camera with `editor_radius`. The ring centres on `center` when set (the unit an RTS camera
## follows), else on where the camera looks, never farther ahead of it than it is high (so a camera
## at eye height keeps grass at its feet). Keep this node at the origin.

## The cells are hidden headless and on dedicated servers; tests set this to draw anyway.
static var draw_anywhere := false

const SHADER := preload("grass.gdshader")
## The same with alpha scissor, for a kind with `alpha_scissor` above 0.
const CUT_SHADER := preload("grass_cut.gdshader")
## How often the clearings' nodes are read again (s).
const CLEARINGS_EVERY := 0.5
const MAX_CLEARINGS := 48
const MAX_STAMPS := 48

## Where grass grows and how high the ground is (GrassGround).
@export var ground: GrassGround:
	set(value):
		_watch(ground, value, _on_ground_changed)
		if ground != null and ground.area_changed.is_connected(_on_area_changed):
			ground.area_changed.disconnect(_on_area_changed)
		ground = value
		if ground != null:
			ground.area_changed.connect(_on_area_changed)
		_reset()
## What the blades look like (GrassLook). Another one, or new values, take effect at once.
@export var look: GrassLook:
	set(value):
		_watch(look, value, _apply_look)
		look = value
		_apply_look()
## How many blades and how far (GrassQuality).
@export var quality: GrassQuality:
	set(value):
		_watch(quality, value, _reset)
		quality = value
		_reset()
## The world's wind (GrassWind): the field ticks it every frame, and every shader that includes
## grass_wind.gdshaderinc reads it. Null = calm.
@export var wind: GrassWind:
	set(value):
		wind = value
		_reset()
## Off frees every cell (an options menu's switch); on builds them again.
@export var enabled := true:
	set(value):
		enabled = value
		_reset()
## «Bake ground»: reads the ground's heights from the colliders under `ground.area`.
@export_tool_button("Bake ground", "Bake") var bake_button := _bake_in_editor

@export_group("Clearings")
## No grass around the nodes of these groups. GrassClear3D nodes clear too.
@export var clearings: Array[GrassClearing] = []

@export_group("Trampling")
## Nodes of this group bend the grass around them (units, the player). Empty = none.
@export var trample_group: StringName = &""
## How wide each one tramples, unless the node says otherwise with a property or meta
## `grass_trample_radius` (a dragon and a gnome in the same group).
@export_range(0.05, 10.0, 0.05, "suffix:m") var trample_radius := 0.7

@export_group("Camera")
## The camera the grass follows. Empty = the viewport's current camera.
@export var camera: Camera3D
## The grass centres on this node (the unit the camera follows). Empty = where the camera looks.
@export var center: Node3D

@export_group("Editor")
## Draw the grass in the editor, around the 3D view's camera.
@export var editor_preview := true:
	set(value):
		editor_preview = value
		_reset()
## How far it reaches in the editor (m): less than in play, so the editor stays quick.
@export_range(4.0, 500.0, 1.0, "suffix:m") var editor_radius := 25.0:
	set(value):
		editor_radius = value
		_reset()

## What the field draws now (cells and blades, all and in view).
var stats := GrassStats.new()

## One material per kind of blade, and per kind one MultiMesh per tier.
var _materials: Array[ShaderMaterial] = []
var _tier_meshes: Array[Array] = []
var _kinds: Array[GrassMesh] = []
var _build_key := ""
var _quality: GrassQuality
## A cell: a Node3D with one MultiMeshInstance3D per kind.
var _cells: Dictionary[Vector2i, Node3D] = {}
var _tiers: Dictionary[Vector2i, int] = {}
var _bounds: Dictionary[Vector2i, AABB] = {}
var _pool: Array[Node3D] = []
var _center := Vector2.INF
var _ring_center := Vector2.INF
var _clearings_timer := 0.0
var _textures_dirty := true


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if ground == null:
		out.append("Set ground (a GrassGround): where grass grows.")
	elif ground.data == null:
		out.append("The ground is flat at flat_height: press «Bake ground» to read its heights.")
	if ground != null and ground.bake_cost().y > 64.0:
		var cost := ground.bake_cost()
		out.append(
			(
				"Baking this ground casts %d million rays and keeps %d MB: raise texel_size, or "
				+ "write the heights with set_heights()."
			)
			% [roundi(cost.x / 1000000.0), roundi(cost.y)]
		)
	if look == null:
		out.append("Set look (a GrassLook).")
	if quality == null:
		out.append("Set quality (a GrassQuality, or GrassQuality.preset()).")
	if is_inside_tree() and not global_transform.is_equal_approx(Transform3D.IDENTITY):
		out.append("Keep this node at the origin with no rotation or scale.")
	return out


func _ready() -> void:
	set_notify_transform(true)
	_reset()


func _exit_tree() -> void:
	_free_cells()


## True when this process can draw grass: not headless, not a dedicated server.
func can_draw() -> bool:
	if draw_anywhere:
		return true
	return DisplayServer.get_name() != "headless" and not OS.has_feature("dedicated_server")


## Reads the ground's heights again from the colliders within `radius` of `at`: a crater, a mound.
## Only the cells there change.
func ground_changed(at: Vector3, radius: float) -> void:
	if ground == null or not is_inside_tree():
		return
	var rect := Rect2(at.x - radius, at.z - radius, radius * 2.0, radius * 2.0)
	ground.bake(get_world_3d().direct_space_state, rect)


## Reads every ground height again from the colliders (`ground.area`).
func bake_ground() -> int:
	if ground == null or not is_inside_tree():
		return 0
	return ground.bake(get_world_3d().direct_space_state)


## Reads the clearings' nodes now instead of within half a second.
func refresh_clearings() -> void:
	_clearings_timer = CLEARINGS_EVERY


func _process(delta: float) -> void:
	if wind != null:
		wind.tick(delta)
	if not _active():
		return
	var view := _camera()
	if view == null:
		return
	if _textures_dirty:
		_apply_ground()
	_center = _focus(view)
	_set_all(&"field_center", _center)
	_write_meeting()
	if _ring_center == Vector2.INF or _ring_center.distance_to(_center) > _quality.ring_margin():
		_update_ring(_center)
	_clearings_timer += delta
	if _clearings_timer >= CLEARINGS_EVERY:
		_clearings_timer = 0.0
		_apply_clearings()
	_apply_stamps()
	_count(view)


func _active() -> bool:
	if not enabled or ground == null or look == null or quality == null or not is_inside_tree():
		return false
	if Engine.is_editor_hint():
		return editor_preview
	return can_draw()


## Builds the meshes and the materials for the settings in force, and drops every cell.
func _reset() -> void:
	_free_cells()
	if not is_inside_tree():
		return
	GrassGlobals.declare()
	if wind == null:
		GrassWind.write_calm()
	else:
		wind.write()
	set_process(_active() or wind != null)
	_materials.clear()
	if not _active():
		stats = GrassStats.new()
		return
	_quality = quality
	if Engine.is_editor_hint() and editor_radius < quality.radius:
		_quality = quality.duplicate() as GrassQuality
		_quality.radius = editor_radius
		_quality.near_radius = minf(quality.near_radius, editor_radius)
	_kinds = look.kinds()
	_build_key = look.build_key()
	_tier_meshes = GrassBlades.tier_meshes(_quality, _kinds)
	for kind in _kinds:
		var material := ShaderMaterial.new()
		material.shader = CUT_SHADER if kind.alpha_scissor > 0.0 else SHADER
		_materials.append(material)
	_apply_quality()
	_apply_look()
	_apply_ground()
	_apply_clearings()


## Sets a uniform on every kind's material.
func _set_all(uniform: StringName, value: Variant) -> void:
	for material in _materials:
		material.set_shader_parameter(uniform, value)


## Where the drawn grass ends and the colour it fades to, for the game's ground
## (grass_ground.gdshaderinc).
func _write_meeting() -> void:
	var fade := look.fade_to_ground * _quality.radius
	var field := Vector4(_center.x, _center.y, _quality.radius, fade)
	RenderingServer.global_shader_parameter_set(&"grasskit_field", field)
	var grass := look.average_color()
	var colour := Vector4(grass.r, grass.g, grass.b, look.far_grass)
	RenderingServer.global_shader_parameter_set(&"grasskit_grass", colour)


func _free_cells() -> void:
	for cell in _cells.values():
		cell.queue_free()
	for cell in _pool:
		cell.queue_free()
	_cells.clear()
	_tiers.clear()
	_bounds.clear()
	_pool.clear()
	_ring_center = Vector2.INF


func _apply_quality() -> void:
	_set_all(&"radius", _quality.radius)
	_set_all(&"near_radius", _quality.near_radius)
	_set_all(&"far_density", _quality.far_density)
	_set_all(&"min_blade_pixels", _quality.min_blade_pixels)
	_set_all(&"near_fade", _quality.near_fade)
	_set_all(&"jitter", 1.0 / sqrt(_quality.density))
	_set_all(&"morph_ends", _quality.morph_ends())
	_set_all(&"morph_band", _quality.cell_size * 0.4)


## The look's uniforms on every material; other meshes in it build the field again.
func _apply_look() -> void:
	if _materials.is_empty() or look == null:
		return
	if look.build_key() != _build_key:
		_reset()
		return
	for index in _kinds.size():
		var material := _materials[index]
		var kind := _kinds[index]
		look.apply_to(material)
		material.set_shader_parameter(&"kind_size", kind.size)
		var height := kind.mesh.get_aabb().end.y if kind.mesh != null else 1.0
		material.set_shader_parameter(&"mesh_height", maxf(height, 0.001))
		material.set_shader_parameter(&"bend_from_color", kind.bend_from_color)
		material.set_shader_parameter(&"palette", kind.palette)
		material.set_shader_parameter(&"tint", kind.tint)
		material.set_shader_parameter(&"mask_map", kind.mask_texture)
		material.set_shader_parameter(&"albedo_map", kind.albedo_texture)
		material.set_shader_parameter(&"has_albedo", kind.albedo_texture != null)
		material.set_shader_parameter(&"normal_map", kind.normal_texture)
		material.set_shader_parameter(&"has_normal_map", kind.normal_texture != null)
		material.set_shader_parameter(&"orm_map", kind.orm_texture)
		material.set_shader_parameter(&"has_orm", kind.orm_texture != null)
		material.set_shader_parameter(&"alpha_scissor", kind.alpha_scissor)


func _apply_ground() -> void:
	_textures_dirty = false
	if _materials.is_empty() or ground == null:
		return
	_set_all(&"ground_data", ground.ground_texture())
	var fade := Vector2(cos(deg_to_rad(ground.slope_fade.x)), cos(deg_to_rad(ground.slope_fade.y)))
	_set_all(&"slope_fade_cos", fade)
	_set_all(&"density_map", ground.density_texture)
	_set_all(&"size_map", ground.size_texture)
	_set_all(&"has_size_map", ground.size_texture != null)
	_set_all(&"ground_colors", ground.color_texture)
	_set_all(&"has_ground_colors", ground.color_texture != null)
	var area := ground.area
	_set_all(&"ground_area", Vector4(area.position.x, area.position.y, area.size.x, area.size.y))


## Where the ring goes: `center` if set, else where the camera looks on the ground, but never
## farther ahead of the camera than 1.5 times its height above the ground. A high RTS camera centres
## on the middle of the screen; one at eye height keeps the grass around its feet.
func _focus(view: Camera3D) -> Vector2:
	if center != null and center.is_inside_tree():
		return Vector2(center.global_position.x, center.global_position.z)
	var eye := view.global_position
	var flat := Vector2(eye.x, eye.z)
	var forward := -view.global_basis.z
	var above := maxf(eye.y - ground.height_at(flat), 0.0)
	var reach := above * 1.5
	if forward.y < -0.01:
		var hit := eye + forward * (above / -forward.y)
		return flat + (Vector2(hit.x, hit.z) - flat).limit_length(reach)
	var ahead := Vector2(forward.x, forward.z)
	if ahead.length() < 0.001:
		return flat
	return flat + ahead.normalized() * minf(reach, _quality.radius * 0.25)


## Cells for a ring around `center`: new ones from the pool, the ones left behind back to it.
## A cell's tier is taken a little nearer than its nearest point, so the centre can move a quarter
## of a cell before the ring follows and every cell still holds the blades it must show.
func _update_ring(center: Vector2) -> void:
	_ring_center = center
	var size := _quality.cell_size
	var margin := _quality.ring_margin()
	var wanted := GrassCells.around(center, _quality.radius + margin, size)
	for key in _cells.keys():
		if not wanted.has(key):
			var gone := _cells[key]
			gone.visible = false
			_pool.append(gone)
			_cells.erase(key)
			_tiers.erase(key)
	for key in wanted:
		var tier := _quality.tier_at(maxf(wanted[key] - margin, 0.0))
		var cell: Node3D = _cells.get(key)
		if cell == null:
			cell = _pool.pop_back() if not _pool.is_empty() else _new_cell()
			_cells[key] = cell
			cell.position = Vector3(key.x * size, 0.0, key.y * size)
			var box := _bounds_of(key)
			for kind in cell.get_children():
				(kind as MultiMeshInstance3D).custom_aabb = box
			cell.visible = true
		if _tiers.get(key, -1) != tier:
			for index in _kinds.size():
				(cell.get_child(index) as MultiMeshInstance3D).multimesh = _tier_meshes[index][tier]
			_tiers[key] = tier


func _new_cell() -> Node3D:
	var cell := Node3D.new()
	for material in _materials:
		var kind := MultiMeshInstance3D.new()
		kind.material_override = material
		kind.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _quality.cast_shadows
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
		cell.add_child(kind)
	add_child(cell, false, Node.INTERNAL_MODE_BACK)
	return cell


## The cell's bounds in its own space: its ground's lowest to highest point plus the tallest blade
## standing, and room for a blade bent past the cell's edge.
func _bounds_of(key: Vector2i) -> AABB:
	if _bounds.has(key):
		return _bounds[key]
	var size := _quality.cell_size
	var biggest := 1.0
	for kind in _kinds:
		biggest = maxf(biggest, kind.size)
	var tallest := look.height_range.y * biggest * 2.4
	var span := ground.height_range_in(GrassCells.rect_of(key, size))
	var box := AABB(
		Vector3(-tallest, span.x - 0.1, -tallest),
		Vector3(size + tallest * 2.0, span.y - span.x + tallest + 0.2, size + tallest * 2.0)
	)
	_bounds[key] = box
	return box


func _apply_clearings() -> void:
	if _materials.is_empty() or not is_inside_tree():
		return
	var found := PackedVector4Array()
	for clearing in clearings:
		if clearing == null or clearing.group == &"":
			continue
		for node in get_tree().get_nodes_in_group(clearing.group):
			if node is Node3D and found.size() < MAX_CLEARINGS:
				var at := (node as Node3D).global_position
				found.append(Vector4(at.x, at.z, clearing.radius, clearing.soft))
	for node in get_tree().get_nodes_in_group(GrassClear3D.GROUP):
		var clear := node as GrassClear3D
		if clear != null and clear.is_visible_in_tree() and found.size() < MAX_CLEARINGS:
			var at := clear.global_position
			found.append(Vector4(at.x, at.z, clear.radius, clear.soft))
	_set_all(&"clearing_count", found.size())
	found.resize(MAX_CLEARINGS)
	_set_all(&"clearings", found)


## The trampling nodes nearest the field's centre, within its radius.
func _apply_stamps() -> void:
	if trample_group == &"":
		_set_all(&"stamp_count", 0)
		return
	var stamps := PackedVector4Array()
	for node in get_tree().get_nodes_in_group(trample_group):
		if node is Node3D:
			var at := (node as Node3D).global_position
			if Vector2(at.x, at.z).distance_to(_center) <= _quality.radius:
				stamps.append(Vector4(at.x, at.z, _trample_radius_of(node), 1.0))
	if stamps.size() > MAX_STAMPS:
		var by_distance := Array(stamps)
		by_distance.sort_custom(
			func(a: Vector4, b: Vector4) -> bool:
				var near_a := _center.distance_squared_to(Vector2(a.x, a.y))
				return near_a < _center.distance_squared_to(Vector2(b.x, b.y))
		)
		stamps = PackedVector4Array(by_distance.slice(0, MAX_STAMPS))
	_set_all(&"stamp_count", stamps.size())
	stamps.resize(MAX_STAMPS)
	_set_all(&"stamps", stamps)


## The node's own `grass_trample_radius` (property, then meta), else `trample_radius`.
func _trample_radius_of(node: Node) -> float:
	var own: Variant = node.get(&"grass_trample_radius")
	if own == null:
		own = node.get_meta(&"grass_trample_radius", trample_radius)
	return float(own)


## Counts the cells and blades, all of them and those whose bounds the camera sees.
func _count(view: Camera3D) -> void:
	var planes := view.get_frustum()
	var counted := GrassStats.new()
	counted.blades_by_kind.resize(_kinds.size())
	for key in _cells:
		var cell := _cells[key]
		var seen := _in_view(cell.global_transform * _bounds_of(key), planes)
		counted.cells += 1
		if seen:
			counted.cells_in_view += 1
		for index in cell.get_child_count():
			var blades := (cell.get_child(index) as MultiMeshInstance3D).multimesh.instance_count
			counted.blades += blades
			if seen:
				counted.blades_in_view += blades
				counted.blades_by_kind[index] += blades
				counted.draws += 1
	stats = counted


static func _in_view(box: AABB, planes: Array[Plane]) -> bool:
	for plane in planes:
		# The box corner farthest along the plane's normal: outside if even it is in front.
		var corner := box.position + Vector3(
			box.size.x if plane.normal.x < 0.0 else 0.0,
			box.size.y if plane.normal.y < 0.0 else 0.0,
			box.size.z if plane.normal.z < 0.0 else 0.0
		)
		if plane.is_point_over(corner):
			return false
	return true


func _camera() -> Camera3D:
	if Engine.is_editor_hint():
		# Looked up by name: EditorInterface is not in an exported game.
		var editor := Engine.get_singleton(&"EditorInterface")
		if editor == null:
			return null
		var viewport: SubViewport = editor.call(&"get_editor_viewport_3d", 0)
		return viewport.get_camera_3d() if viewport != null else null
	if camera != null:
		return camera
	return get_viewport().get_camera_3d()


func _on_ground_changed() -> void:
	_textures_dirty = true


## Part of the ground changed: the cells there take new bounds.
func _on_area_changed(rect: Rect2) -> void:
	_textures_dirty = true
	if _quality == null:
		return
	for key in _bounds.keys():
		if GrassCells.rect_of(key, _quality.cell_size).intersects(rect, true):
			_bounds.erase(key)
			if _cells.has(key):
				var box := _bounds_of(key)
				for kind in _cells[key].get_children():
					(kind as MultiMeshInstance3D).custom_aabb = box


func _bake_in_editor() -> void:
	if ground == null:
		push_error("%s: set ground first" % name)
		return
	var found := bake_ground()
	var scene := get_tree().edited_scene_root if Engine.is_editor_hint() else null
	var path := ground.resource_path
	if scene != null and (path.is_empty() or path.contains("::")):
		if scene.scene_file_path.is_empty():
			push_error("%s: save the scene first; the ground goes next to it" % name)
			return
		path = scene.scene_file_path.get_basename() + "_grass_ground.res"
	if not path.is_empty() and not path.contains("::"):
		var err := ResourceSaver.save(ground, path)
		if err != OK:
			push_error("%s: could not save %s (%s)" % [name, path, error_string(err)])
			return
		ground.take_over_path(path)
	var editor := Engine.get_singleton(&"EditorInterface")
	if editor != null:
		editor.call(&"mark_scene_as_unsaved")
	update_configuration_warnings()
	print("%s: ground baked, %d of %d texels hit (%s)" % [
		name, found, ground.texture_size().x * ground.texture_size().y, path
	])


## Keeps `callback` connected to the `changed` of the resource in force only.
func _watch(old: Resource, new: Resource, callback: Callable) -> void:
	if old != null and old.changed.is_connected(callback):
		old.changed.disconnect(callback)
	if new != null and not new.changed.is_connected(callback):
		new.changed.connect(callback)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		update_configuration_warnings()
