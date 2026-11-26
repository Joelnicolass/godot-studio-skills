extends RefCounted

## The fingers of one touch gesture, for the RTS cameras: which ones are down, whether the gesture
## is the camera's (its first finger decides), how far it travelled and what each move asks for:
## one finger drags (past `drag_px`), two pinch (`ratio`) and twist (past `twist_start`). The
## cameras apply it; it moves nothing.


## What one finger move asks the camera for.
class Move:
	## 0: nothing (not the camera's gesture, or a third finger); 1: `drag`; 2: the two-finger fields.
	var fingers := 0
	## One finger: screen pixels to drag the view by (zero until the gesture is a drag).
	var drag := Vector2.ZERO
	## Two fingers: their middle before and after the move.
	var middle_from := Vector2.ZERO
	var middle_to := Vector2.ZERO
	## Two fingers: their gap after the move over their gap before (more than 1: apart).
	var ratio := 1.0
	## Two fingers: radians the line between them turned (clockwise on screen), once past
	## `twist_start`.
	var twist := 0.0


## Screen pixels a gesture travels before it is a drag (and no click).
var drag_px := 12.0
## Radians two fingers twist before the view turns with them, so a pinch does not turn it.
var twist_start := 0.0

# Every finger down, the camera's or not.
var _down: Dictionary[int, bool] = {}
# The camera's fingers and where each one is; empty while the gesture is not the camera's.
var _fingers: Dictionary[int, Vector2] = {}
var _ours := false
var _travel := 0.0
var _dragged := false
var _twisted := 0.0
var _turning := false


## No finger is down: the next one starts a gesture.
func is_idle() -> bool:
	return _down.is_empty()


## The camera's fingers are down.
func is_active() -> bool:
	return not _fingers.is_empty()


## The gesture travelled past `drag_px` or had two fingers: it is no click.
func is_dragged() -> bool:
	return _dragged


## A finger down at `at`. `ours` is read for the first finger of a gesture only: the fingers that
## join it follow it.
func press(index: int, at: Vector2, ours: bool) -> void:
	if _down.is_empty():
		_ours = ours
		_travel = 0.0
		_dragged = false
	_down[index] = true
	if not _ours:
		return
	_fingers[index] = at
	if _fingers.size() >= 2:
		# A second finger makes it a gesture, never a click.
		_dragged = true
		_twisted = 0.0
		_turning = false


func lift(index: int) -> void:
	_down.erase(index)
	_fingers.erase(index)


## Forgets every finger (the window lost the focus, touch was turned off).
func clear() -> void:
	_down.clear()
	_fingers.clear()


## A finger moved to `at`, `relative` from where it was.
func move(index: int, at: Vector2, relative: Vector2) -> Move:
	var step := Move.new()
	if not _fingers.has(index):
		return step
	if _fingers.size() == 1:
		_fingers[index] = at
		step.fingers = 1
		if _dragged or _travel + relative.length() > drag_px:
			step.drag = relative
		_travel += relative.length()
		_dragged = _dragged or _travel > drag_px
		return step
	# The two lowest fingers pinch; a third one only moves.
	var ids := _fingers.keys()
	ids.sort()
	var first: int = ids[0]
	var second: int = ids[1]
	var a0: Vector2 = _fingers[first]
	var b0: Vector2 = _fingers[second]
	_fingers[index] = at
	if index != first and index != second:
		return step
	var a1: Vector2 = _fingers[first]
	var b1: Vector2 = _fingers[second]
	step.fingers = 2
	step.middle_from = (a0 + b0) * 0.5
	step.middle_to = (a1 + b1) * 0.5
	var gap := a0.distance_to(b0)
	if gap > 1.0:
		step.ratio = a1.distance_to(b1) / gap
	var turn := angle_difference((b0 - a0).angle(), (b1 - a1).angle())
	_twisted += turn
	_turning = _turning or absf(_twisted) > twist_start
	if _turning:
		step.twist = turn
	return step
