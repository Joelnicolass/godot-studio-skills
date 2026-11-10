extends BotMode

## A BotMode for the tests: it wants `want`, counts its calls and, with a `point`, walks there.

var want := 0.0
var point := Vector3.INF
var entered := 0
var ticks := 0
var exited := 0
var arrived := false


func _want(_bot: Bot3D) -> float:
	return want


func _enter(_bot: Bot3D) -> void:
	entered += 1


func _tick(bot: Bot3D, delta: float) -> void:
	ticks += 1
	if point != Vector3.INF and not bot.walk_to(point, delta):
		arrived = true


func _exit(_bot: Bot3D) -> void:
	exited += 1
