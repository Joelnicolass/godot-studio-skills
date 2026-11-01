extends Node

## A bot on a pawn whose seat nobody plays (world.gd puts it there, on the server). It walks to a point, then to
## another, by pressing the player's keys (MpInput.bot_press): the pawn's mp_move moves it as it moves a player. While a
## player plays the seat (a late player, or its own player back) it waits: MpInput reads that player's keys.

## Where it walks: a point inside this rectangle, a new one each time it gets there.
const AREA := Rect2(160, 100, 640, 340)
## Closer than this (pixels) to its point: there.
const ARRIVED := 12.0

var _input: MpInput
var _target := Vector2.ZERO


func _ready() -> void:
	_input = get_parent().get_node(^"MpInput")
	_target = _pick()


func _physics_process(_delta: float) -> void:
	if _input.has_player():
		return
	var to := _target - (get_parent() as Node2D).global_position
	if to.length() < ARRIVED:
		_target = _pick()
		return
	var push := to.normalized()
	_hold(&"ui_right", &"ui_left", push.x)
	_hold(&"ui_down", &"ui_up", push.y)


## One axis: the key on the side to go, as strong as that side of the direction; the other key let go.
func _hold(positive: StringName, negative: StringName, amount: float) -> void:
	_input.bot_press(positive if amount > 0.0 else negative, absf(amount))
	_input.bot_release(negative if amount > 0.0 else positive)


func _pick() -> Vector2:
	return Vector2(randf_range(AREA.position.x, AREA.end.x), randf_range(AREA.position.y, AREA.end.y))
