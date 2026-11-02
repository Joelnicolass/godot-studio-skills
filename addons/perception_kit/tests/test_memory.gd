extends "res://addons/perception_kit/tests/perception_test.gd"

## PerceptionMemory: one stimulus per kind and key, older every frame, forgotten past a time.


func test_remember_and_refresh() -> void:
	var memory := PerceptionMemory.new()
	var first := PerceptionStimulus.new(PerceptionStimulus.HEARING, Vector3(1, 0, 0), 0.5, 7)
	check(memory.remember(first), "a new kind and key is new")
	var again := PerceptionStimulus.new(PerceptionStimulus.HEARING, Vector3(2, 0, 0), 0.9, 7)
	check(not memory.remember(again), "the same kind and key is not")
	check(memory.find(PerceptionStimulus.HEARING, 7) == first and first.position == Vector3(2, 0, 0) and near(first.strength, 0.9), "the one remembered stays the same object and takes the new values")
	check(memory.remember(PerceptionStimulus.new(PerceptionStimulus.SIGHT, Vector3.ZERO, 1.0, 7)), "the same key of another kind is new")
	check(memory.size() == 2 and not memory.is_empty(), "two remembered")
	check(memory.forget(PerceptionStimulus.SIGHT, 7) != null and memory.size() == 1, "forget one")
	memory.clear()
	check(memory.is_empty() and memory.latest() == null, "cleared: nothing, no latest")


func test_age_forgets() -> void:
	var memory := PerceptionMemory.new()
	var old := PerceptionStimulus.new(PerceptionStimulus.HEARING, Vector3(5, 0, 0), 1.0, 1)
	var fresh := PerceptionStimulus.new(PerceptionStimulus.HEARING, Vector3(6, 0, 0), 1.0, 2)
	memory.remember(old)
	memory.age(2.0, 5.0)
	memory.remember(fresh)
	var gone := memory.age(3.5, 5.0)
	check(gone.size() == 1 and gone[0] == old and gone[0].position == Vector3(5, 0, 0), "past 5 s it is forgotten, with where it was")
	check(memory.size() == 1 and near(fresh.age_s, 3.5), "the younger one stays, older (%.1f s)" % fresh.age_s)


func test_latest() -> void:
	var memory := PerceptionMemory.new()
	var heard := PerceptionStimulus.new(PerceptionStimulus.HEARING, Vector3.ZERO, 1.0, 1)
	var target := Node.new()
	var seen := PerceptionStimulus.seeing(target, PerceptionStimulus.SIGHT, Vector3.ONE, 0.2)
	memory.remember(heard)
	memory.remember(seen)
	check(memory.latest() == seen, "on a tie the seen one wins")
	memory.age(1.0, 9.0)
	memory.remember(PerceptionStimulus.new(PerceptionStimulus.HEARING, Vector3(3, 0, 0), 1.0, 1))
	check(memory.latest() == heard and heard.position == Vector3(3, 0, 0), "a younger noise wins")
	check(memory.latest(PerceptionStimulus.SIGHT) == seen, "of a kind")
	check(memory.all(PerceptionStimulus.HEARING).size() == 1 and memory.all().size() == 2, "all, of a kind or of any")
	check(seen.is_seen() and seen.target == target and not heard.is_seen() and heard.target == null, "a seen one has its target; a noise has none")
	target.free()
	check(seen.target == null, "a freed target reads as null")


func test_stop_sensing() -> void:
	var memory := PerceptionMemory.new()
	var stimulus := PerceptionStimulus.new(PerceptionStimulus.HEARING, Vector3.ZERO, 1.0, 1)
	stimulus.sensing = true
	memory.remember(stimulus)
	memory.stop_sensing()
	check(not stimulus.sensing and memory.size() == 1, "no longer sensed, still remembered")
	check(PerceptionStimulus.new(&"smell", Vector3(1, 2, 0)).position_2d == Vector2(1, 2), "position_2d")
