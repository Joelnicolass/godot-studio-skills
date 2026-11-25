extends Node

## The game of the example: two players take turns putting stones on a 5 × 5 board. Its moves are plain functions
## with a name: `do_place` plays, `can_place` says why not (`""` = it can) and `undo_place` takes it back.
## CommandKit finds them by those names: this file knows nothing about the kit.

const SIZE := 5

var stones: Dictionary[Vector2i, int] = {}
var turn := 0


func reset() -> void:
	stones.clear()
	turn = 0


func can_place(seat: int, cell: Vector2i) -> String:
	if seat != turn:
		return "not_your_turn"
	if stones.has(cell):
		return "occupied"
	return ""


func do_place(seat: int, cell: Vector2i) -> void:
	stones[cell] = seat
	turn = 1 - seat


func undo_place(seat: int, cell: Vector2i) -> void:
	stones.erase(cell)
	turn = seat
