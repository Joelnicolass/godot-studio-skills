@tool
@icon("res://addons/grid_kit/icons/grid_view_3d.svg")
class_name GridView3D
extends Node3D

## Draws its parent `GridBoard` in 3D: one scene per cell, picked from `tiles` by the cell's `value_key` value (for
## example `&"terrain"` → `&"forest"`). It redraws a cell when that value changes and the cells that came or went when
## the board is `rebuilt`. A click or a tap that does not drag reports the cell under it (`cell_clicked`); the pointer
## moving over a new cell reports it too (`cell_hovered`). Picking needs no colliders: the ray from the camera meets
## the board plane or, on a board with heights (`GridBoard.height_key`), the first cell that stands in its way. Each
## tile sits on its cell's center, at its height, before it enters the tree, and `tile_created` hands it to you first
## (give it its cell there); `drawn` says every tile is in place. A cell whose height changes moves its tile.

## The player clicked or tapped `cell` (a press and release that moved less than `click_max_drag_px`).
signal cell_clicked(cell: Vector2i)
## The pointer is now over `cell` (`CellGrid.NO_CELL` when it left the board).
signal cell_hovered(cell: Vector2i)
## A tile for `cell` was made and placed on the cell's center. It is not in the tree yet: what you set on it here (its
## cell, its data) is already there in its `_ready`.
signal tile_created(cell: Vector2i, tile: Node3D)
## The tiles match the board again: after the board was rebuilt, `tiles`, `default_tile` or `value_key` changed, or
## `redraw()`. A single cell redrawn by a value change emits only `tile_created`.
signal drawn

const HeightPick := preload("res://addons/grid_kit/nodes/grid_height_pick.gd")

## One scene per value of `value_key`. A cell whose value has no scene uses `default_tile`.
@export var tiles: Dictionary[StringName, PackedScene] = {}:
	set(value):
		tiles = value
		_queue_redraw()
## The scene for a cell whose value is not in `tiles` (or has no value). Empty: nothing is drawn there.
@export var default_tile: PackedScene:
	set(value):
		default_tile = value
		_queue_redraw()
## Which value of a cell chooses its scene.
@export var value_key: StringName = &"terrain":
	set(value):
		value_key = value
		_queue_redraw()
## Off: clicks, taps and hover are ignored (a modal is open, the camera is busy).
@export var input_enabled := true
## A press that travels more than this before release is a drag (the camera's), not a click.
@export_range(0.0, 64.0, 0.5, "suffix:px") var click_max_drag_px := 6.0
## The camera used for picking. Empty: the viewport's current camera.
@export var camera: Camera3D

## The cell the pointer is over (`CellGrid.NO_CELL` when none).
var hovered_cell := CellGrid.NO_CELL

var _tiles_by_cell: Dictionary[Vector2i, Node3D] = {}
var _scenes_by_cell: Dictionary[Vector2i, PackedScene] = {}
var _board: GridBoard
var _press_at := Vector2.INF
var _flush_queued := false
var _full_redraw := false
var _height_pick := HeightPick.new()


func _enter_tree() -> void:
	_board = get_parent() as GridBoard
	_height_pick.invalidate()
	if _board != null:
		if not _board.rebuilt.is_connected(_queue_sync):
			_board.rebuilt.connect(_queue_sync)
		if not _board.cell_changed.is_connected(_on_cell_changed):
			_board.cell_changed.connect(_on_cell_changed)
	_queue_redraw()


func _exit_tree() -> void:
	if _board != null:
		if _board.rebuilt.is_connected(_queue_sync):
			_board.rebuilt.disconnect(_queue_sync)
		if _board.cell_changed.is_connected(_on_cell_changed):
			_board.cell_changed.disconnect(_on_cell_changed)
	_board = null


## The board this view draws (its parent), or null.
func board() -> GridBoard:
	return _board


## Draws every cell again now.
func redraw() -> void:
	_full_redraw = false
	for tile: Node3D in _tiles_by_cell.values():
		if is_instance_valid(tile):
			tile.queue_free()
	_tiles_by_cell.clear()
	_scenes_by_cell.clear()
	_sync()


## The tile node drawn at `cell`, or null.
func tile_at(cell: Vector2i) -> Node3D:
	return _tiles_by_cell.get(cell)


## The board cell under a screen point, or `CellGrid.NO_CELL`.
func cell_at_screen(screen_point: Vector2) -> Vector2i:
	var eye := camera if camera != null else get_viewport().get_camera_3d()
	if eye == null:
		return CellGrid.NO_CELL
	return cell_at_ray(eye.project_ray_origin(screen_point), eye.project_ray_normal(screen_point))


## The cell where a ray (in world space) meets the board plane, or `CellGrid.NO_CELL` when it misses the plane. With
## `on_board_only` off it also answers for a cell that is not on the board (to add cells next to it). On a board with
## heights each cell is a column up to its height (a cell off the board has height 0), and the answer is the first
## column the ray meets, by its top or by its side: a tall cell in front hides the low one behind it.
func cell_at_ray(origin: Vector3, direction: Vector3, on_board_only := true) -> Vector2i:
	if _board == null or not is_inside_tree():
		return CellGrid.NO_CELL
	if _board.height_key != &"":
		var to_board := global_transform.affine_inverse()
		var cell := _height_pick.pick(_board, to_board * origin, to_board.basis * direction)
		return cell if not on_board_only or _board.has_cell(cell) else CellGrid.NO_CELL
	var plane := Plane(global_basis.y.normalized(), global_position)
	var hit: Variant = plane.intersects_ray(origin, direction)
	if hit == null:
		return CellGrid.NO_CELL
	var point := to_local(hit as Vector3)
	return _board.position_to_cell(point) if on_board_only else _board.position_to_any_cell(point)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not input_enabled:
		return
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		_on_press(button.pressed, button.position)
		return
	var touch := event as InputEventScreenTouch
	if touch != null and touch.index == 0:
		_on_press(touch.pressed, touch.position)
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		_hover(motion.position)


func _on_press(pressed: bool, at: Vector2) -> void:
	if pressed:
		_press_at = at
		return
	if _press_at == Vector2.INF:
		return
	var travelled := _press_at.distance_to(at)
	_press_at = Vector2.INF
	if travelled > click_max_drag_px:
		return
	var cell := cell_at_screen(at)
	if cell != CellGrid.NO_CELL:
		cell_clicked.emit(cell)


func _hover(at: Vector2) -> void:
	var cell := cell_at_screen(at)
	if cell != hovered_cell:
		hovered_cell = cell
		cell_hovered.emit(cell)


# Every tile again (the tiles or the key changed).
func _queue_redraw() -> void:
	_full_redraw = true
	_queue_flush()


# The board got or lost cells, or places them somewhere else: only the cells that came or went are made or freed,
# and the others move.
func _queue_sync() -> void:
	_height_pick.invalidate()
	_queue_flush()


func _queue_flush() -> void:
	if _flush_queued or not is_inside_tree():
		return
	_flush_queued = true
	_flush.call_deferred()
	update_configuration_warnings()


func _flush() -> void:
	_flush_queued = false
	if _full_redraw:
		redraw()
	else:
		_sync()


# Brings the tiles in line with the board: frees the tiles of cells that are gone, draws the missing ones, replaces a
# tile whose scene changed and moves the rest to where the board puts them now.
func _sync() -> void:
	if _board == null:
		for tile: Node3D in _tiles_by_cell.values():
			if is_instance_valid(tile):
				tile.queue_free()
		_tiles_by_cell.clear()
		_scenes_by_cell.clear()
		drawn.emit()
		return
	var wanted := _board.cells()
	var present: Dictionary[Vector2i, bool] = {}
	for cell in wanted:
		present[cell] = true
	for cell: Vector2i in _tiles_by_cell.keys():
		if not present.has(cell):
			_free_tile(cell)
	for cell in wanted:
		var scene := _scene_for(cell)
		if _tiles_by_cell.has(cell):
			if _scenes_by_cell.get(cell) == scene:
				_tiles_by_cell[cell].position = _board.cell_to_position(cell)
				continue
			_free_tile(cell)
		_draw_cell(cell, scene)
	drawn.emit()


func _on_cell_changed(cell: Vector2i, key: StringName, _value: Variant) -> void:
	if key == _board.height_key:
		_height_pick.widen(_board.cell_height(cell))
		if _tiles_by_cell.has(cell):
			_tiles_by_cell[cell].position = _board.cell_to_position(cell)
	if key != value_key:
		return
	var scene := _scene_for(cell)
	if _tiles_by_cell.has(cell):
		if _scenes_by_cell.get(cell) == scene:
			return
		_free_tile(cell)
	_draw_cell(cell, scene)


func _scene_for(cell: Vector2i) -> PackedScene:
	var kind: Variant = _board.get_value(cell, value_key)
	return tiles.get(StringName(str(kind)), default_tile) if kind != null else default_tile


func _free_tile(cell: Vector2i) -> void:
	var old: Node3D = _tiles_by_cell.get(cell)
	if old != null and is_instance_valid(old):
		old.queue_free()
	_tiles_by_cell.erase(cell)
	_scenes_by_cell.erase(cell)


func _draw_cell(cell: Vector2i, scene: PackedScene) -> void:
	if scene == null:
		return
	var tile := scene.instantiate() as Node3D
	if tile == null:
		push_error("GridView3D: a tile scene must have a Node3D root")
		return
	tile.position = _board.cell_to_position(cell)
	_tiles_by_cell[cell] = tile
	_scenes_by_cell[cell] = scene
	tile_created.emit(cell, tile)
	add_child(tile)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not get_parent() is GridBoard:
		warnings.append("GridView3D draws its parent: make it a child of a GridBoard.")
	if tiles.is_empty() and default_tile == null:
		warnings.append("No tile scenes: fill tiles (one per value of value_key) or default_tile.")
	return warnings
