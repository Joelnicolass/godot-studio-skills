class_name PerceptionMemory
extends RefCounted

## What a sensor remembers: one PerceptionStimulus per kind and key, older every frame, forgotten
## past a time. A sensor owns one; a game can use its own (a squad's shared memory, a save).

var _by_kind: Dictionary[StringName, Dictionary] = {}


## Remembers `stimulus`. True when it is new (no stimulus of its kind and key yet); otherwise the
## one remembered takes its values and stays the same object (`find()` gives it).
func remember(stimulus: PerceptionStimulus) -> bool:
	var of_kind: Dictionary = _by_kind.get_or_add(stimulus.kind, {})
	var known: PerceptionStimulus = of_kind.get(stimulus.key)
	if known != null:
		known.refresh(stimulus)
		return false
	of_kind[stimulus.key] = stimulus
	return true


## The stimulus of `kind` and `key`, or null.
func find(kind: StringName, key: int) -> PerceptionStimulus:
	var of_kind: Dictionary = _by_kind.get(kind, {})
	return of_kind.get(key)


## Forgets the stimulus of `kind` and `key`; gives it, or null.
func forget(kind: StringName, key: int) -> PerceptionStimulus:
	var of_kind: Dictionary = _by_kind.get(kind, {})
	var known: PerceptionStimulus = of_kind.get(key)
	of_kind.erase(key)
	return known


## Everything grows `delta_s` older; what is older than `memory_s` is forgotten and given back.
func age(delta_s: float, memory_s: float) -> Array[PerceptionStimulus]:
	var gone: Array[PerceptionStimulus] = []
	for kind in _by_kind:
		var of_kind: Dictionary = _by_kind[kind]
		for key: int in of_kind.keys():
			var stimulus: PerceptionStimulus = of_kind[key]
			stimulus.age_s += delta_s
			if stimulus.age_s > memory_s:
				of_kind.erase(key)
				gone.append(stimulus)
	return gone


## The youngest stimulus (of `kind`, or of any): on a tie, a seen one, then the strongest. Null
## when nothing is remembered.
func latest(kind: StringName = &"") -> PerceptionStimulus:
	var best: PerceptionStimulus = null
	for stimulus in all(kind):
		if best == null or _newer(stimulus, best):
			best = stimulus
	return best


## Everything remembered (of `kind`, or of any).
func all(kind: StringName = &"") -> Array[PerceptionStimulus]:
	var out: Array[PerceptionStimulus] = []
	for each: StringName in _by_kind:
		if kind.is_empty() or each == kind:
			for stimulus: PerceptionStimulus in _by_kind[each].values():
				out.append(stimulus)
	return out


func is_empty() -> bool:
	for kind in _by_kind:
		if not _by_kind[kind].is_empty():
			return false
	return true


func size() -> int:
	var count := 0
	for kind in _by_kind:
		count += _by_kind[kind].size()
	return count


func clear() -> void:
	_by_kind.clear()


## Every stimulus is no longer being perceived (the sensor's next look sets it again).
func stop_sensing() -> void:
	for kind in _by_kind:
		for stimulus: PerceptionStimulus in _by_kind[kind].values():
			stimulus.sensing = false


static func _newer(a: PerceptionStimulus, b: PerceptionStimulus) -> bool:
	if not is_equal_approx(a.age_s, b.age_s):
		return a.age_s < b.age_s
	if a.is_seen() != b.is_seen():
		return a.is_seen()
	return a.strength > b.strength
