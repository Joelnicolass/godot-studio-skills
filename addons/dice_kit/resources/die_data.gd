@tool
@icon("res://addons/dice_kit/icons/die_data.svg")
class_name DieData
extends Resource

## A kind of die: its faces, in order. Every face is as likely as the others; a face that should come up more often
## goes in the list more than once. A face's place in `faces` (0 first) is the index a `DiceRoll` keeps for each die.
## Ready dice to drag into the inspector: `addons/dice_kit/dice/d4.tres`, `d6`, `d8`, `d10`, `d12` and `d20` (copy one
## into your game before editing it: a new install of the kit writes over that folder).

## The faces, in order. Changing the list, or a value inside a face, applies at once: a roller's warnings and a tray's
## dice follow. A die with an empty slot cannot roll (see `can_roll()`).
@export var faces: Array[DieFace] = []:
	set(value):
		_watch(value)
		faces = value
		emit_changed()
## The shape views draw for this kind of die (a d8 model), so mixed dice each keep theirs. Empty: the view's own
## (`DiceTray3D.die_mesh`, or a cube). The ready dice have none.
@export var mesh: Mesh:
	set(value):
		mesh = value
		emit_changed()

var _watched: Array[DieFace] = []


## How many faces it has (empty slots included).
func sides() -> int:
	return faces.size()


## True when it has faces and none of its slots is empty. A die that cannot roll gives an error and an empty roll, and
## draws nothing from the rng.
func can_roll() -> bool:
	return not faces.is_empty() and not faces.has(null)


## Rolls `n` dice of this kind, drawing one number from `rng` per die. `n` under 1, a die that cannot roll or no `rng`:
## an error and an empty roll.
func roll(n: int, rng: RandomNumberGenerator) -> DiceRoll:
	if n < 1:
		push_error("DieData.roll: n must be 1 or more (%d)" % n)
		return DiceRoll.new()
	var pool: Array[DieData] = []
	pool.resize(n)
	pool.fill(self)
	return DiceRoll.of(pool, rng)


## A die with `side_count` faces worth 1 to `side_count`, without tags or icons (`numbered(6)` is a d6). Under 1: an
## error and a die without faces.
static func numbered(side_count: int) -> DieData:
	var die := DieData.new()
	if side_count < 1:
		push_error("DieData.numbered: a die needs 1 side or more (%d)" % side_count)
		return die
	var list: Array[DieFace] = []
	for number in range(1, side_count + 1):
		list.append(DieFace.new(number))
	die.faces = list
	return die


# Listens to `changed` of every face in the list, and only to those.
func _watch(list: Array[DieFace]) -> void:
	for face in _watched:
		if face.changed.is_connected(emit_changed):
			face.changed.disconnect(emit_changed)
	_watched.clear()
	for face in list:
		if face != null and not _watched.has(face):
			face.changed.connect(emit_changed)
			_watched.append(face)
