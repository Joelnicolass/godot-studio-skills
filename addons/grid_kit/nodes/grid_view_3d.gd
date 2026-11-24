@tool
class_name GridView3D
extends Node3D

## Draws its parent `GridBoard` in 3D: one scene per cell, picked from `tiles` by the cell's `value_key` value (for
## example `&"terrain"` → `&"forest"`). It redraws a cell when that value changes and the whole board on `rebuilt`.
## A click or a tap that does not drag reports the cell under it (`cell_clicked`); the pointer moving over a new cell
## reports it too (`cell_hovered`). Picking needs no colliders: the ray from the camera meets the board plane.

## The player clicked or tapped `cell` (a press and release that moved less than `click_max_drag_px`).
signal cell_clicked(cell: Vector2i)
## The pointer is now over `cell` (`HexGrid.NO_CELL` when it left the board).
signal cell_hovered(cell: Vector2i)

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

## The cell the pointer is over (`HexGrid.NO_CELL` when none).
var hovered_cell := HexGrid.NO_CELL

var _tiles_by_cell: Dictionary[Vector2i, Node3D] = {}
var _board: GridBoard
var _press_at := Vector2.INF
var _redraw_queued := false


func _enter_tree() -> void:
	_board = get_parent() as GridBoard
	if _board != null:
		if not _board.rebuilt.is_connected(_queue_redraw):
			_board.rebuilt.connect(_queue_redraw)
		if not _board.cell_changed.is_connected(_on_cell_changed):
			_board.cell_changed.connect(_on_cell_changed)
	_queue_redraw()


func _exit_tree() -> void:
	if _board != null:
		if _board.rebuilt.is_connected(_queue_redraw):
			_board.rebuilt.disconnect(_queue_redraw)
		if _board.cell_changed.is_connected(_on_cell_changed):
			_board.cell_changed.disconnect(_on_cell_changed)
	_board = null


## The board this view draws (its parent), or null.
func board() -> GridBoard:
	return _board


## Draws every cell again now.
func redraw() -> void:
	_redraw_queued = false
	for tile: Node3D in _tiles_by_cell.values():
		if is_instance_valid(tile):
			tile.queue_free()
	_tiles_by_cell.clear()
	if _board == null:
		return
	for cell in _board.cells():
		_draw_cell(cell)


## The tile node drawn at `cell`, or null.
func tile_at(cell: Vector2i) -> Node3D:
	return _tiles_by_cell.get(cell)


## The board cell under a screen point, or `HexGrid.NO_CELL`.
func cell_at_screen(screen_point: Vector2) -> Vector2i:
	var eye := camera if camera != null else get_viewport().get_camera_3d()
	if eye == null or _board == null:
		return HexGrid.NO_CELL
	var origin := eye.project_ray_origin(screen_point)
	var direction := eye.project_ray_normal(screen_point)
	var plane := Plane(global_basis.y.normalized(), global_position)
	var hit: Variant = plane.intersects_ray(origin, direction)
	if hit == null:
		return HexGrid.NO_CELL
	return _board.position_to_cell(to_local(hit as Vector3))


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
	if cell != HexGrid.NO_CELL:
		cell_clicked.emit(cell)


func _hover(at: Vector2) -> void:
	var cell := cell_at_screen(at)
	if cell != hovered_cell:
		hovered_cell = cell
		cell_hovered.emit(cell)


func _queue_redraw() -> void:
	if _redraw_queued or not is_inside_tree():
		return
	_redraw_queued = true
	redraw.call_deferred()
	update_configuration_warnings()


func _on_cell_changed(cell: Vector2i, key: StringName, _value: Variant) -> void:
	if key != value_key:
		return
	var old: Node3D = _tiles_by_cell.get(cell)
	if old != null and is_instance_valid(old):
		old.queue_free()
	_tiles_by_cell.erase(cell)
	_draw_cell(cell)


func _draw_cell(cell: Vector2i) -> void:
	var kind: Variant = _board.get_value(cell, value_key)
	var scene: PackedScene = tiles.get(StringName(str(kind)), default_tile) if kind != null else default_tile
	if scene == null:
		return
	var tile := scene.instantiate() as Node3D
	if tile == null:
		push_error("GridView3D: a tile scene must have a Node3D root")
		return
	tile.position = _board.cell_to_position(cell)
	add_child(tile)
	_tiles_by_cell[cell] = tile


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not get_parent() is GridBoard:
		warnings.append("GridView3D draws its parent: make it a child of a GridBoard.")
	if tiles.is_empty() and default_tile == null:
		warnings.append("No tile scenes: fill tiles (one per value of value_key) or default_tile.")
	return warnings
