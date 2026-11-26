extends "res://addons/gesture_kit/tests/gesture_test.gd"

## GestureReader alone, with exact times: every gesture, its thresholds, the order of its signals and
## what a finger landing, lifting or a clear does in the middle of one.

const SIGNALS: Array[StringName] = [
	&"tapped",
	&"double_tapped",
	&"tap_confirmed",
	&"long_pressed",
	&"long_press_ended",
	&"swiped",
	&"drag_started",
	&"dragged",
	&"drag_ended",
	&"pinched",
	&"twisted",
]

var reader: GestureReader
var heard: Array[Array] = []


func _reader() -> GestureReader:
	reader = GestureReader.new()
	heard = []
	for signal_name in SIGNALS:
		reader.connect(signal_name, _hear.bind(signal_name))
	return reader


func _hear(first: Variant, second: Variant, signal_name: StringName) -> void:
	heard.append([signal_name, first, second])


func _names() -> Array[StringName]:
	var names: Array[StringName] = []
	for entry in heard:
		names.append(entry[0])
	return names


func _of(signal_name: StringName) -> Array[Array]:
	var found: Array[Array] = []
	for entry in heard:
		if entry[0] == signal_name:
			found.append(entry)
	return found


func _tap(at: Vector2, from: float, to: float, index := 0) -> void:
	reader.press(index, at, from)
	reader.lift(index, at, to)


func test_taps_with_one_two_and_three_fingers() -> void:
	_reader()
	_tap(Vector2(100, 100), 0.0, 0.1)
	check(_names() == [&"tapped"], "one finger: a tap, nothing else: %s" % [_names()])
	check(heard[0][1] == Vector2(100, 100) and heard[0][2] == 1, "at where it landed, one finger: %s" % [heard[0]])
	reader.press(0, Vector2(100, 100), 2.0)
	reader.press(1, Vector2(200, 300), 2.05)
	reader.lift(0, Vector2(100, 100), 2.1)
	reader.lift(1, Vector2(200, 300), 2.12)
	var two := _of(&"tapped")[-1]
	check(two[1] == Vector2(150, 200) and two[2] == 2, "two fingers: their middle, 2: %s" % [two])
	reader.press(0, Vector2(0, 0), 4.0)
	reader.press(1, Vector2(30, 0), 4.0)
	reader.press(2, Vector2(60, 30), 4.0)
	reader.lift(2, Vector2(60, 30), 4.1)
	reader.lift(0, Vector2(0, 0), 4.1)
	reader.lift(1, Vector2(30, 0), 4.1)
	var three := _of(&"tapped")[-1]
	check(three[1] == Vector2(30, 10) and three[2] == 3, "three fingers: 3: %s" % [three])
	reader.press(0, Vector2(10, 10), 6.0)
	reader.move(0, Vector2(18, 15), 6.05)
	reader.lift(0, Vector2(18, 15), 6.1)
	check(_of(&"tapped").size() == 4 and _of(&"drag_started").is_empty(), "moving less than slop_px still taps")
	check(_of(&"tapped")[-1][1] == Vector2(10, 10), "at where it landed, not where it lifted")


func test_past_the_slop_it_drags() -> void:
	_reader()
	reader.press(0, Vector2(100, 100), 0.0)
	reader.move(0, Vector2(110, 100), 0.05)
	check(heard.is_empty(), "10 px: nothing yet")
	reader.move(0, Vector2(113, 100), 0.1)
	check(_names() == [&"drag_started", &"dragged"], "13 px: the drag starts: %s" % [_names()])
	check(heard[0][1] == Vector2(100, 100) and heard[0][2] == 1, "where the finger landed: %s" % [heard[0]])
	check(heard[1][1] == Vector2(13, 0), "the first dragged covers the slop: %s" % [heard[1]])
	reader.move(0, Vector2(120, 104), 0.15)
	check(_of(&"dragged")[-1][1] == Vector2(7, 4), "then each move: %s" % [_of(&"dragged")[-1]])
	reader.lift(0, Vector2(120, 104), 0.9)
	check(_names().back() == &"drag_ended" and _of(&"tapped").is_empty(), "lifting ends the drag, no tap")
	check(_of(&"drag_ended")[0][1] == Vector2.ZERO, "a finger that stopped before lifting throws nothing")
	var total := Vector2.ZERO
	for entry in _of(&"dragged"):
		total += entry[1]
	check(total == Vector2(20, 4), "the drags add up to the motion: %s" % total)


func test_drag_velocity() -> void:
	_reader()
	reader.press(0, Vector2(0, 0), 0.0)
	for step in range(1, 21):
		reader.move(0, Vector2(step * 10, step * -5), step * 0.01)
	reader.lift(0, Vector2(200, -100), 0.205)
	var velocity: Vector2 = _of(&"drag_ended")[0][1]
	check(velocity.is_equal_approx(Vector2(1000, -500)), "10 px every 10 ms: 1000 px/s: %s" % velocity)
	_reader()
	reader.press(0, Vector2(0, 0), 0.0)
	reader.move(0, Vector2(300, 0), 0.05)
	reader.lift(0, Vector2(300, 0), 0.08)
	velocity = _of(&"drag_ended")[0][1]
	check(velocity.is_equal_approx(Vector2(7500, 0)), "one move 50 ms after landing took at most 40 ms: %s" % velocity)
	_reader()
	reader.press(0, Vector2(0, 0), 0.0)
	reader.move(0, Vector2(50, 0), 0.05)
	reader.move(0, Vector2(100, 0), 0.1)
	reader.move(0, Vector2(150, 0), 0.6)
	reader.move(0, Vector2(200, 0), 0.616)
	reader.lift(0, Vector2(200, 0), 0.62)
	velocity = _of(&"drag_ended")[0][1]
	check(velocity.is_equal_approx(Vector2(3125, 0)), "a pause, then a flick: only the flick counts: %s" % velocity)
	_reader()
	reader.press(0, Vector2(0, 0), 1.0)
	reader.move(0, Vector2(100, 0), 1.00003)
	reader.lift(0, Vector2(100, 0), 1.00006)
	velocity = _of(&"drag_ended")[0][1]
	check(velocity.is_equal_approx(Vector2(12000, 0)), "a flick read in one frame: one frame at 120 fps: %s" % velocity)


func test_long_press() -> void:
	_reader()
	reader.press(0, Vector2(50, 50), 0.0)
	check(reader.is_waiting(), "a finger down waits for a long press")
	reader.update(0.25)
	check(is_equal_approx(reader.hold_progress(), 0.5), "halfway: %s" % reader.hold_progress())
	reader.update(0.49)
	check(heard.is_empty(), "0.49 s: nothing yet")
	reader.update(0.5)
	check(_names() == [&"long_pressed"] and heard[0][1] == Vector2(50, 50) and heard[0][2] == 1, "%s" % [heard])
	check(reader.hold_progress() == 0.0 and not reader.is_waiting(), "the hold is over")
	reader.move(0, Vector2(58, 50), 0.6)
	check(heard.size() == 1, "within the slop of the hold: nothing")
	reader.move(0, Vector2(70, 50), 0.7)
	check(_names() == [&"long_pressed", &"drag_started", &"dragged"], "past it, a drag: %s" % [_names()])
	check(heard[1][1] == Vector2(50, 50), "from where it was held: %s" % [heard[1]])
	reader.lift(0, Vector2(70, 50), 0.71)
	check(_of(&"tapped").is_empty() and _of(&"swiped").is_empty(), "no tap and no swipe after a long press")
	check(
		heard[-1] == [&"long_press_ended", Vector2(70, 50), 1], "the long press ends where it lifted: %s" % [heard[-1]]
	)
	check(_names().slice(-2) == [&"drag_ended", &"long_press_ended"], "after its drag: %s" % [_names()])
	_reader()
	reader.press(0, Vector2(50, 50), 0.0)
	reader.move(0, Vector2(80, 50), 0.1)
	reader.update(2.0)
	check(_of(&"long_pressed").is_empty(), "a finger that moved never long presses")
	_reader()
	reader.press(0, Vector2(50, 50), 0.0)
	reader.move(0, Vector2(52, 50), 0.6)
	check(_names() == [&"long_pressed"], "a finger event is late enough without update(): %s" % [_names()])
	_reader()
	reader.press(0, Vector2(0, 0), 0.0)
	reader.press(1, Vector2(40, 0), 0.3)
	reader.update(0.7)
	check(heard.is_empty(), "a second finger starts the wait again")
	reader.update(0.8)
	check(_names() == [&"long_pressed"] and heard[0][1] == Vector2(20, 0) and heard[0][2] == 2, "%s" % [heard])
	_reader()
	_tap(Vector2(10, 10), 0.0, 0.5)
	var expected: Array[StringName] = [&"long_pressed", &"long_press_ended"]
	check(_names() == expected, "lifting at long_press_s is a long press, not a tap: %s" % [_names()])
	_reader()
	reader.press(0, Vector2(0, 0), 0.0)
	reader.press(1, Vector2(40, 0), 0.4)
	reader.lift(0, Vector2(0, 0), 0.6)
	reader.lift(1, Vector2(40, 0), 0.6)
	check(heard == [[&"tapped", Vector2(20, 0), 2]], "a second finger late: still a tap, timed from it: %s" % [heard])
	_reader()
	reader.press(0, Vector2(0, 0), 0.0)
	reader.press(1, Vector2(40, 0), 0.0)
	reader.lift(1, Vector2(40, 0), 0.1)
	reader.update(0.5)
	check(heard == [[&"long_pressed", Vector2(0, 0), 2]], "fingers is the most of the gesture: %s" % [heard])
	reader.clear()
	check(heard[-1] == [&"long_press_ended", Vector2(0, 0), 2], "clear() ends a long press: %s" % [heard[-1]])


func test_double_tap_and_tap_confirmed() -> void:
	_reader()
	_tap(Vector2(100, 100), 0.0, 0.05)
	check(reader.is_waiting(), "a tap waits for a second one")
	_tap(Vector2(110, 105), 0.2, 0.25)
	check(_names() == [&"tapped", &"tapped", &"double_tapped"], "%s" % [_names()])
	check(heard[2][1] == Vector2(110, 105) and heard[2][2] == 1, "at the second tap: %s" % [heard[2]])
	reader.update(5.0)
	check(_of(&"tap_confirmed").is_empty() and not reader.is_waiting(), "a doubled tap is never confirmed")
	_reader()
	_tap(Vector2(100, 100), 0.0, 0.05)
	reader.update(0.35)
	check(_names() == [&"tapped"], "0.30 s after lifting: still waiting")
	reader.update(0.36)
	check(_names() == [&"tapped", &"tap_confirmed"] and heard[1][1] == Vector2(100, 100), "%s" % [heard])
	_reader()
	_tap(Vector2(100, 100), 0.0, 0.05)
	_tap(Vector2(100, 100), 0.4, 0.45)
	check(_names() == [&"tapped", &"tap_confirmed", &"tapped"], "too late: two taps: %s" % [_names()])
	_reader()
	_tap(Vector2(100, 100), 0.0, 0.05)
	_tap(Vector2(200, 100), 0.1, 0.15)
	check(_names() == [&"tapped", &"tap_confirmed", &"tapped"], "too far: two taps: %s" % [_names()])
	_reader()
	_tap(Vector2(100, 100), 0.0, 0.05)
	reader.press(0, Vector2(95, 100), 0.1)
	reader.press(1, Vector2(105, 100), 0.1)
	reader.lift(0, Vector2(95, 100), 0.15)
	reader.lift(1, Vector2(105, 100), 0.15)
	check(_of(&"double_tapped").is_empty(), "one finger then two: no double tap")
	_reader()
	_tap(Vector2(100, 100), 0.0, 0.05)
	reader.press(0, Vector2(100, 100), 0.3)
	reader.update(0.4)
	check(_names() == [&"tapped"], "a second tap that landed in time is still down: the first waits")
	reader.lift(0, Vector2(100, 100), 0.45)
	check(_names() == [&"tapped", &"tapped", &"double_tapped"], "it lifts: a double tap: %s" % [_names()])
	_reader()
	_tap(Vector2(100, 100), 0.0, 0.05)
	reader.press(0, Vector2(100, 100), 0.2)
	reader.move(0, Vector2(150, 100), 0.4)
	check(_names() == [&"tapped", &"tap_confirmed", &"drag_started", &"dragged"], "%s" % [_names()])
	_reader()
	_tap(Vector2(100, 100), 0.0, 0.05)
	_tap(Vector2(100, 100), 0.06, 0.08)
	reader.update(1.0)
	check(_names() == [&"tapped", &"tap_confirmed"], "a second tap 10 ms later is a bounce: %s" % [_names()])
	_reader()
	for start in [0.0, 0.1, 0.2]:
		_tap(Vector2(100, 100), start, start + 0.05)
	reader.update(1.0)
	var expected: Array[StringName] = [&"tapped", &"tapped", &"double_tapped", &"tapped", &"tap_confirmed"]
	check(_names() == expected, "three quick taps: a double tap and a tap: %s" % [_names()])


func test_swipe() -> void:
	var lines := {
		Vector2(100, 10): Vector2.RIGHT,
		Vector2(-100, 30): Vector2.LEFT,
		Vector2(20, -90): Vector2.UP,
		Vector2(-40, 70): Vector2.DOWN,
	}
	for line: Vector2 in lines:
		_reader()
		reader.press(0, Vector2(300, 300), 0.0)
		reader.move(0, Vector2(300, 300) + line * 0.5, 0.1)
		reader.move(0, Vector2(300, 300) + line, 0.2)
		reader.lift(0, Vector2(300, 300) + line, 0.25)
		check(_names().slice(-2) == [&"drag_ended", &"swiped"], "a drag first, then the swipe: %s" % [_names()])
		check(heard[-1][1] == lines[line] and heard[-1][2] == 1, "%s: %s" % [line, heard[-1]])
	_reader()
	reader.swipe_directions = GestureReader.Directions.EIGHT
	reader.press(0, Vector2(0, 0), 0.0)
	reader.lift(0, Vector2(80, 70), 0.1)
	check(_of(&"swiped")[0][1].is_equal_approx(Vector2(1, 1).normalized()), "eight: down right %s" % [heard[-1]])
	_reader()
	reader.swipe_directions = GestureReader.Directions.ANY
	reader.press(0, Vector2(0, 0), 0.0)
	reader.lift(0, Vector2(80, 70), 0.1)
	check(_of(&"swiped")[0][1].is_equal_approx(Vector2(80, 70).normalized()), "any: the line itself")
	_reader()
	reader.press(0, Vector2(0, 0), 0.0)
	reader.move(0, Vector2(100, 0), 0.05)
	reader.move(0, Vector2(150, 0), 0.4)
	reader.lift(0, Vector2(200, 0), 0.6)
	check(_of(&"swiped").is_empty() and _of(&"drag_ended").size() == 1, "too slow from its first move: only a drag")
	_reader()
	reader.press(0, Vector2(0, 0), 0.0)
	reader.lift(0, Vector2(50, 0), 0.1)
	check(_of(&"swiped").is_empty() and _of(&"drag_ended").size() == 1, "too short: only a drag")
	_reader()
	reader.press(0, Vector2(0, 0), 0.0)
	reader.press(1, Vector2(50, 0), 0.02)
	reader.move(0, Vector2(0, -80), 0.1)
	reader.move(1, Vector2(50, -80), 0.1)
	reader.lift(0, Vector2(0, -80), 0.15)
	reader.lift(1, Vector2(50, -80), 0.16)
	check(_of(&"swiped").size() == 1 and _of(&"swiped")[0][1] == Vector2.UP, "two fingers up: %s" % [heard[-1]])
	check(_of(&"swiped")[0][2] == 2, "with 2 fingers")
	_reader()
	reader.press(0, Vector2(0, 0), 0.0)
	reader.move(0, Vector2(100, 0), 0.37)
	reader.move(0, Vector2(200, 0), 0.43)
	reader.lift(0, Vector2(200, 0), 0.44)
	check(_of(&"swiped").size() == 1, "a thumb that waited, then swiped: the clock runs from the move")
	_reader()
	reader.press(0, Vector2(100, 300), 0.0)
	reader.press(1, Vector2(200, 300), 0.0)
	for step in range(1, 8):
		_move(1, Vector2(200 + step * 20, 300), step * 0.03)
	reader.lift(0, Vector2(100, 300), 0.24)
	reader.lift(1, Vector2(340, 300), 0.26)
	check(_of(&"pinched").size() > 0, "one finger still, the other one out: a pinch")
	check(_of(&"swiped").is_empty(), "and no swipe, though the middle travelled 70 px: %s" % [_names()])


func test_drag_with_fingers_landing_and_lifting() -> void:
	_reader()
	reader.press(0, Vector2(100, 100), 0.0)
	reader.press(1, Vector2(200, 100), 0.0)
	reader.move(0, Vector2(110, 100), 0.02)
	reader.move(1, Vector2(210, 100), 0.04)
	check(heard.is_empty(), "the middle of two moved 10 px: nothing yet")
	reader.move(0, Vector2(120, 100), 0.06)
	check(_names() == [&"drag_started", &"dragged"], "15 px: their middle drags: %s" % [_names()])
	check(heard[0][1] == Vector2(150, 100) and heard[0][2] == 2, "from their middle: %s" % [heard[0]])
	check(heard[1][1] == Vector2(15, 0), "the first dragged covers the slop: %s" % [heard[1]])
	reader.move(1, Vector2(220, 100), 0.08)
	check(heard[-1] == [&"dragged", Vector2(5, 0), 2], "one of two fingers moved 10: the middle moved 5")
	reader.press(2, Vector2(400, 400), 0.15)
	check(heard.size() == 3, "a third finger landing moves nothing")
	reader.move(2, Vector2(400, 430), 0.2)
	check(heard[-1] == [&"dragged", Vector2(0, 10), 3], "it moves the middle of three: %s" % [heard[-1]])
	reader.lift(0, Vector2(120, 100), 0.25)
	reader.lift(2, Vector2(400, 430), 0.25)
	check(heard.size() == 4, "fingers lifting move nothing: %s" % [heard.slice(4)])
	reader.move(1, Vector2(240, 100), 0.3)
	check(heard[-1] == [&"dragged", Vector2(20, 0), 3], "one left: it drags, and the gesture had 3: %s" % [heard[-1]])
	reader.lift(1, Vector2(240, 100), 0.31)
	check(heard[-1][0] == &"drag_ended" and heard[-1][2] == 3, "one drag_ended, 3 fingers: %s" % [heard[-1]])
	check(_of(&"drag_started").size() == 1 and _of(&"drag_ended").size() == 1, "one drag the whole time")


# A finger moves and two frames pass: a pair finger that moved alone is read on the second one.
func _move(index: int, at: Vector2, now: float) -> void:
	reader.move(index, at, now)
	reader.update(now)
	reader.update(now)


func test_pinch_and_twist() -> void:
	_reader()
	reader.press(0, Vector2(100, 100), 0.0)
	reader.press(1, Vector2(200, 100), 0.0)
	_move(1, Vector2(210, 100), 0.05)
	check(_of(&"pinched").is_empty(), "the gap changed 10 px: no pinch yet")
	_move(1, Vector2(220, 100), 0.1)
	check(_of(&"pinched").is_empty(), "past slop_px the pinch starts from here")
	_move(1, Vector2(250, 100), 0.15)
	var pinch := _of(&"pinched")
	check(pinch.size() == 1 and is_equal_approx(pinch[0][1], 150.0 / 120.0), "spread: %s" % [pinch])
	check(pinch[0][2] == Vector2(175, 100), "around the middle of the two: %s" % [pinch[0]])
	_move(0, Vector2(130, 100), 0.2)
	check(is_equal_approx(_of(&"pinched")[-1][1], 120.0 / 150.0), "closing: below 1")
	reader.lift(0, Vector2(130, 100), 0.3)
	reader.lift(1, Vector2(250, 100), 0.3)
	check(_of(&"tapped").is_empty(), "a pinch is no tap")
	_reader()
	reader.press(0, Vector2(100, 100), 0.0)
	reader.press(1, Vector2(200, 100), 0.0)
	var degrees := 0.0
	for step in 7:
		degrees += 4.0
		_move(1, Vector2(100, 100) + Vector2.from_angle(deg_to_rad(degrees)) * 100.0, 0.05 * (step + 1))
	var turned := 0.0
	for entry in _of(&"twisted"):
		turned += entry[1]
	check(_of(&"twisted").size() == 4, "4° steps: past 10° at 12°, then each step: %d" % _of(&"twisted").size())
	check(is_equal_approx(turned, deg_to_rad(16.0)), "16° after the start: %s" % rad_to_deg(turned))
	check(_of(&"pinched").is_empty(), "turning around a finger does not pinch")
	_reader()
	reader.press(0, Vector2(100, 100), 0.0)
	reader.press(1, Vector2(200, 100), 0.0)
	_move(1, Vector2(100, 200), 0.1)
	check(_of(&"twisted").is_empty(), "a quarter turn in one move only starts the twist")
	_move(1, Vector2(0, 100), 0.2)
	check(is_equal_approx(_of(&"twisted")[0][1], PI / 2.0), "clockwise on screen is positive: %s" % [heard])
	_reader()
	reader.press(0, Vector2(100, 100), 0.0)
	reader.press(1, Vector2(200, 100), 0.0)
	reader.press(2, Vector2(300, 300), 0.0)
	_move(2, Vector2(500, 300), 0.1)
	check(_of(&"pinched").is_empty() and _of(&"twisted").is_empty(), "a third finger neither pinches nor twists")
	reader.lift(0, Vector2(100, 100), 0.2)
	_move(2, Vector2(500, 400), 0.3)
	check(_of(&"pinched").is_empty(), "the pair is now fingers 1 and 2: past the slop their pinch starts")
	_move(2, Vector2(500, 500), 0.4)
	check(_of(&"pinched").size() == 1, "and then they pinch")


func test_two_fingers_are_read_together() -> void:
	_reader()
	reader.press(0, Vector2(100, 100), 0.0)
	reader.press(1, Vector2(200, 100), 0.0)
	for step in range(1, 6):
		reader.move(0, Vector2(100, 100 + step * 40), step * 0.016)
		check(reader.is_waiting(), "one of the two moved: the pair waits for the other")
		reader.move(1, Vector2(200, 100 + step * 40), step * 0.016)
	check(_of(&"pinched").is_empty() and _of(&"twisted").is_empty(), "40 px steps one finger at a time: no pinch")
	check(_of(&"dragged").size() > 0, "they drag: %s" % [_names()])
	reader.move(1, Vector2(260, 300), 0.1)
	reader.move(1, Vector2(300, 300), 0.11)
	check(_of(&"pinched").is_empty(), "one finger moving twice: the first move is read on the second")
	reader.move(1, Vector2(320, 300), 0.12)
	check(_of(&"pinched").size() == 1, "and the second on the third: %s" % [_of(&"pinched")])
	reader.lift(1, Vector2(340, 300), 0.13)
	check(is_equal_approx(_of(&"pinched")[-1][1], 240.0 / 220.0), "lifting reads the last move first")
	_reader()
	reader.press(0, Vector2(100, 100), 0.0)
	reader.press(1, Vector2(200, 100), 0.0)
	for step in range(1, 6):
		reader.move(0, Vector2(100, 100 + step * 40), step * 0.032)
		reader.update(step * 0.032)
		reader.move(1, Vector2(200, 100 + step * 40), step * 0.032 + 0.016)
		reader.update(step * 0.032 + 0.016)
	check(_of(&"pinched").is_empty(), "the two moving a frame apart: still no pinch: %s" % [_of(&"pinched")])


func test_two_fingers_close_together() -> void:
	_reader()
	reader.press(0, Vector2(100, 100), 0.0)
	reader.press(1, Vector2(130, 100), 0.0)
	_move(1, Vector2(102, 100), 0.1)
	_move(1, Vector2(104, 100), 0.2)
	check(is_equal_approx(_of(&"pinched")[-1][1], 2.0), "2 px to 4 px: twice as far: %s" % [_of(&"pinched")])
	_move(1, Vector2(100.5, 100), 0.3)
	_move(1, Vector2(130, 100), 0.4)
	check(is_equal_approx(_of(&"pinched")[-1][1], 30.0), "under 1 px counts as 1, and it pinches again: %s" % [heard])
	check(_of(&"twisted").is_empty(), "fingers that close turn nothing")
	_reader()
	reader.press(0, Vector2(100, 100), 0.0)
	reader.press(1, Vector2(105, 100), 0.0)
	_move(1, Vector2(100, 105), 0.1)
	_move(1, Vector2(95, 100), 0.2)
	check(_of(&"twisted").is_empty(), "5 px apart, a half turn is noise: %s" % [heard])


func test_fingers_that_come_back() -> void:
	_reader()
	reader.press(0, Vector2(100, 100), 0.0)
	reader.press(1, Vector2(200, 100), 0.0)
	reader.lift(0, Vector2(100, 100), 0.1)
	reader.press(0, Vector2(600, 400), 0.15)
	check(heard.is_empty(), "a finger index used again, far away: no jump")
	_move(0, Vector2(605, 400), 0.2)
	check(_of(&"pinched").is_empty() and _of(&"dragged").is_empty(), "the new pair starts from there")
	check(reader.center() == Vector2(402.5, 250), "center() is the middle of the two: %s" % reader.center())


func test_center_and_limits() -> void:
	_reader()
	reader.press(0, Vector2(10, 10), 0.0)
	reader.move(0, Vector2(80, 10), 0.1)
	check(reader.center() == Vector2(80, 10), "during a drag, where the finger is")
	reader.lift(0, Vector2(90, 10), 0.2)
	check(reader.center() == Vector2(90, 10), "after it, where it lifted")
	reader.slop_px = -3.0
	reader.long_press_s = 0.0
	reader.double_tap_s = -1.0
	reader.double_tap_px = -1.0
	reader.swipe_min_px = 0.0
	reader.swipe_max_s = 0.0
	reader.twist_start_deg = 500.0
	check(reader.slop_px == 0.0 and reader.long_press_s == 0.01 and reader.double_tap_s == 0.0, "taps: kept sane")
	check(reader.double_tap_px == 0.0 and reader.swipe_min_px == 1.0 and reader.swipe_max_s == 0.01, "swipe")
	check(reader.twist_start_deg == 180.0, "twist")
	reader.press(0, Vector2(0, 0), 1.0)
	reader.update(1.02)
	check(_of(&"long_pressed").size() == 1 and reader.hold_progress() == 0.0, "a long press of 0 holds at once")


func test_clear() -> void:
	_reader()
	reader.press(0, Vector2(0, 0), 0.0)
	reader.press(1, Vector2(40, 0), 0.0)
	reader.move(0, Vector2(0, 40), 0.1)
	reader.clear()
	check(heard[-1] == [&"drag_ended", Vector2.ZERO, 2], "a drag under way ends, still: %s" % [heard[-1]])
	var count := heard.size()
	reader.move(0, Vector2(0, 80), 0.2)
	reader.lift(0, Vector2(0, 80), 0.3)
	reader.lift(1, Vector2(40, 0), 0.3)
	reader.update(3.0)
	check(heard.size() == count, "the forgotten fingers do nothing: %s" % [heard.slice(count)])
	check(reader.fingers_down() == 0 and not reader.is_waiting() and not reader.is_dragging(), "nothing is down")
	_reader()
	_tap(Vector2(10, 10), 0.0, 0.05)
	reader.clear()
	reader.update(1.0)
	check(_names() == [&"tapped"], "a waiting tap is forgotten too")


func test_a_finger_that_lands_twice_starts_over() -> void:
	_reader()
	reader.press(0, Vector2(0, 0), 0.0)
	reader.press(0, Vector2(300, 300), 0.1)
	check(heard.is_empty() and reader.fingers_down() == 1, "no jump, no drag")
	reader.lift(0, Vector2(300, 300), 0.15)
	check(heard == [[&"tapped", Vector2(300, 300), 1]], "a tap where it landed again: %s" % [heard])
	reader.move(7, Vector2(1, 1), 1.0)
	reader.lift(7, Vector2(1, 1), 1.0)
	check(_names() == [&"tapped", &"tap_confirmed"], "a finger it never saw is ignored: %s" % [_names()])


func test_what_it_reports() -> void:
	_reader()
	reader.press(3, Vector2(1, 2), 0.0)
	reader.press(5, Vector2(3, 4), 0.0)
	check(reader.fingers_down() == 2, "two fingers down")
	var positions := reader.finger_positions()
	check(positions.size() == 2 and positions[3] == Vector2(1, 2) and positions[5] == Vector2(3, 4), "%s" % positions)
	reader.finger_positions()[3] = Vector2(100, 100)
	check(reader.finger_positions()[3] == Vector2(1, 2), "a copy")
	reader.move(5, Vector2(60, 4), 0.1)
	check(reader.is_dragging(), "dragging")
	reader.lift(3, Vector2(1, 2), 0.2)
	reader.lift(5, Vector2(60, 4), 0.2)
	check(not reader.is_dragging() and reader.fingers_down() == 0, "and not any more")
