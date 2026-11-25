extends Node

## Test game whose can_ function has no return type: it answers whatever `answer` holds.

var answer: Variant = ""
var ran := 0


func can_flag(_seat: int):
	return answer


func do_flag(_seat: int) -> void:
	ran += 1
