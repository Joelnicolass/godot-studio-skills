class_name GestureReader
extends RefCounted

## The fingers on one surface, read as gestures: a tap with one or more fingers, a double tap, a long
## press, a swipe, a drag with any number of fingers, a pinch and a twist. It draws nothing and reads no
## clock: whatever feeds it passes the time in seconds (`now`) with each finger, and calls `update(now)`
## while `is_waiting()` so a long press, a confirmed tap and a two-finger move arrive on time.
## `GestureArea` feeds its own; a test or your own input code feeds a `GestureReader.new()`.
##
## A gesture starts when a finger lands on an empty surface and ends when the last finger lifts.
## `fingers` in every signal is the most fingers that were down at once in the gesture so far.

## Every finger lifted without moving past `slop_px`, less than `long_press_s` after the last finger
## landed. `at`: where the fingers landed (their middle). Each tap of a double tap arrives here too.
signal tapped(at: Vector2, fingers: int)
## The second tap of a pair: it landed within `double_tap_s` of the first one lifting (and not within
## `DOUBLE_TAP_MIN_S`, a bounce), within `double_tap_px` of it, with as many fingers. `tapped` came first.
signal double_tapped(at: Vector2, fingers: int)
## A tap that no second tap followed in `double_tap_s`: for a tap that must not also start a double tap.
## A `clear()` before that forgets it.
signal tap_confirmed(at: Vector2, fingers: int)
## The fingers stayed down `long_press_s` (counted from the last one that landed) without moving past
## `slop_px`. No tap or swipe follows; moving on drags. `at`: where the fingers are.
signal long_pressed(at: Vector2, fingers: int)
## The fingers of a long press lifted, also after dragging, or the reader was cleared. `at`: where they
## were. For «hold to charge, let go to fire».
signal long_press_ended(at: Vector2, fingers: int)
## The fingers lifted after a quick line: at least `swipe_min_px`, at most `swipe_max_s` after they
## started to move, without a long press, a pinch or a twist. `direction`: a unit vector, snapped to
## `swipe_directions`. `drag_ended` came first.
signal swiped(direction: Vector2, fingers: int)
## The fingers moved past `slop_px` (from where they landed, or from where they were held). `at`: their
## middle when the drag began, before the slop: the first `dragged` covers the slop, so whatever follows
## the fingers stays under them.
signal drag_started(at: Vector2, fingers: int)
## The middle of the fingers moved by `relative` since the last call (`center()` says where it is). A
## finger landing or lifting moves nothing.
signal dragged(relative: Vector2, fingers: int)
## The last finger of a drag lifted, or the reader was cleared (`velocity` zero). `velocity`: pixels per
## second over the last tenth of a second before lifting, to throw what was dragged; zero if the fingers
## had stopped.
signal drag_ended(velocity: Vector2, fingers: int)
## Two fingers moved apart (`ratio` above 1) or together (below 1) since the last call, once their gap
## changed by more than `slop_px`. `center`: the middle of the two. A zoom multiplies by `ratio`.
signal pinched(ratio: float, center: Vector2)
## The line between two fingers turned by `radians` (clockwise on screen) since the last call, once it
## turned past `twist_start_deg`. `center`: the middle of the two. Fingers closer than twice `slop_px`
## turn nothing: their angle is noise.
signal twisted(radians: float, center: Vector2)

## How `swiped` reports its direction.
enum Directions {
	FOUR,  ## `Vector2.LEFT`, `RIGHT`, `UP` or `DOWN`: compare with `==`.
	EIGHT,  ## The four, plus the four diagonals.
	ANY,  ## The exact direction of the line.
}

## The fingers' recent motion that counts for the velocity of `drag_ended`, in seconds.
const VELOCITY_WINDOW_S := 0.1
## A gap between two moves longer than this means the fingers had stopped (Android's 40 ms): the velocity
## counts only what came after it.
const STOPPED_GAP_S := 0.04
## The velocity never divides by less than one frame at 120 fps: moves read in the same frame carry no
## time between them.
const MIN_SPAN_S := 1.0 / 120.0
## A second tap that lands sooner than this after the first one lifted is a bounce of the screen, and is
## ignored (Android's 40 ms).
const DOUBLE_TAP_MIN_S := 0.04

## Pixels the fingers can move and still tap or hold. Past it they drag; two fingers whose gap changes
## by more than it pinch.
var slop_px := 12.0:
	set(value):
		slop_px = maxf(value, 0.0)
## Seconds held still for a long press, from the last finger that landed. A tap lifts before it.
var long_press_s := 0.5:
	set(value):
		long_press_s = maxf(value, 0.01)
## Seconds between a tap lifting and the next one landing for a double tap; `tap_confirmed` waits this.
var double_tap_s := 0.3:
	set(value):
		double_tap_s = maxf(value, 0.0)
## Pixels between two taps for a double tap.
var double_tap_px := 50.0:
	set(value):
		double_tap_px = maxf(value, 0.0)
## Pixels the middle of the fingers travels for a swipe.
var swipe_min_px := 60.0:
	set(value):
		swipe_min_px = maxf(value, 1.0)
## Seconds from the fingers starting to move to the last one lifting, for a swipe.
var swipe_max_s := 0.5:
	set(value):
		swipe_max_s = maxf(value, 0.01)
## The directions `swiped` snaps to.
var swipe_directions := Directions.FOUR
## Degrees two fingers turn before `twisted` starts, so a pinch does not also turn.
var twist_start_deg := 10.0:
	set(value):
		twist_start_deg = clampf(value, 0.0, 180.0)

# Where each finger down is now, and where each finger of the gesture landed (kept after it lifts).
var _at: Dictionary[int, Vector2] = {}
var _landed: Dictionary[int, Vector2] = {}
var _now := 0.0
var _start_s := 0.0
var _most := 0
# The middle of the fingers down, and how far it travelled in the gesture (finger changes move nothing).
var _center := Vector2.ZERO
var _moved := Vector2.ZERO
# Nothing moved past the slop, pinched or twisted: the gesture can still be a tap or a long press.
var _still := true
var _moving_from := 0.0
var _held := false
var _hold_from := 0.0
var _drag_from := Vector2.ZERO
var _dragging := false
# The gesture pinched or twisted: it is no swipe.
var _shaped := false
var _sample_s := PackedFloat64Array()
var _sample_moved := PackedVector2Array()
# The two lowest fingers pinch and twist.
var _pair: Array[int] = []
# Where the pair was when it was last read, and which of the two moved since: they are read together,
# so two fingers moving one event after the other do not look like a pinch. One that moved alone is
# read on the second `update()`, in case the other one comes a frame later.
var _pair_seen := PackedVector2Array()
var _pair_moved: Dictionary[int, bool] = {}
var _pair_waited := false
var _gap_from := 1.0
var _gap := 1.0
var _turned := 0.0
var _pinching := false
var _twisting := false
# The last tap, until a second tap doubles it or `double_tap_s` confirms it.
var _tap_waits := false
var _tap_s := 0.0
var _tap_at := Vector2.ZERO
var _tap_fingers := 0


## A finger `index` landed at `at`. A finger already down that lands again lost its lift: the reader
## starts over.
func press(index: int, at: Vector2, now: float) -> void:
	_tick(now)
	if _at.has(index):
		clear()
	if _at.is_empty():
		_begin(now)
	_at[index] = at
	_landed[index] = at
	_most = maxi(_most, _at.size())
	_rebase()
	if not _held:
		_hold_from = now


## Finger `index` is at `at` now. A finger the reader does not know is ignored.
func move(index: int, at: Vector2, now: float) -> void:
	_tick(now)
	if not _at.has(index) or _at[index] == at:
		return
	if _pair_moved.has(index):
		_read_pair()
	_at[index] = at
	var step := _centroid() - _center
	_center += step
	_moved += step
	_sample(now)
	if _still and (at.distance_to(_landed[index]) > slop_px or _moved.length() > slop_px):
		_start_moving()
	if not _dragging and (_moved - _drag_from).length() > slop_px:
		_dragging = true
		drag_started.emit(_center - (_moved - _drag_from), _most)
		dragged.emit(_moved - _drag_from, _most)
	elif _dragging and step != Vector2.ZERO:
		dragged.emit(step, _most)
	if _pair.has(index):
		_pair_moved[index] = true
		if _pair_moved.size() == 2:
			_read_pair()


## Finger `index` lifted at `at`. The last finger ends the gesture.
func lift(index: int, at: Vector2, now: float) -> void:
	_tick(now)
	if not _at.has(index):
		return
	move(index, at, now)
	if not _pair_moved.is_empty():
		_read_pair()
	_at.erase(index)
	if _at.is_empty():
		_finish(now)
	else:
		_rebase()
	_confirm_if_due(now)


## Forgets every finger and the tap that waited for a second one (the window lost the focus, the
## surface hid, the system canceled the touch). A drag under way ends with `velocity` zero and a long
## press with `long_press_ended`; nothing else is emitted.
func clear() -> void:
	var was_dragging := _dragging
	var was_held := _held and not _at.is_empty()
	_at.clear()
	_dragging = false
	_tap_waits = false
	_held = false
	_still = true
	_pair.clear()
	_pair_moved.clear()
	_pair_waited = false
	if was_dragging:
		drag_ended.emit(Vector2.ZERO, _most)
	if was_held:
		long_press_ended.emit(_center, _most)


## Advances the clock to `now`: a long press or a confirmed tap that is due arrives here, and two fingers
## of which only one moved are read. Call it every frame while `is_waiting()`.
func update(now: float) -> void:
	_tick(now)
	if not _pair_moved.is_empty():
		if _pair_waited:
			_read_pair()
		else:
			_pair_waited = true


## A long press, a confirmed tap or a two-finger move may still arrive: keep calling `update`.
func is_waiting() -> bool:
	return _tap_waits or not _pair_moved.is_empty() or (not _at.is_empty() and _still and not _held)


## How many fingers are down now (the signals' `fingers` is the most at once in the gesture).
func fingers_down() -> int:
	return _at.size()


## Where each finger down is, by index (a copy).
func finger_positions() -> Dictionary[int, Vector2]:
	return _at.duplicate()


## The middle of the fingers down; once they lifted, where they were. During a drag, where the drag is
## now: an aiming line from `drag_started(at)` to here.
func center() -> Vector2:
	return _center


## The fingers moved past the slop and drag.
func is_dragging() -> bool:
	return _dragging


## How far the current fingers are into a long press, 0 to 1, as of the last call (0: no finger down,
## or they moved, or the long press already happened). Draw a ring with it.
func hold_progress() -> float:
	if _at.is_empty() or not _still or _held:
		return 0.0
	return clampf((_now - _hold_from) / long_press_s, 0.0, 1.0)


func _tick(now: float) -> void:
	_now = maxf(_now, now)
	var holds := not _at.is_empty() and _still and not _held and _now - _hold_from >= long_press_s
	if holds:
		_held = true
		_drag_from = _moved
	# A tap that waited is settled first: it happened before this hold.
	_confirm_if_due(_now)
	if holds:
		long_pressed.emit(_center, _most)


func _begin(now: float) -> void:
	_start_s = now
	_landed.clear()
	_most = 0
	_moved = Vector2.ZERO
	_drag_from = Vector2.ZERO
	_still = true
	_held = false
	_dragging = false
	_shaped = false
	_sample_s.clear()
	_sample_moved.clear()
	_sample(now)


# The gesture is no tap or long press any more: from now on the swipe's clock runs.
func _start_moving() -> void:
	_still = false
	_moving_from = _now
	_confirm_if_due(_now)


# The fingers changed: the middle and the pair start again from here, so nothing jumps.
func _rebase() -> void:
	_center = _centroid()
	var ids := _at.keys()
	ids.sort()
	_pair.clear()
	_pair_moved.clear()
	_pair_waited = false
	if ids.size() >= 2:
		_pair.assign(ids.slice(0, 2))
		var points := _pair_points()
		_pair_seen = points
		_gap_from = maxf(points[0].distance_to(points[1]), 1.0)
		_gap = _gap_from
		_turned = 0.0
		_pinching = false
		_twisting = false


func _read_pair() -> void:
	_pair_moved.clear()
	_pair_waited = false
	var points := _pair_points()
	if points.size() < 2 or _pair_seen.size() < 2:
		return
	var before := _pair_seen
	_pair_seen = points
	var center_now := (points[0] + points[1]) * 0.5
	var distance := points[0].distance_to(points[1])
	var gap := maxf(distance, 1.0)
	if not _pinching and absf(gap - _gap_from) > slop_px:
		_pinching = true
		_shaped = true
		_gap = gap
		if _still:
			_start_moving()
	elif _pinching and gap != _gap:
		pinched.emit(gap / _gap, center_now)
		_gap = gap
	# Two fingers almost on top of each other have no angle worth reading.
	if minf(before[0].distance_to(before[1]), distance) < maxf(slop_px * 2.0, 1.0):
		return
	var turn := angle_difference((before[1] - before[0]).angle(), (points[1] - points[0]).angle())
	if not _twisting:
		_turned += turn
		if absf(_turned) > deg_to_rad(twist_start_deg):
			_twisting = true
			_shaped = true
			if _still:
				_start_moving()
	elif turn != 0.0:
		twisted.emit(turn, center_now)


func _finish(now: float) -> void:
	if _dragging:
		_dragging = false
		drag_ended.emit(_velocity(now), _most)
	if _held:
		long_press_ended.emit(_center, _most)
	elif _still and now - _hold_from < long_press_s:
		_tap(now)
	elif not _shaped and now - _moving_from <= swipe_max_s and _moved.length() >= swipe_min_px:
		swiped.emit(_direction(_moved), _most)
	_held = false
	_pair.clear()


func _tap(now: float) -> void:
	if _tap_waits and _start_s - _tap_s < DOUBLE_TAP_MIN_S:
		return
	var at := Vector2.ZERO
	for landed: Vector2 in _landed.values():
		at += landed
	at /= _landed.size()
	var doubles := (
		_tap_waits
		and _start_s - _tap_s <= double_tap_s
		and _tap_fingers == _most
		and _tap_at.distance_to(at) <= double_tap_px
	)
	if _tap_waits and not doubles:
		_tap_waits = false
		tap_confirmed.emit(_tap_at, _tap_fingers)
	tapped.emit(at, _most)
	if doubles:
		_tap_waits = false
		double_tapped.emit(at, _most)
		return
	_tap_waits = true
	_tap_s = now
	_tap_at = at
	_tap_fingers = _most


# The waiting tap is confirmed once `double_tap_s` passed, unless a second tap that started in time is
# still down and can double it.
func _confirm_if_due(now: float) -> void:
	if not _tap_waits or now - _tap_s <= double_tap_s:
		return
	var second_in_time := not _at.is_empty() and _start_s - _tap_s <= double_tap_s and _still and not _held
	if second_in_time:
		return
	_tap_waits = false
	tap_confirmed.emit(_tap_at, _tap_fingers)


# The motion of the last `VELOCITY_WINDOW_S`, and one sample from before it.
func _sample(now: float) -> void:
	_sample_s.append(now)
	_sample_moved.append(_moved)
	while _sample_s.size() > 2 and now - _sample_s[1] > VELOCITY_WINDOW_S:
		_sample_s.remove_at(0)
		_sample_moved.remove_at(0)


func _velocity(now: float) -> Vector2:
	var last := _sample_s.size() - 1
	# Fingers that stopped before lifting throw nothing.
	if last < 1 or now - _sample_s[last] > VELOCITY_WINDOW_S:
		return Vector2.ZERO
	# Back over the window, until a gap where the fingers had stopped.
	var first := last
	while (
		first > 0
		and _sample_s[last] - _sample_s[first - 1] <= VELOCITY_WINDOW_S
		and _sample_s[first] - _sample_s[first - 1] <= STOPPED_GAP_S
	):
		first -= 1
	var seconds := _sample_s[last] - _sample_s[first]
	if first == last:
		# One move after a stop: it took at most STOPPED_GAP_S.
		first = last - 1
		seconds = clampf(_sample_s[last] - _sample_s[first], MIN_SPAN_S, STOPPED_GAP_S)
	return (_sample_moved[last] - _sample_moved[first]) / maxf(seconds, MIN_SPAN_S)


func _direction(line: Vector2) -> Vector2:
	match swipe_directions:
		Directions.ANY:
			return line.normalized()
		Directions.EIGHT:
			var eighth := posmod(roundi(line.angle() / (TAU / 8.0)), 8)
			var diagonal := sqrt(0.5)
			var all: Array[Vector2] = [
				Vector2.RIGHT,
				Vector2(diagonal, diagonal),
				Vector2.DOWN,
				Vector2(-diagonal, diagonal),
				Vector2.LEFT,
				Vector2(-diagonal, -diagonal),
				Vector2.UP,
				Vector2(diagonal, -diagonal),
			]
			return all[eighth]
	if absf(line.x) >= absf(line.y):
		return Vector2.RIGHT if line.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if line.y > 0.0 else Vector2.UP


func _centroid() -> Vector2:
	if _at.is_empty():
		return _center
	var sum := Vector2.ZERO
	for at: Vector2 in _at.values():
		sum += at
	return sum / _at.size()


func _pair_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in _pair:
		if _at.has(index):
			points.append(_at[index])
	return points
