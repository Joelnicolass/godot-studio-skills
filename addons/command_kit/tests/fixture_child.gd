extends "res://addons/command_kit/tests/fixture_game.gd"

## Test game that extends another one: the commands of its base script count too.


func do_extra(_seat: int) -> void:
	total += 100
