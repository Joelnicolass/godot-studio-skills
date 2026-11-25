extends RefCounted

## Test rules that are not a node: they keep their own CommandLog, like a game with headless rules.

var points := 0
var commands := CommandLog.new(self)


func do_score(_seat: int, amount: int) -> void:
	points += amount


func undo_score(_seat: int, amount: int) -> void:
	points -= amount
