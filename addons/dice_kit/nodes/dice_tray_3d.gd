@tool
@icon("res://addons/dice_kit/icons/dice_tray_3d.svg")
class_name DiceTray3D
extends Node3D

## Shows a roll as dice in 3D, in rows of `per_row` along X centered on this node, resting on its XZ plane. Each die is
## its `DieData.mesh`, your `die_mesh` or a cube, with the face that came up on top: its icon, or its value and tags.
## The dice tumble for `tumble_time`, settle face up and then `settled` says so. Give it a `roller` and it shows every
## roll of it; `show_roll()` shows any roll (mixed dice, one from the network). The tumble is only a look and draws no
## random numbers: the same roll always tumbles the same way. Before the first roll, in the editor too, it shows the
## roller's dice at rest, first face up.

## The dice of `roll` came to rest, face up: the moment to show the result to the player.
signal settled(roll: DiceRoll)

# Times the top face changes while a die tumbles, before it lands on the one that came up.
const _FLIPS := 6
const _FONT_SIZE := 64

## The roller whose rolls it shows. Empty: it shows only what `show_roll()` gets.
@export var roller: DiceRoller:
	set(value):
		if roller != null:
			if roller.rolled.is_connected(show_roll):
				roller.rolled.disconnect(show_roll)
			if roller.dice_changed.is_connected(_on_dice_changed):
				roller.dice_changed.disconnect(_on_dice_changed)
		roller = value
		if roller != null:
			roller.rolled.connect(show_roll)
			roller.dice_changed.connect(_on_dice_changed)
		if shown_roll == null:
			_show_rest()
## The shape of every die whose `DieData.mesh` is empty (a die with its own mesh keeps it). Empty: a cube. Any mesh
## works (a d20 model): it is scaled so its longest side is `die_size`, and the face that came up is drawn flat above
## its top, like a sticker; the mesh itself does not turn to that face. A mesh with a material of its own keeps it; one
## without is painted `die_color`.
@export var die_mesh: Mesh:
	set(value):
		die_mesh = value
		_redraw()
## The size of each die: the edge of the cube, or the longest side of `die_mesh`.
@export_range(0.05, 5.0, 0.01, "or_greater", "suffix:m") var die_size := 0.6:
	set(value):
		die_size = value
		_redraw()
## From the center of one die to the center of the next, in a row and between rows.
@export_range(0.05, 10.0, 0.01, "or_greater", "suffix:m") var spacing := 0.9:
	set(value):
		spacing = value
		_redraw()
## How many dice in a row; the next ones start a new row behind it (away from +Z).
@export_range(1, 50, 1, "or_greater") var per_row := 6:
	set(value):
		per_row = value
		_redraw()
## How long the dice tumble before they settle. 0: they land at once (and `settled` comes right away).
@export_range(0.0, 5.0, 0.05, "or_greater", "suffix:s") var tumble_time := 0.8
## The color of the dice (of `die_mesh` too, when it has no material of its own).
@export var die_color := Color(0.9, 0.84, 0.7):
	set(value):
		die_color = value
		_redraw()
## The color of the value and tags written on top. Icons keep their own colors.
@export var pip_color := Color(0.16, 0.12, 0.09):
	set(value):
		pip_color = value
		_redraw()

## The roll on the table (null while it shows the roller's dice at rest).
var shown_roll: DiceRoll

var _views: Array[_DieView] = []
var _elapsed := 0.0
var _tumbling := false


func _ready() -> void:
	set_process(_tumbling)
	if shown_roll == null:
		_show_rest()


func _process(delta: float) -> void:
	if not _tumbling:
		set_process(false)
		return
	_elapsed += delta
	if _elapsed >= tumble_time:
		_land()
	else:
		_pose(_progress())


## Shows `roll` on the table: its dice tumble for `tumble_time` and settle face up, then `settled` is emitted. A new
## roll while one tumbles takes its place. A null or empty roll: an error, and nothing changes.
func show_roll(roll: DiceRoll) -> void:
	if roll == null or roll.size() == 0:
		push_error("DiceTray3D.show_roll: no roll to show")
		return
	shown_roll = roll
	_build(roll.dice, roll.indices)
	_elapsed = 0.0
	if tumble_time <= 0.0:
		_land()
		return
	_tumbling = true
	_pose(0.0)
	set_process(true)


## True while the dice of `shown_roll` are still tumbling.
func is_tumbling() -> bool:
	return _tumbling


## How many dice are on the table.
func dice_shown() -> int:
	return _views.size()


## The face drawn on top of die `slot` (0 first, in roll order) right now: it changes while the die tumbles. Null out
## of range.
func face_on_top(slot: int) -> DieFace:
	if slot < 0 or slot >= _views.size():
		return null
	return _views[slot].showing


func _land() -> void:
	_tumbling = false
	_pose(1.0)
	set_process(false)
	settled.emit(shown_roll)


# The roller's dice changed: at rest (and always in the editor) the table shows the new ones; a roll on the table in
# the game stays until the next one.
func _on_dice_changed() -> void:
	if shown_roll == null or Engine.is_editor_hint():
		_show_rest()


# The roller's dice, first face up. Nothing when there is no roller or its dice cannot roll.
func _show_rest() -> void:
	shown_roll = null
	_tumbling = false
	set_process(false)
	var pool: Array[DieData] = []
	if roller != null:
		pool = roller.pool()
	var picked: Array[int] = []
	for data in pool:
		if data == null or not data.can_roll():
			_build([], [])
			return
		picked.append(0)
	_build(pool, picked)
	_pose(1.0)


# The current dice again, with the new mesh, size, spacing, rows or colors.
func _redraw() -> void:
	if _views.is_empty():
		return
	var pool: Array[DieData] = []
	var picked: Array[int] = []
	for view in _views:
		pool.append(view.die)
		picked.append(view.index)
	_build(pool, picked)
	_pose(_progress() if _tumbling else 1.0)


func _build(pool: Array[DieData], picked: Array[int]) -> void:
	for view in _views:
		remove_child(view.root)
		view.root.queue_free()
	_views.clear()
	if pool.is_empty():
		return
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * die_size
	var paint := StandardMaterial3D.new()
	paint.albedo_color = die_color
	paint.roughness = 0.45
	var shapes: Dictionary[Mesh, _Shape] = {}
	for slot in pool.size():
		var data := pool[slot]
		var body: Mesh = data.mesh if data.mesh != null else (die_mesh if die_mesh != null else cube)
		if not shapes.has(body):
			shapes[body] = _shape_of(body, body != cube)
		var shape := shapes[body]
		var view := _DieView.new(data, picked[slot])
		view.build(body, paint if shape.painted else null, shape, pip_color, _FONT_SIZE)
		add_child(view.root, false, INTERNAL_MODE_BACK)
		_views.append(view)


# How `body` sits on the table: scaled so its longest side is `die_size` (the cube already is), turning about its
# center, painted `die_color` when it has no material of its own.
func _shape_of(body: Mesh, scaled: bool) -> _Shape:
	var bounds := body.get_aabb()
	var shape := _Shape.new()
	shape.scale = die_size / maxf(bounds.get_longest_axis_size(), 0.001) if scaled else 1.0
	shape.center = bounds.get_center() * shape.scale
	shape.height = bounds.size.y * shape.scale
	shape.size = die_size
	shape.painted = body.get_surface_count() == 0 or body.surface_get_material(0) == null
	return shape


func _progress() -> float:
	return clampf(_elapsed / tumble_time, 0.0, 1.0) if tumble_time > 0.0 else 1.0


# Every die at `progress` of its tumble (0: thrown, 1: at rest face up). Only the die's slot and the face index shape
# the motion, so the same roll moves the same way every time.
func _pose(progress: float) -> void:
	var eased := 1.0 - pow(1.0 - clampf(progress, 0.0, 1.0), 3.0)
	var total := _views.size()
	var rows := ceili(float(total) / per_row)
	for slot in total:
		var view := _views[slot]
		@warning_ignore("integer_division")
		var row := slot / per_row
		var in_row := mini(per_row, total - row * per_row)
		var column := slot - row * per_row
		var rest := Vector3(
			(column - (in_row - 1) * 0.5) * spacing, view.shape.height * 0.5, (row - (rows - 1) * 0.5) * spacing
		)
		if progress >= 1.0:
			view.root.transform = Transform3D(Basis.IDENTITY, rest)
			view.show_face(view.index)
			continue
		var turns := 1 + (slot + view.index) % 2
		var axis := Vector3(1.0, 0.4 * ((slot + view.index) % 3 - 1), 0.6 * ((slot * 2 + view.index) % 3 - 1))
		var hop := sin(PI * eased) * die_size * 1.2 * (1.0 - eased)
		var slide := Vector3(0.0, hop, (1.0 - eased) * die_size * 2.5)
		view.root.transform = Transform3D(Basis(axis.normalized(), turns * TAU * eased), rest + slide)
		var step := int(eased * _FLIPS)
		view.show_face((view.index + _FLIPS - step) % maxi(view.die.faces.size(), 1))


# How the dice of one mesh are drawn: the mesh's scale, its center (so it turns about it), its height, the die size and
# whether it takes the tray's paint.
class _Shape:
	var scale := 1.0
	var center := Vector3.ZERO
	var height := 1.0
	var size := 1.0
	var painted := true


# One die on the table: its mesh, and a label or a sprite lying above its top.
class _DieView:
	var die: DieData
	var index: int
	var showing: DieFace
	var shape: _Shape
	var root := Node3D.new()
	var label := Label3D.new()
	var sprite := Sprite3D.new()

	func _init(die_in: DieData, index_in: int) -> void:
		die = die_in
		index = index_in

	func build(body: Mesh, paint: Material, shape_in: _Shape, ink: Color, font_size: int) -> void:
		shape = shape_in
		var mesh := MeshInstance3D.new()
		mesh.mesh = body
		mesh.scale = Vector3.ONE * shape.scale
		mesh.position = -shape.center
		if paint != null:
			mesh.material_override = paint
		root.add_child(mesh)
		for top: Node3D in [label, sprite]:
			top.position = Vector3(0.0, shape.height * 0.5 + 0.004, 0.0)
			top.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
			root.add_child(top)
		label.font_size = font_size
		label.outline_size = 0
		label.modulate = ink
		label.double_sided = false

	# Draws `face_index` of the die on top; a slot out of the list draws the face that came up instead.
	func show_face(face_index: int) -> void:
		var face: DieFace = die.faces[face_index] if face_index < die.faces.size() else die.faces[index]
		if face == null or face == showing:
			return
		showing = face
		sprite.visible = face.icon != null
		label.visible = face.icon == null
		if face.icon != null:
			sprite.texture = face.icon
			sprite.pixel_size = shape.size * 0.7 / maxf(maxi(face.icon.get_width(), face.icon.get_height()), 1.0)
			return
		var lines: PackedStringArray = []
		if face.value != 0 or face.tags.is_empty():
			lines.append(str(face.value))
		if not face.tags.is_empty():
			lines.append(" ".join(PackedStringArray(face.tags)))
		var longest := 1
		for line in lines:
			longest = maxi(longest, line.length())
		var height := shape.size * minf(minf(0.5, 0.75 / (lines.size() * 1.15)), 0.8 / (0.6 * longest))
		label.text = "\n".join(lines)
		label.pixel_size = height / label.font_size
