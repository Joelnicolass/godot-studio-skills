extends "res://addons/gesture_kit/tests/gesture_test.gd"

## The minimal example played with fingers through Godot's input, as a person would: drag the card,
## throw it, put it back with a double tap, pinch and twist it, hold it to mark it, swipe off it for
## another color and hide the help with two fingers.

var scene: Control
var card: Node2D


func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _finger(index: int, at: Vector2, pressed: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.position = at
	touch.pressed = pressed
	_send(touch)


func _slide(index: int, from: Vector2, to: Vector2) -> void:
	var drag := InputEventScreenDrag.new()
	drag.index = index
	drag.position = to
	drag.relative = to - from
	_send(drag)


# A finger moves at a screen's pace, one event a frame (60 Hz): the speed of a throw comes out as a
# person's.
func _move(index: int, from: Vector2, to: Vector2) -> void:
	await _wait(0.016)
	_slide(index, from, to)


func _frames(count: int) -> void:
	for i in count:
		await tree.process_frame


func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await tree.process_frame


func test_minimal_plays() -> void:
	tree.root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	tree.root.size = Vector2i(1280, 720)
	Input.use_accumulated_input = false
	scene = (load("res://addons/gesture_kit/examples/minimal/minimal.tscn") as PackedScene).instantiate() as Control
	tree.root.add_child(scene)
	await tree.process_frame
	card = scene.get_node(^"%Card") as Node2D
	var area := scene.get_node(^"%Area") as GestureArea
	var status := scene.get_node(^"%Status") as Label
	check(area._get_configuration_warnings().is_empty(), "the area has no warnings")
	check(card.position == Vector2(640, 360), "the card starts in the middle: %s" % card.position)
	_finger(0, Vector2(640, 360), true)
	await _move(0, Vector2(640, 360), Vector2(690, 360))
	await _move(0, Vector2(690, 360), Vector2(740, 380))
	await _wait(0.15)
	_finger(0, Vector2(740, 380), false)
	check(card.position == Vector2(740, 380), "dragged, it stays under the finger: %s" % card.position)
	await _wait(0.35)
	_finger(0, Vector2(740, 380), true)
	await _move(0, Vector2(740, 380), Vector2(760, 380))
	await _move(0, Vector2(760, 380), Vector2(800, 380))
	_finger(0, Vector2(800, 380), false)
	await _wait(0.4)
	check(card.position.x > 820.0, "thrown, it glides on: %s" % card.position)
	await _wait(0.35)
	_finger(0, Vector2(200, 200), true)
	_finger(0, Vector2(200, 200), false)
	await _wait(0.06)
	_finger(0, Vector2(205, 200), true)
	_finger(0, Vector2(205, 200), false)
	check(card.position == Vector2(640, 360), "a double tap puts it back: %s" % card.position)
	check(status.text == "Double tap: back to the middle", "and says so: %s" % status.text)
	await _wait(0.35)
	_finger(0, Vector2(540, 360), true)
	_finger(1, Vector2(740, 360), true)
	_slide(1, Vector2(740, 360), Vector2(780, 360))
	await _frames(2)
	_slide(1, Vector2(780, 360), Vector2(860, 360))
	await _frames(2)
	check(is_equal_approx(card.scale.x, 320.0 / 240.0), "pinched: %s" % card.scale)
	_slide(1, Vector2(860, 360), Vector2(540, 680))
	await _frames(2)
	_slide(1, Vector2(540, 680), Vector2(220, 360))
	await _frames(2)
	check(is_equal_approx(card.rotation, PI / 2.0), "twisted a quarter turn: %s" % rad_to_deg(card.rotation))
	await _wait(0.15)
	_finger(0, Vector2(540, 360), false)
	_finger(1, Vector2(220, 360), false)
	await _wait(0.35)
	var mark := scene.get_node(^"%Mark") as ColorRect
	var on_card := card.get_global_transform_with_canvas() * Vector2(0, 40)
	check(scene.call(&"is_on_card", on_card), "a point of the turned card is on it")
	_finger(0, on_card, true)
	await _wait(0.25)
	check(area.reader.hold_progress() > 0.3 and not mark.visible, "holding: the ring fills up")
	await _wait(0.35)
	check(mark.visible, "held: the card is marked")
	_finger(0, on_card, false)
	await _wait(0.35)
	var number := scene.get_node(^"%Number") as Label
	_finger(0, Vector2(100, 650), true)
	await _move(0, Vector2(100, 650), Vector2(200, 650))
	await _move(0, Vector2(200, 650), Vector2(300, 650))
	_finger(0, Vector2(300, 650), false)
	check(number.text == "5" and status.text == "Swipe right", "a swipe off the card: %s" % status.text)
	var before := card.position
	_finger(0, on_card, true)
	await _move(0, on_card, on_card + Vector2(-100, 0))
	await _move(0, on_card + Vector2(-100, 0), on_card + Vector2(-200, 0))
	_finger(0, on_card + Vector2(-200, 0), false)
	check(number.text == "5", "a quick drag of the card throws it and keeps its color")
	check(card.position.x < before.x, "it moved: %s" % card.position)
	await _wait(0.35)
	var help := scene.get_node(^"%Help") as Label
	_finger(0, Vector2(100, 100), true)
	_finger(1, Vector2(160, 100), true)
	_finger(0, Vector2(100, 100), false)
	_finger(1, Vector2(160, 100), false)
	check(not help.visible and status.text == "Tap with 2 fingers", "a two-finger tap hides the help")
	Input.use_accumulated_input = true
	scene.queue_free()
	await tree.process_frame
