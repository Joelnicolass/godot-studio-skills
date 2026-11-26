@tool
@icon("res://addons/grid_kit/icons/grid_fog.svg")
class_name GridFog
extends Node3D

## What each player knows of the board its parent `GridView3D` draws, and the fog that shows it. It owns a `CellFog`,
## or shows the one your game's rules keep (`use_fog`). Every call goes to the fog: `see`, `reveal`, `explore`,
## `clear_visible`, `state`; `see_around` makes visible what is within a few steps of some cells (what a unit sees),
## and can let some cells block the view. It draws the fog of one observer, `shown_observer`: a hidden cell has its
## tile hidden under a dark cap, an explored cell has its tile darkened (with a `material_overlay` on its meshes), a
## visible cell shows as it is; `fade_time` makes the change gradual. What the game puts on the board (units, cities)
## it shows or hides itself with `sees`. In the editor the fog is not drawn, so the map stays in sight and can be
## painted; **Preview** shows it for a moment.

## These cells of `observer` are VISIBLE now and were not before.
signal revealed(observer: int, cells: Array[Vector2i])
## These cells of `observer` were VISIBLE and are EXPLORED now: seen before, not now. `explored` follows with them.
signal faded(observer: int, cells: Array[Vector2i])
## These cells of `observer` are EXPLORED now and were not before: they faded from view, or `explore` made them known.
signal explored(observer: int, cells: Array[Vector2i])
## Every cell of `observer` is HIDDEN again (`clear`, `clear_observer`).
signal cleared(observer: int)
## The tile of `cell` was hidden under the fog and shows now (its cell was revealed or explored), already visible:
## animate it here (grow it, fade it in).
signal tile_shown(cell: Vector2i, tile: Node3D)
## It shows another fog now (`use_fog`, `use_own_fog`): read every state again.
signal rebuilt

## Whose fog is drawn: a player's seat or a team, the same number from 0 up that you pass to `see`. -1: nobody's, the
## whole board shows (a spectator, a replay).
@export var shown_observer := 0:
	set(value):
		shown_observer = value
		_queue_full()
## The cap over a cell nobody told this observer about. Its tile is hidden under it. Transparent: no cap.
@export var hidden_color := Color(0.05, 0.06, 0.08, 1.0):
	set(value):
		hidden_color = value
		if _cap_material != null:
			_cap_material.albedo_color = value
		_queue_full()
## Laid over the meshes of the tile of a cell seen before and not now: dark and half transparent darkens it.
@export var explored_color := Color(0.0, 0.0, 0.03, 0.55):
	set(value):
		explored_color = value
		if _dim_material != null:
			_dim_material.albedo_color = value
## Seconds a cell takes to change: the veil fades in when it stops being seen and out when it is seen again, and a
## revealed tile comes out of the dark. 0: at once. A cell that becomes hidden is hidden at once; switching
## `shown_observer` is always at once.
@export_range(0.0, 2.0, 0.01, "or_greater", "suffix:s") var fade_time := 0.0
## How high above its cell the cap floats.
@export_range(0.0, 1.0, 0.001, "or_greater") var lift := 0.01:
	set(value):
		lift = value
		_queue_full()
## Shows the fog in the editor for a few seconds, as it would look: the middle of the board visible, a ring around it
## explored, the rest hidden. Nothing is saved.
@export_tool_button("Preview", "Visible") var preview_button := _preview

## The fog this node shows.
var fog: CellFog:
	get:
		if _fog == null:
			_set_fog(CellFog.new())
		return _fog

var _fog: CellFog
var _view: GridView3D
var _board: GridBoard
var _caps := MultiMeshInstance3D.new()
var _cap_mesh := ArrayMesh.new()
var _cap_key := ""
var _cap_material: StandardMaterial3D
var _dim_material: StandardMaterial3D
# What is drawn now, per board cell: its state, the cells under a cap, the tiles this node hid (by instance id) and the
# veils over darkened tiles. All of it is given back as it was.
var _drawn: Dictionary[Vector2i, int] = {}
var _capped: Dictionary[Vector2i, bool] = {}
var _hidden_tiles: Dictionary[Vector2i, int] = {}
var _veils: Dictionary[Vector2i, _Veil] = {}
# Cells to draw again on the next pass, or all of them.
var _dirty: Dictionary[Vector2i, bool] = {}
var _full := true
var _refresh_queued := false
var _preview_fog: CellFog


# The veil over one tile: its meshes, the overlay each had before, and the fade running on it.
class _Veil:
	var tile_id := 0
	var mesh_ids: Array[int] = []
	var before: Array[Material] = []
	var tween: Tween


func _init() -> void:
	_cap_material = StandardMaterial3D.new()
	_cap_material.albedo_color = hidden_color
	_cap_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cap_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cap_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_dim_material = StandardMaterial3D.new()
	_dim_material.albedo_color = explored_color
	_dim_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dim_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _cap_mesh
	_caps.multimesh = multimesh
	_caps.material_override = _cap_material
	_caps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_caps, false, INTERNAL_MODE_FRONT)


func _enter_tree() -> void:
	_view = get_parent() as GridView3D
	_board = _view.board() if _view != null else null
	if _view != null and not _view.drawn.is_connected(_queue_full):
		_view.drawn.connect(_queue_full)
		_view.tile_created.connect(_on_tile_created)
	if _board != null and not _board.rebuilt.is_connected(_queue_full):
		_board.rebuilt.connect(_queue_full)
		_board.cell_changed.connect(_on_cell_changed)
	_queue_full()


func _exit_tree() -> void:
	_give_back_all()
	if _view != null and _view.drawn.is_connected(_queue_full):
		_view.drawn.disconnect(_queue_full)
		_view.tile_created.disconnect(_on_tile_created)
	if _board != null and _board.rebuilt.is_connected(_queue_full):
		_board.rebuilt.disconnect(_queue_full)
		_board.cell_changed.disconnect(_on_cell_changed)
	_view = null
	_board = null


## Shows `other` instead of this node's own fog (your game's rules keep it). Emits `rebuilt`.
func use_fog(other: CellFog) -> void:
	_set_fog(other)


## Goes back to a fog of its own, where every cell is hidden. Emits `rebuilt`.
func use_own_fog() -> void:
	_set_fog(CellFog.new())


## What `observer` knows of `cell`: `CellFog.State.HIDDEN`, `EXPLORED` or `VISIBLE`.
func state(observer: int, cell: Vector2i) -> CellFog.State:
	return fog.state(observer, cell)


## `observer` sees `cell` now: show what the game has on it.
func sees(observer: int, cell: Vector2i) -> bool:
	return fog.sees(observer, cell)


## `observer` has seen `cell` at some time, or sees it now.
func knows(observer: int, cell: Vector2i) -> bool:
	return fog.knows(observer, cell)


## `observer` sees exactly `cells` now; what it saw and no longer does is EXPLORED. The usual call after every move.
func see(observer: int, cells: Array[Vector2i]) -> void:
	fog.see(observer, cells)


## `observer` sees exactly the board cells within `radius` steps of `cells` (its units, its towns); what it saw and no
## longer does is EXPLORED. With `blocks` (`func(cell: Vector2i) -> bool`: a mountain, a forest) a cell that blocks
## hides what is behind it, seen from each of `cells` (`CellGrid.cells_visible_from`).
func see_around(observer: int, cells: Array[Vector2i], radius := 1, blocks: Callable = Callable()) -> void:
	if _board == null:
		push_error("GridFog: make it a child of a GridView3D under a GridBoard to use see_around")
		return
	if not blocks.is_valid():
		fog.see(observer, _board.grid.cells_near(cells, radius))
		return
	var seen: Dictionary[Vector2i, bool] = {}
	for center in cells:
		for cell in _board.grid.cells_visible_from(center, radius, blocks):
			seen[cell] = true
	var list: Array[Vector2i] = []
	list.assign(seen.keys())
	fog.see(observer, list)


## `observer` sees `cells` now, as well as what it saw already.
func reveal(observer: int, cells: Array[Vector2i]) -> void:
	fog.reveal(observer, cells)


## `observer` knows the terrain of `cells` without seeing them now (a region turned face up, a map).
func explore(observer: int, cells: Array[Vector2i]) -> void:
	fog.explore(observer, cells)


## Nothing is VISIBLE to `observer` any more: what it saw is EXPLORED.
func clear_visible(observer: int) -> void:
	fog.clear_visible(observer)


## Every cell of every observer is HIDDEN again, as at the start.
func clear() -> void:
	fog.clear()


## Every cell of `observer` is HIDDEN again; the others keep what they know.
func clear_observer(observer: int) -> void:
	fog.clear_observer(observer)


## The cells `observer` sees now, sorted by row and then column.
func visible_cells(observer: int) -> Array[Vector2i]:
	return fog.visible_cells(observer)


## The cells `observer` saw before and does not see now, sorted by row and then column.
func explored_cells(observer: int) -> Array[Vector2i]:
	return fog.explored_cells(observer)


## Every observer's fog as plain data, for a save or a replay check (`CellFog.to_dict`).
func to_dict() -> Dictionary:
	return fog.to_dict()


func _set_fog(next: CellFog) -> void:
	if _fog != null:
		_fog.revealed.disconnect(_on_revealed)
		_fog.faded.disconnect(_on_faded)
		_fog.explored.disconnect(_on_explored)
		_fog.cleared.disconnect(_on_cleared)
	_fog = next
	_fog.revealed.connect(_on_revealed)
	_fog.faded.connect(_on_faded)
	_fog.explored.connect(_on_explored)
	_fog.cleared.connect(_on_cleared)
	rebuilt.emit()
	_queue_full()


func _on_revealed(observer: int, cells: Array[Vector2i]) -> void:
	revealed.emit(observer, cells)
	_queue_cells(observer, cells)


func _on_faded(observer: int, cells: Array[Vector2i]) -> void:
	faded.emit(observer, cells)
	_queue_cells(observer, cells)


func _on_explored(observer: int, cells: Array[Vector2i]) -> void:
	explored.emit(observer, cells)
	_queue_cells(observer, cells)


func _on_cleared(observer: int) -> void:
	cleared.emit(observer)
	if observer == shown_observer:
		_queue_full()


func _on_tile_created(cell: Vector2i, _tile: Node3D) -> void:
	_dirty[cell] = true
	_queue_refresh()


func _on_cell_changed(_cell: Vector2i, key: StringName, _value: Variant) -> void:
	if _board != null and key == _board.height_key:
		_queue_full()


func _queue_cells(observer: int, cells: Array[Vector2i]) -> void:
	if observer != shown_observer:
		return
	for cell in cells:
		_dirty[cell] = true
	_queue_refresh()


func _queue_full() -> void:
	_full = true
	_queue_refresh()


# Many changes in a frame make one pass, over the cells that changed only (or over the board when it is new).
func _queue_refresh() -> void:
	if _refresh_queued or not is_inside_tree():
		return
	_refresh_queued = true
	_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	var shown := _drawn_fog()
	if shown == null or _board == null or _view == null:
		_give_back_all()
		_dirty.clear()
		_full = false
		return
	var observer := shown_observer if shown == _fog else 0
	var instant := _full
	var cells: Array[Vector2i] = []
	if _full:
		cells = _board.cells()
		for cell: Vector2i in _drawn.keys():
			if not _board.has_cell(cell):
				_forget(cell)
	else:
		for cell: Vector2i in _dirty:
			if _board.has_cell(cell):
				cells.append(cell)
	_full = false
	_dirty.clear()
	_fit_cap_mesh()
	for cell in cells:
		_draw_cell(cell, shown.state(observer, cell), instant)
	_place_caps()


# The fog to draw now: the preview in the editor, nothing else in the editor, the shown observer's in the game.
func _drawn_fog() -> CellFog:
	if Engine.is_editor_hint():
		return _preview_fog
	if shown_observer < 0:
		return null
	return fog


func _draw_cell(cell: Vector2i, cell_state: int, instant: bool) -> void:
	var tile := _view.tile_at(cell)
	var before: int = _drawn.get(cell, -1)
	# The view drew this cell again: the old tile is gone, and what was done to it with it.
	if _tile_changed(cell, tile):
		_forget(cell)
		before = -1
	_drawn[cell] = cell_state
	if cell_state == CellFog.State.HIDDEN:
		_capped[cell] = true
		_drop_veil(cell)
		if tile != null and tile.visible and not _hidden_tiles.has(cell):
			_hidden_tiles[cell] = tile.get_instance_id()
			tile.visible = false
		return
	_capped.erase(cell)
	var was_hidden := _hidden_tiles.has(cell)
	if was_hidden:
		_hidden_tiles.erase(cell)
		if tile != null:
			tile.visible = true
	if tile == null:
		return
	var target := explored_color if cell_state == CellFog.State.EXPLORED else Color(explored_color, 0.0)
	var start := target
	if not instant and fade_time > 0.0 and before != -1:
		if before == CellFog.State.HIDDEN:
			start = hidden_color
		elif before == CellFog.State.EXPLORED:
			start = explored_color
		else:
			start = Color(explored_color, 0.0)
	_shade(cell, tile, start, target)
	if was_hidden:
		tile_shown.emit(cell, tile)


func _tile_changed(cell: Vector2i, tile: Node3D) -> bool:
	var tile_id := tile.get_instance_id() if tile != null else 0
	if _hidden_tiles.has(cell) and _hidden_tiles[cell] != tile_id:
		return true
	return _veils.has(cell) and _veils[cell].tile_id != tile_id


# Lays the veil over the tile's meshes, from `from` to `to` in `fade_time` (or at once when they are the same). A veil
# that ends transparent goes away and gives every mesh its overlay back.
func _shade(cell: Vector2i, tile: Node3D, from: Color, to: Color) -> void:
	if from.a <= 0.0 and to.a <= 0.0:
		_drop_veil(cell)
		return
	var veil: _Veil = _veils.get(cell)
	if veil == null:
		veil = _Veil.new()
		veil.tile_id = tile.get_instance_id()
		for mesh in _geometry_of(tile):
			veil.mesh_ids.append(mesh.get_instance_id())
			veil.before.append(mesh.material_overlay)
		_veils[cell] = veil
	if veil.tween != null:
		veil.tween.kill()
		veil.tween = null
	if from.is_equal_approx(to):
		_lay(veil, _dim_material)
		return
	var fading := _dim_material.duplicate() as StandardMaterial3D
	fading.albedo_color = from
	_lay(veil, fading)
	veil.tween = create_tween()
	veil.tween.tween_property(fading, "albedo_color", to, fade_time)
	veil.tween.finished.connect(_on_fade_done.bind(cell, veil))


func _on_fade_done(cell: Vector2i, veil: _Veil) -> void:
	if _veils.get(cell) != veil:
		return
	veil.tween = null
	if _drawn.get(cell, -1) == CellFog.State.EXPLORED:
		_lay(veil, _dim_material)
	else:
		_drop_veil(cell)


func _lay(veil: _Veil, material: Material) -> void:
	for mesh_id in veil.mesh_ids:
		var mesh := instance_from_id(mesh_id) as GeometryInstance3D
		if mesh != null:
			mesh.material_overlay = material


func _drop_veil(cell: Vector2i) -> void:
	var veil: _Veil = _veils.get(cell)
	if veil == null:
		return
	_veils.erase(cell)
	if veil.tween != null:
		veil.tween.kill()
	for i in veil.mesh_ids.size():
		var mesh := instance_from_id(veil.mesh_ids[i]) as GeometryInstance3D
		if mesh != null:
			mesh.material_overlay = veil.before[i]


# Gives the cell's tile back as it was and forgets the cell.
func _forget(cell: Vector2i) -> void:
	_drop_veil(cell)
	if _hidden_tiles.has(cell):
		var tile := instance_from_id(_hidden_tiles[cell]) as Node3D
		_hidden_tiles.erase(cell)
		if tile != null:
			tile.visible = true
	_drawn.erase(cell)
	_capped.erase(cell)


func _give_back_all() -> void:
	for cell: Vector2i in _drawn.keys():
		_forget(cell)
	for cell: Vector2i in _veils.keys():
		_drop_veil(cell)
	for cell: Vector2i in _hidden_tiles.keys():
		_forget(cell)
	_capped.clear()
	_place_caps()


func _place_caps() -> void:
	var multimesh := _caps.multimesh
	if hidden_color.a <= 0.0 or _board == null:
		multimesh.instance_count = 0
		return
	var cells: Array[Vector2i] = []
	cells.assign(_capped.keys())
	multimesh.instance_count = cells.size()
	for i in cells.size():
		multimesh.set_instance_transform(i, Transform3D(Basis(), _cap_origin(cells[i])))


# Where the cap of `cell` lies: `lift` above the top of the cell, at its height.
func _cap_origin(cell: Vector2i) -> Vector3:
	return _board.cell_to_position(cell) + Vector3.UP * lift


static func _geometry_of(tile: Node) -> Array[GeometryInstance3D]:
	var list: Array[GeometryInstance3D] = []
	if tile is GeometryInstance3D:
		list.append(tile as GeometryInstance3D)
	for child in tile.get_children():
		list.append_array(_geometry_of(child))
	return list


# The cap is the outline of one cell; it is made again, in place, only when the shape or the size change.
func _fit_cap_mesh() -> void:
	var key := "%s|%s" % [_board.grid.shape_name(), _board.cell_size]
	if key == _cap_key:
		return
	_cap_key = key
	var outline := _board.grid.cell_outline(_board.cell_size)
	var vertices := PackedVector3Array()
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		vertices.append_array([Vector3.ZERO, Vector3(b.x, 0.0, b.y), Vector3(a.x, 0.0, a.y)])
	_cap_mesh.clear_surfaces()
	if vertices.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	_cap_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


# In the editor: the middle cell and its neighbors visible, the next ring explored, the rest hidden, for 4 seconds.
func _preview() -> void:
	if _board == null or _board.cells().is_empty():
		return
	var middle := _board.grid.center_cell()
	var preview := CellFog.new()
	preview.explore(0, _board.cells_in_range(middle, 2))
	preview.reveal(0, _board.cells_in_range(middle, 1))
	_preview_fog = preview
	_full = true
	_refresh()
	await get_tree().create_timer(4.0).timeout
	if _preview_fog == preview:
		_preview_fog = null
		_full = true
		_refresh()


func _get_configuration_warnings() -> PackedStringArray:
	if not get_parent() is GridView3D:
		return PackedStringArray(["GridFog draws over the tiles of its parent: make it a child of a GridView3D."])
	return PackedStringArray()
