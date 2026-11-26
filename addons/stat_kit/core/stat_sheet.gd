class_name StatSheet
extends RefCounted

## The stats of one thing as plain data: no nodes, no scene. Each stat has a base value, optional limits and a list of
## `StatModifier`s. Its value is `(base + every ADD) × (1 + every PERCENT) × every MUL`; when a SET applies, the last
## SET added wins instead. Then the value is kept between the stat's limits.
## A game keeps one per character, city or player in its rules; `StatBlock` wraps one for the editor.
## Values are floats: a game that wants whole numbers rounds them itself (`roundi(sheet.value(&"attack"))`).

## The value of `stat` is now `value`. Only when the final value really changed.
signal stat_changed(stat: StringName, value: float)

var _bases: Dictionary[StringName, float] = {}
var _mins: Dictionary[StringName, float] = {}
var _maxs: Dictionary[StringName, float] = {}
var _entries: Array[_Entry] = []
# The value of every stat, kept up to date after each change: `value()` reads it, `stat_changed` compares with it.
var _known: Dictionary[StringName, float] = {}


## A sheet with `start_bases` (`{stat: base}`, optional).
func _init(start_bases: Dictionary = {}) -> void:
	for key: Variant in start_bases:
		var stat := StringName(str(key))
		if stat == &"":
			push_error("StatSheet: a base has an empty stat")
			continue
		_bases[stat] = float(start_bases[key])
	_refresh(stats())


## Sets the base value of `stat`. An empty `stat` is an error.
func set_base(stat: StringName, amount: float) -> void:
	if stat == &"":
		push_error("StatSheet.set_base: the stat is empty")
		return
	_bases[stat] = amount
	_refresh([stat])


## The base value of `stat` (0 when it has none).
func base(stat: StringName) -> float:
	return _bases.get(stat, 0.0)


## A copy of every base value, by stat.
func bases() -> Dictionary[StringName, float]:
	return _bases.duplicate()


## Keeps `stat` between `min_value` and `max_value`, after every modifier (a SET too). Leave a side out for no limit
## there: `set_limits(&"moves", 1)`. A minimum above the maximum or an empty `stat` is an error.
func set_limits(stat: StringName, min_value: float = -INF, max_value: float = INF) -> void:
	if stat == &"":
		push_error("StatSheet.set_limits: the stat is empty")
		return
	if min_value > max_value:
		push_error("StatSheet.set_limits: %s has a minimum above its maximum (%s > %s)" % [stat, min_value, max_value])
		return
	if min_value > -INF:
		_mins[stat] = min_value
	else:
		_mins.erase(stat)
	if max_value < INF:
		_maxs[stat] = max_value
	else:
		_maxs.erase(stat)
	_refresh([stat])


## Takes the limits of `stat` away.
func clear_limits(stat: StringName) -> void:
	_mins.erase(stat)
	_maxs.erase(stat)
	_refresh([stat])


## The limits of `stat` as `Vector2(min, max)`: `-INF` or `INF` on a side with no limit.
func limits(stat: StringName) -> Vector2:
	var low: float = _mins.get(stat, -INF)
	var high: float = _maxs.get(stat, INF)
	return Vector2(low, high)


## Adds `mod`. With `source`, it counts as given by `source` instead of `mod.source`, so one `.tres` serves two rings
## (`add(ring, &"left_ring")`, `add(ring, &"right_ring")`). The same modifier twice counts twice (it stacks).
## Changing the modifier later (its amount, its stat) applies at once. A null `mod` or an empty stat is an error.
func add(mod: StatModifier, source: StringName = &"") -> void:
	if _append(mod, source, false):
		_refresh([mod.stat])


## Adds every modifier of `mods`, all given by `source` when one is passed: an item with several bonuses.
## One `stat_changed` per stat, at the end.
func add_all(mods: Array[StatModifier], source: StringName = &"") -> void:
	var touched: Array[StringName] = []
	for mod in mods:
		if _append(mod, source, false):
			touched.append(mod.stat)
	_refresh(touched)


## Takes away one occurrence of `mod`; with `source`, one added with that source. False when there is none.
## A modifier that came back from `from_dict` is a copy: when `mod` itself is not in the sheet, a loaded copy with
## the same stat, op, amount and source counts as it.
func remove(mod: StatModifier, source: StringName = &"") -> bool:
	if mod == null:
		return false
	var index := -1
	for i in _entries.size():
		if _entries[i].mod == mod and (source == &"" or _entries[i].source() == source):
			index = i
			break
	if index < 0:
		var wanted := source if source != &"" else mod.source
		for i in _entries.size():
			var entry := _entries[i]
			if entry.loaded and entry.source() == wanted and _same(entry.mod, mod):
				index = i
				break
	if index < 0:
		return false
	var taken := _entries[index]
	_entries.remove_at(index)
	_forget(taken.mod)
	_refresh([taken.mod.stat])
	return true


## Takes away every modifier given by `source` (the one passed to `add`, or the modifier's own), in one go.
## Returns how many it took. `remove_source(&"")` takes the ones with no source.
func remove_source(source: StringName) -> int:
	var kept: Array[_Entry] = []
	var taken: Array[_Entry] = []
	var touched: Array[StringName] = []
	for entry in _entries:
		if entry.source() == source:
			taken.append(entry)
			touched.append(entry.mod.stat)
		else:
			kept.append(entry)
	if taken.is_empty():
		return 0
	_entries = kept
	for entry in taken:
		_forget(entry.mod)
	_refresh(touched)
	return taken.size()


## Every modifier, or those of one `stat`, in the order they were added (a copy of the list).
func modifiers(stat: StringName = &"") -> Array[StatModifier]:
	var list: Array[StatModifier] = []
	for entry in _entries:
		if stat == &"" or entry.mod.stat == stat:
			list.append(entry.mod)
	return list


## The source each modifier counts as given by, in the same order as `modifiers(stat)`.
## `sources().has(&"blessing")` tells whether a blessing is on.
func sources(stat: StringName = &"") -> Array[StringName]:
	var list: Array[StringName] = []
	for entry in _entries:
		if stat == &"" or entry.mod.stat == stat:
			list.append(entry.source())
	return list


## One line per modifier of `stat`, in the order added, with the source it counts as given by: a tooltip.
func describe(stat: StringName) -> PackedStringArray:
	var lines := PackedStringArray()
	for entry in _entries:
		if entry.mod.stat == stat:
			lines.append(entry.mod.describe(entry.source()))
	return lines


## Takes every modifier away; the bases and the limits stay.
func clear_modifiers() -> void:
	if _entries.is_empty():
		return
	var taken := _entries
	_entries = []
	for entry in taken:
		_forget(entry.mod)
	_refresh(_known.keys())


## The final value of `stat`: `(base + every ADD) × (1 + every PERCENT) × every MUL`, or the last SET added when
## there is one, kept between its limits. 0 for a stat the sheet does not know.
func value(stat: StringName) -> float:
	return _known.get(stat, 0.0)


## The final value of every stat, sorted by stat.
func values() -> Dictionary[StringName, float]:
	var all: Dictionary[StringName, float] = {}
	for stat in stats():
		all[stat] = value(stat)
	return all


## Every stat with a base, a limit or a modifier, sorted.
func stats() -> Array[StringName]:
	var seen: Dictionary[StringName, bool] = {}
	for stat in _bases:
		seen[stat] = true
	for stat in _mins:
		seen[stat] = true
	for stat in _maxs:
		seen[stat] = true
	for entry in _entries:
		if entry.mod.stat != &"":
			seen[entry.mod.stat] = true
	var list: Array[StringName] = []
	list.assign(seen.keys())
	list.sort_custom(_before)
	return list


## Plain data for a save, a network snapshot or a replay check: `{"bases": {stat: base}, "limits": {stat: {"min",
## "max"}}, "modifiers": [StatModifier.to_dict(), …]}`. The modifiers keep the order they were added in and the source
## they count as given by; a side with no limit is left out.
func to_dict() -> Dictionary:
	var bases_out: Dictionary = {}
	for stat in _sorted(_bases.keys()):
		bases_out[String(stat)] = _bases[stat]
	var limits_out: Dictionary = {}
	for stat in _sorted(_mins.keys() + _maxs.keys()):
		var side: Dictionary = {}
		if _mins.has(stat):
			side["min"] = _mins[stat]
		if _maxs.has(stat):
			side["max"] = _maxs[stat]
		limits_out[String(stat)] = side
	var mods_out: Array[Dictionary] = []
	for entry in _entries:
		var saved := entry.mod.to_dict()
		saved["source"] = String(entry.source())
		mods_out.append(saved)
	return {"bases": bases_out, "limits": limits_out, "modifiers": mods_out}


## Rebuilds a sheet from `to_dict()`. The modifiers are new copies: take them away with `remove_source`, or with
## `remove` and a modifier equal to the one you added. What cannot be read is an error and is skipped.
static func from_dict(data: Dictionary) -> StatSheet:
	var saved_bases: Variant = data.get("bases", {})
	var bases_in: Dictionary = saved_bases if saved_bases is Dictionary else {}
	var sheet := StatSheet.new(bases_in)
	var saved_limits: Variant = data.get("limits", {})
	var limits_in: Dictionary = saved_limits if saved_limits is Dictionary else {}
	for key: Variant in limits_in:
		var side: Variant = limits_in[key]
		if not side is Dictionary:
			push_error("StatSheet.from_dict: the limits of %s are not a Dictionary" % [key])
			continue
		var bounds: Dictionary = side
		sheet.set_limits(StringName(str(key)), float(bounds.get("min", -INF)), float(bounds.get("max", INF)))
	var saved_mods: Variant = data.get("modifiers", [])
	var list: Array = saved_mods if saved_mods is Array else []
	for entry: Variant in list:
		if not entry is Dictionary:
			push_error("StatSheet.from_dict: a modifier is not a Dictionary (%s)" % [entry])
			continue
		var mod_data: Dictionary = entry
		var mod := StatModifier.from_dict(mod_data)
		if mod != null:
			sheet._append(mod, &"", true)
	sheet._refresh(sheet.stats())
	return sheet


# Adds one entry without telling anyone; false (and an error) when `mod` cannot go in a sheet.
func _append(mod: StatModifier, source: StringName, loaded: bool) -> bool:
	if mod == null:
		push_error("StatSheet.add: the modifier is null")
		return false
	if mod.stat == &"":
		push_error("StatSheet.add: the modifier has no stat")
		return false
	_entries.append(_Entry.new(mod, source, loaded))
	if not mod.changed.is_connected(_on_modifier_changed):
		mod.changed.connect(_on_modifier_changed)
	return true


# The value of `stat` worked out from the base, the modifiers and the limits.
func _compute(stat: StringName) -> float:
	var added := base(stat)
	var percent := 0.0
	var factor := 1.0
	var fixed := false
	var fixed_value := 0.0
	for entry in _entries:
		var mod := entry.mod
		if mod.stat != stat:
			continue
		match mod.op:
			StatModifier.Op.ADD:
				added += mod.amount
			StatModifier.Op.PERCENT:
				percent += mod.amount
			StatModifier.Op.MUL:
				factor *= mod.amount
			StatModifier.Op.SET:
				fixed = true
				fixed_value = mod.amount
	var raw := fixed_value if fixed else added * (1.0 + percent) * factor
	var low: float = _mins.get(stat, -INF)
	var high: float = _maxs.get(stat, INF)
	return clampf(raw, low, high)


# Works out each of `touched` again and emits `stat_changed` (sorted) for those whose value is not what it was.
func _refresh(touched: Array) -> void:
	var list: Array[StringName] = []
	for item: Variant in touched:
		var stat := StringName(str(item))
		if stat != &"" and not list.has(stat):
			list.append(stat)
	list.sort_custom(_before)
	var live := stats()
	for stat in list:
		var before: float = _known.get(stat, 0.0)
		var now := _compute(stat)
		if live.has(stat):
			_known[stat] = now
		else:
			_known.erase(stat)
		if not is_equal_approx(before, now):
			stat_changed.emit(stat, now)


# Stops listening to `mod` once no entry holds it.
func _forget(mod: StatModifier) -> void:
	for entry in _entries:
		if entry.mod == mod:
			return
	if mod.changed.is_connected(_on_modifier_changed):
		mod.changed.disconnect(_on_modifier_changed)


# A modifier in the sheet changed (its amount, its op, even its stat): every stat is worked out again.
func _on_modifier_changed() -> void:
	var touched: Array[StringName] = stats()
	touched.append_array(_known.keys())
	_refresh(touched)


static func _same(a: StatModifier, b: StatModifier) -> bool:
	return a.stat == b.stat and a.op == b.op and is_equal_approx(a.amount, b.amount)


static func _sorted(keys: Array) -> Array[StringName]:
	var list: Array[StringName] = []
	for key: Variant in keys:
		var stat := StringName(str(key))
		if not list.has(stat):
			list.append(stat)
	list.sort_custom(_before)
	return list


static func _before(a: StringName, b: StringName) -> bool:
	return String(a) < String(b)


# One modifier in the sheet, with the source the code passed when it added it (empty: the modifier's own).
class _Entry:
	var mod: StatModifier
	var given: StringName
	var loaded: bool

	func _init(mod_in: StatModifier, given_in: StringName, loaded_in: bool) -> void:
		mod = mod_in
		given = given_in
		loaded = loaded_in

	func source() -> StringName:
		return given if given != &"" else mod.source
