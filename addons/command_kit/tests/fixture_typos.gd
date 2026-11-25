extends Node

## Test game with the mistakes the editor warns about.


func do_move() -> void:
	pass


func can_mvoe(_seat: int) -> String:
	return ""


func undo_mvoe(_seat: int) -> void:
	pass


func do_jump(_seat: int, _height: int) -> void:
	pass


func can_jump(_seat: int) -> bool:
	return true


func undo_jump(_seat: int, _a: int, _b: int, _c: int) -> void:
	pass
