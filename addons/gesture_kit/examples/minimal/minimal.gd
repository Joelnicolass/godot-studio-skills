extends Control

## GestureKit's smallest example: a card on a screen-wide GestureArea. Drag the card and throw it (one finger),
## pinch it and twist it with two fingers (with the mouse: Alt + drag); a double tap puts it back, a
## long press on it marks it (the yellow corner), a swipe that starts off the card changes its color
## and a two-finger tap shows or hides the help. The ring that fills up while you hold is drawn from
## `reader.hold_progress()`.

const COLORS: Array[Color] = [
	Color(0.96, 0.55, 0.4),
	Color(0.35, 0.7, 0.95),
	Color(0.55, 0.85, 0.45),
	Color(0.95, 0.8, 0.3),
	Color(0.75, 0.5, 0.95),
]
const SMALLEST := 0.4
const LARGEST := 3.0
const THROW_SECONDS := 0.3

var color_index := 0
var holding_card := false
var _throw: Tween

@onready var area: GestureArea = %Area
@onready var card: Node2D = %Card
@onready var face: ColorRect = %Face
@onready var number: Label = %Number
@onready var mark: ColorRect = %Mark
@onready var ring: Control = %Ring
@onready var status: Label = %Status
@onready var help: Label = %Help


func _ready() -> void:
	area.tapped.connect(_on_tapped)
	area.double_tapped.connect(_on_double_tapped)
	area.long_pressed.connect(_on_long_pressed)
	area.swiped.connect(_on_swiped)
	area.drag_started.connect(_on_drag_started)
	area.dragged.connect(_on_dragged)
	area.drag_ended.connect(_on_drag_ended)
	area.pinched.connect(_on_pinched)
	area.twisted.connect(_on_twisted)
	ring.draw.connect(_draw_ring)
	resized.connect(_center_card)
	_center_card()
	_paint()


func _process(_delta: float) -> void:
	ring.queue_redraw()


## Whether the screen point `at` is on the card, however it is moved, turned or scaled.
func is_on_card(at: Vector2) -> bool:
	var local := card.get_global_transform_with_canvas().affine_inverse() * at
	return Rect2(face.position, face.size).has_point(local)


func _on_tapped(_at: Vector2, fingers: int) -> void:
	status.text = "Tap with %d finger%s" % [fingers, "" if fingers == 1 else "s"]
	if fingers == 2:
		help.visible = not help.visible


func _on_double_tapped(_at: Vector2, _fingers: int) -> void:
	status.text = "Double tap: back to the middle"
	_center_card()
	card.scale = Vector2.ONE
	card.rotation = 0.0


func _on_long_pressed(at: Vector2, _fingers: int) -> void:
	if is_on_card(at):
		mark.visible = not mark.visible
		status.text = "Long press: %s" % ("marked" if mark.visible else "unmarked")


func _on_swiped(direction: Vector2, _fingers: int) -> void:
	if holding_card:
		return
	if direction == Vector2.LEFT or direction == Vector2.RIGHT:
		color_index = posmod(color_index + (1 if direction == Vector2.LEFT else -1), COLORS.size())
		_paint()
	var words := {Vector2.LEFT: "left", Vector2.RIGHT: "right", Vector2.UP: "up", Vector2.DOWN: "down"}
	status.text = "Swipe %s" % words.get(direction, "")


func _on_drag_started(at: Vector2, _fingers: int) -> void:
	holding_card = is_on_card(at)
	if holding_card and _throw != null:
		_throw.kill()


func _on_dragged(relative: Vector2, _fingers: int) -> void:
	if holding_card:
		card.position += relative


func _on_drag_ended(velocity: Vector2, fingers: int) -> void:
	# One finger throws; two were pinching or twisting it.
	if not holding_card or fingers > 1 or velocity.length() < 200.0:
		return
	_throw = create_tween()
	var to := card.position + velocity * THROW_SECONDS * 0.5
	_throw.tween_property(card, ^"position", to, THROW_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _on_pinched(ratio: float, center: Vector2) -> void:
	var scale_to := clampf(card.scale.x * ratio, SMALLEST, LARGEST)
	ratio = scale_to / card.scale.x
	card.scale = Vector2.ONE * scale_to
	card.position = center + (card.position - center) * ratio
	status.text = "Pinch: ×%.2f" % scale_to


func _on_twisted(radians: float, center: Vector2) -> void:
	card.rotation += radians
	card.position = center + (card.position - center).rotated(radians)
	status.text = "Twist: %d°" % roundi(rad_to_deg(card.rotation))


func _draw_ring() -> void:
	var hold := area.reader.hold_progress()
	if hold < 0.2:
		return
	var at := Vector2.ZERO
	var fingers := area.reader.finger_positions()
	for index: int in fingers:
		at += fingers[index]
	at = ring.get_global_transform_with_canvas().affine_inverse() * (at / fingers.size())
	ring.draw_arc(at, 44.0, -PI / 2.0, -PI / 2.0 + TAU * hold, 48, Color.WHITE, 5.0)


func _center_card() -> void:
	card.position = size * 0.5


func _paint() -> void:
	face.color = COLORS[color_index]
	number.text = str(color_index + 1)
