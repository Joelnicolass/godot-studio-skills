@tool
@icon("res://addons/unlock_kit/icons/unlock_tree_view.svg")
class_name UnlockTreeView
extends Control

## Draws an `UnlockTree`, in the editor too: one column per depth, left to right (or one row per depth, top to bottom),
## the entries of a column in tree order (an entry's `view_position` puts its box anywhere), a box per entry (icon,
## title, cost) in the color of its state and the font of the game's theme, and a curve from each requirement to the
## entry, dashed for `requires_any`. The tooltip of a box shows its
## title, description, cost and what is missing. With an `entry_scene`, each box is an instance of your scene (your
## theme, focus and art) and the view keeps the curves. Its minimum size fits the tree. It only draws and reports:
## your game decides what a click does (`tree.buy(id, pay)`).

## The box of `id` was clicked with the left button (or its `entry_scene` button was pressed).
signal entry_pressed(id: StringName)
## The pointer is on the box of `id` now (`&""`: on no box any more).
signal entry_hovered(id: StringName)

## Where deeper entries go.
enum Direction {
	LEFT_TO_RIGHT,  ## One column per depth, left to right; the entries of a column go down.
	TOP_TO_BOTTOM,  ## One row per depth, top to bottom; the entries of a row go right.
}

const _MARGIN := 2.0
const _PAD := 6.0
const _CURVE_STEPS := 24

## The tree to draw.
@export var tree: UnlockTree:
	set(value):
		_unwatch()
		tree = value
		_watch()
		_clear_instances()
		_on_tree_changed()
		update_configuration_warnings()
## Optional: one instance of this scene per entry instead of the drawn box. Its root is a `Control` whose script
## declares `var entry_id: StringName` and `var tree: UnlockTree`: the view sets both before the instance enters the
## scene tree, then places it on the entry's box (position and size). The scene reads its state from `tree` and
## listens to its signals. A root that is a `BaseButton` reports `pressed` as `entry_pressed` (keyboard and gamepad
## too); any root reports the pointer as `entry_hovered`. Empty: the view draws the boxes.
@export var entry_scene: PackedScene:
	set(value):
		entry_scene = value
		_clear_instances()
		_on_tree_changed()
		update_configuration_warnings()

@export_group("Layout")
## Where deeper entries go: columns left to right, or rows top to bottom. The curves follow. `view_position` still wins.
@export var direction := Direction.LEFT_TO_RIGHT:
	set(value):
		direction = value
		_on_tree_changed()
## The size of each box.
@export var box_size := Vector2(150, 52):
	set(value):
		box_size = value.max(Vector2(16, 16))
		_on_tree_changed()
## The space between boxes: across (x) and down (y).
@export var gap := Vector2(56, 14):
	set(value):
		gap = value.max(Vector2.ZERO)
		_on_tree_changed()
## The size of the title; the cost line is 2 smaller. The font itself comes from the theme (a `Theme` on this view or
## an ancestor: its `Label` font or its `default_font`).
@export_range(6, 48, 1, "suffix:px") var font_size := 13:
	set(value):
		font_size = value
		_on_tree_changed()
## How round the corners of a drawn box are.
@export_range(0, 32, 1, "suffix:px") var corner_radius := 6:
	set(value):
		corner_radius = value
		queue_redraw()

@export_group("Colors")
## The box of an unlocked entry.
@export var unlocked_color := Color(0.42, 0.6, 0.2):
	set(value):
		unlocked_color = value
		queue_redraw()
## The box of an entry that can be unlocked now.
@export var available_color := Color(0.72, 0.6, 0.16):
	set(value):
		available_color = value
		queue_redraw()
## The box of an entry that still misses a requirement.
@export var locked_color := Color(0.2, 0.22, 0.25):
	set(value):
		locked_color = value
		queue_redraw()
## The curves from each requirement to the entries that need it.
@export var line_color := Color(0.55, 0.58, 0.62):
	set(value):
		line_color = value
		queue_redraw()
## The title and the cost line.
@export var text_color := Color(0.96, 0.96, 0.94):
	set(value):
		text_color = value
		queue_redraw()

var _rects: Dictionary[StringName, Rect2] = {}
var _layout_dirty := true
var _hovered: StringName = &""
var _watched: UnlockTree
var _style := StyleBoxFlat.new()
var _instances: Dictionary[StringName, Control] = {}
var _sync_queued := false


## The id of the box under `point` (in this control's coordinates), or `&""`.
func entry_at(point: Vector2) -> StringName:
	_layout()
	for id in _rects:
		if _rects[id].has_point(point):
			return id
	return &""


## The box of `id` in this control's coordinates (empty when it is not drawn).
func box_rect(id: StringName) -> Rect2:
	_layout()
	return _rects[id] if _rects.has(id) else Rect2()


func _get_minimum_size() -> Vector2:
	_layout()
	var end := Vector2.ZERO
	for id in _rects:
		end = end.max(_rects[id].end)
	return end + Vector2(_MARGIN, _MARGIN) if not _rects.is_empty() else Vector2.ZERO


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover(&"")
	elif what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_hover(entry_at(motion.position))
		return
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		var id := entry_at(button.position)
		if id != &"":
			accept_event()
			entry_pressed.emit(id)


func _get_tooltip(at_position: Vector2) -> String:
	var id := entry_at(at_position)
	if id == &"" or tree == null:
		return ""
	var lines := PackedStringArray([tr(tree.title_of(id))])
	var item := tree.entry(id)
	if item != null and item.description != "":
		lines.append(tr(item.description))
	var cost := _cost_text(id)
	if cost != "":
		lines.append(tr("Cost: %s") % cost)
	if tree.is_unlocked(id):
		lines.append(tr("Unlocked"))
		return "\n".join(lines)
	var needs_all := PackedStringArray()
	for need in tree.requires(id):
		if not tree.is_unlocked(need):
			needs_all.append(tr(tree.title_of(need)))
	if not needs_all.is_empty():
		lines.append(tr("Needs: %s") % ", ".join(needs_all))
	var one := PackedStringArray()
	for need in tree.requires_any(id):
		if tree.is_unlocked(need):
			one.clear()
			break
		one.append(tr(tree.title_of(need)))
	if not one.is_empty():
		lines.append(tr("Needs one of: %s") % ", ".join(one))
	return "\n".join(lines)


func _draw() -> void:
	_layout()
	if tree == null or _rects.is_empty():
		return
	var shown := tree.graph
	for id in _rects:
		for need in shown.requires(id):
			if _rects.has(need):
				_draw_link(_rects[need], _rects[id], false)
		for need in shown.requires_any(id):
			if _rects.has(need):
				_draw_link(_rects[need], _rects[id], true)
	if entry_scene != null:
		return
	var font := _font()
	for id in _rects:
		_draw_box(id, shown, font)


# A curve from the requirement's far side to the entry's near side (right to left, or bottom to top), so each link
# reads on its own; dashed for a link of `requires_any`.
func _draw_link(from_rect: Rect2, to_rect: Rect2, dashed: bool) -> void:
	var from := Vector2(from_rect.end.x, from_rect.get_center().y)
	var to := Vector2(to_rect.position.x, to_rect.get_center().y)
	var pull := Vector2(maxf(absf(to.x - from.x) * 0.5, gap.x), 0.0)
	if direction == Direction.TOP_TO_BOTTOM:
		from = Vector2(from_rect.get_center().x, from_rect.end.y)
		to = Vector2(to_rect.get_center().x, to_rect.position.y)
		pull = Vector2(0.0, maxf(absf(to.y - from.y) * 0.5, gap.y))
	var points := PackedVector2Array()
	for step in _CURVE_STEPS + 1:
		points.append(from.bezier_interpolate(from + pull, to - pull, to, float(step) / _CURVE_STEPS))
	if not dashed:
		draw_polyline(points, line_color, 2.0, true)
		return
	for step in range(0, _CURVE_STEPS, 2):
		draw_line(points[step], points[step + 1], line_color, 2.0, true)


func _draw_box(id: StringName, shown: UnlockGraph, font: Font) -> void:
	var rect := _rects[id]
	var fill := locked_color
	if shown.is_unlocked(id):
		fill = unlocked_color
	elif shown.can_unlock(id):
		fill = available_color
	_style.bg_color = fill
	_style.set_corner_radius_all(corner_radius)
	_style.set_border_width_all(2 if id == _hovered else 1)
	_style.border_color = text_color if id == _hovered else fill.darkened(0.4)
	draw_style_box(_style, rect)
	var left := rect.position.x + _PAD
	var item := tree.entry(id)
	if item != null and item.icon != null:
		var side := rect.size.y - 2.0 * _PAD
		draw_texture_rect(item.icon, Rect2(Vector2(left, rect.position.y + _PAD), Vector2(side, side)), false)
		left += side + _PAD
	var width := maxf(rect.end.x - _PAD - left, 1.0)
	_draw_text(tr(tree.title_of(id)), font, font_size, Vector2(left, rect.position.y + _PAD), width, text_color)
	var cost := _cost_text(id)
	if cost != "":
		var small := maxi(font_size - 2, 6)
		var at := Vector2(left, rect.end.y - _PAD - font.get_height(small))
		_draw_text(cost, font, small, at, width, Color(text_color, text_color.a * 0.75))


func _draw_text(text: String, font: Font, size_px: int, at: Vector2, width: float, color: Color) -> void:
	var line := TextLine.new()
	line.add_string(text, font, size_px)
	line.width = width
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.draw(get_canvas_item(), at, color)


# "3 points, 1 wood": the cost of `id`, keys in alphabetical order.
func _cost_text(id: StringName) -> String:
	var cost := tree.cost_of(id)
	var keys: Array[StringName] = []
	keys.assign(cost.keys())
	keys.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	var parts := PackedStringArray()
	for key in keys:
		parts.append("%d %s" % [cost[key], tr(String(key))])
	return ", ".join(parts)


# One column per depth, left to right (or one row per depth, top to bottom); in each, the entries in the graph's order.
# An entry with a `view_position` goes there instead and takes no place in its column.
func _layout() -> void:
	if tree == null:
		_rects.clear()
		return
	# Read the graph first: a pending rebuild of the tree happens here, and it marks the layout dirty.
	var shown := tree.graph
	if not _layout_dirty:
		return
	_layout_dirty = false
	_rects.clear()
	var slots: Dictionary[int, int] = {}
	for id in shown.ids():
		var item := tree.entry(id)
		if item != null and item.view_position != Vector2.ZERO:
			_rects[id] = Rect2(item.view_position, box_size)
			continue
		var level := shown.depth(id)
		var slot: int = slots.get(level, 0)
		slots[level] = slot + 1
		var cell := Vector2(level, slot) if direction == Direction.LEFT_TO_RIGHT else Vector2(slot, level)
		_rects[id] = Rect2(cell * (box_size + gap) + Vector2(_MARGIN, _MARGIN), box_size)


# The game's font: the `Label` font of a `Theme` on this view or an ancestor, else a theme's `default_font`, else the
# project's.
func _font() -> Font:
	return get_theme_font(&"font", &"Label")


func _hover(id: StringName) -> void:
	if id == _hovered:
		return
	_hovered = id
	entry_hovered.emit(id)
	queue_redraw()


func _watch() -> void:
	if tree == null:
		return
	_watched = tree
	_watched.unlocked.connect(_on_entry_changed)
	_watched.locked.connect(_on_entry_changed)
	_watched.availability_changed.connect(_on_tree_changed)
	_watched.rebuilt.connect(_on_tree_changed)


func _unwatch() -> void:
	if _watched == null or not is_instance_valid(_watched):
		_watched = null
		return
	_watched.unlocked.disconnect(_on_entry_changed)
	_watched.locked.disconnect(_on_entry_changed)
	_watched.availability_changed.disconnect(_on_tree_changed)
	_watched.rebuilt.disconnect(_on_tree_changed)
	_watched = null


func _on_entry_changed(_id: StringName) -> void:
	queue_redraw()


func _on_tree_changed() -> void:
	_layout_dirty = true
	update_minimum_size()
	queue_redraw()
	if entry_scene != null and not _sync_queued:
		_sync_queued = true
		_sync_instances.call_deferred()


# One `entry_scene` instance per box, on its box: new ones for new entries, gone for entries that left.
func _sync_instances() -> void:
	_sync_queued = false
	if entry_scene == null or tree == null:
		_clear_instances()
		return
	_layout()
	for id in _instance_ids():
		if not _rects.has(id):
			_drop_instance(id)
	for id in _rects:
		if not _instances.has(id):
			var made := _make_instance(id)
			if made == null:
				return
			_instances[id] = made
		_instances[id].position = _rects[id].position
		_instances[id].size = _rects[id].size


func _make_instance(id: StringName) -> Control:
	var control := entry_scene.instantiate() as Control
	if control == null or not (&"entry_id" in control and &"tree" in control):
		push_error("UnlockTreeView.entry_scene: the root must be a Control whose script declares entry_id and tree")
		if control != null:
			control.free()
		return null
	control.set(&"entry_id", id)
	control.set(&"tree", tree)
	var button := control as BaseButton
	if button != null:
		button.pressed.connect(_on_instance_pressed.bind(id))
	else:
		control.gui_input.connect(_on_instance_input.bind(id))
	control.mouse_entered.connect(_hover.bind(id))
	control.mouse_exited.connect(_hover.bind(&""))
	add_child(control, false, INTERNAL_MODE_BACK)
	return control


func _drop_instance(id: StringName) -> void:
	var control := _instances[id]
	_instances.erase(id)
	if is_instance_valid(control):
		remove_child(control)
		control.queue_free()


func _clear_instances() -> void:
	for id in _instance_ids():
		_drop_instance(id)


func _instance_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_instances.keys())
	return ids


func _on_instance_pressed(id: StringName) -> void:
	entry_pressed.emit(id)


func _on_instance_input(event: InputEvent, id: StringName) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		entry_pressed.emit(id)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if tree == null:
		warnings.append("Assign tree: the UnlockTree to draw.")
	if entry_scene != null:
		var probe := entry_scene.instantiate()
		if not (probe is Control and &"entry_id" in probe and &"tree" in probe):
			warnings.append("entry_scene: its root must be a Control whose script declares entry_id and tree.")
		probe.free()
	return warnings
