extends "res://addons/bot_kit/tests/bot_test.gd"

## BotInput reads like Godot's Input, and its signals fire once per change.


func test_reads_like_input() -> void:
	var keys := BotInput.new()
	check(not keys.is_action_pressed(&"ui_up"), "nothing held at first")
	keys.press(&"ui_up", 0.5)
	keys.press(&"ui_right")
	check(keys.is_action_pressed(&"ui_up"), "held after a press")
	check(near(keys.get_action_strength(&"ui_up"), 0.5), "its strength")
	check(near(keys.get_axis(&"ui_left", &"ui_right"), 1.0), "an axis")
	var v := keys.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	check(near(v, Vector2(1.0, -0.5).normalized(), 0.001), "a vector, at most 1 long, like Input's (%s)" % v)
	keys.press(&"ui_up", 0.0)
	check(not keys.is_action_pressed(&"ui_up"), "a press at 0 lets go")
	keys.press(&"ui_left", 3.0)
	check(near(keys.get_action_strength(&"ui_left"), 1.0), "a strength is at most 1")
	keys.release_all()
	check(keys.held().is_empty(), "release_all lets go of everything")


func test_just_pressed_lasts_its_physics_frame() -> void:
	var keys := BotInput.new()
	await tree.physics_frame
	keys.press(&"fire")
	check(keys.is_action_just_pressed(&"fire"), "just pressed in its frame")
	await tree.physics_frame
	check(not keys.is_action_just_pressed(&"fire") and keys.is_action_pressed(&"fire"), "held, not just pressed, the next frame")
	keys.release(&"fire")
	check(keys.is_action_just_released(&"fire"), "just released in its frame")
	await tree.physics_frame
	check(not keys.is_action_just_released(&"fire"), "not the next frame")


func test_signals_fire_once_per_change() -> void:
	var keys := BotInput.new()
	var log: Array = []
	keys.pressed.connect(func(action: StringName, strength: float) -> void: log.append(["press", action, strength]))
	keys.released.connect(func(action: StringName) -> void: log.append(["release", action]))
	keys.value_changed.connect(func(key: StringName, value: Variant) -> void: log.append(["value", key, value]))
	keys.press(&"fire")
	keys.press(&"fire")
	keys.press(&"fire", 0.5)
	keys.release(&"fire")
	keys.release(&"fire")
	keys.set_value(&"yaw", 1.0)
	keys.set_value(&"yaw", 1.0)
	keys.set_value(&"yaw", 2.0)
	check(log.size() == 5, "five changes, five signals (%s)" % [log])
	check(log[0] == ["press", &"fire", 1.0] and log[1] == ["press", &"fire", 0.5], "a press, then its new strength")
	check(log[2] == ["release", &"fire"], "one release")
	check(log[3] == ["value", &"yaw", 1.0] and log[4] == ["value", &"yaw", 2.0], "values on change")
	check(keys.get_value(&"yaw") == 2.0 and keys.get_value(&"pitch", 0.5) == 0.5, "values read back, with a default")


## A game forwards the keys to its own input with three connections; the signals match its methods.
func test_forwards_to_another_input() -> void:
	var keys := BotInput.new()
	var other := BotInput.new()
	keys.pressed.connect(other.press)
	keys.released.connect(other.release)
	keys.value_changed.connect(other.set_value)
	keys.press(&"ui_up", 0.7)
	keys.set_value(&"pitch", 0.2)
	check(near(other.get_action_strength(&"ui_up"), 0.7) and other.get_value(&"pitch") == 0.2, "the other input has them")
	keys.release_all()
	check(not other.is_action_pressed(&"ui_up"), "and lets them go")
