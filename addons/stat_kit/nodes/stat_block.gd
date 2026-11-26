@tool
@icon("res://addons/stat_kit/icons/stat_block.svg")
class_name StatBlock
extends Node

## The stats of one character, unit or city in the scene tree. It owns a `StatSheet` built from its inspector values
## (`base_values`, `start_modifiers`, `min_values`, `max_values`), or shows one your game's rules already keep
## (`use_sheet`). The inspector lists every final value under "Values", read only, so a change shows at once without
## running the game. Every call goes to the sheet: `add`, `remove`, `remove_source`, `value`.

## The value of `stat` is now `value`. Only when the final value really changed.
signal stat_changed(stat: StringName, value: float)
## The block shows another sheet now (`use_sheet`, `use_own_sheet`, or new inspector values): read every value again.
signal rebuilt

const _PREFIX := "value_"

## The base value of each stat before any modifier (for example `attack: 5`). Changing it builds the sheet again and
## keeps what code did: the modifiers added with `add` and the bases set with `set_base`.
@export var base_values: Dictionary[StringName, float] = {}:
	set(new_bases):
		base_values = new_bases
		_rebuild_own(true)
## The modifiers the sheet starts with, like the items a character starts with equipped. Changing a value inside one
## applies at once; changing the list builds the sheet again and keeps what code added or took away.
@export var start_modifiers: Array[StatModifier] = []:
	set(list):
		_watch(list)
		start_modifiers = list
		_rebuild_own(true)
## The least each stat can be, after every modifier (for example `moves: 1`). A stat not here has no minimum.
@export var min_values: Dictionary[StringName, float] = {}:
	set(new_mins):
		min_values = new_mins
		_rebuild_own(true)
## The most each stat can be, after every modifier (for example `defense: 10`). A stat not here has no maximum.
@export var max_values: Dictionary[StringName, float] = {}:
	set(new_maxs):
		max_values = new_maxs
		_rebuild_own(true)

## The sheet this block shows.
var sheet: StatSheet:
	get:
		if _sheet == null:
			_rebuild_own(false)
		return _sheet

var _sheet: StatSheet
var _own := true
var _watched: Array[StatModifier] = []
# The start modifiers the own sheet was built with (the ones with a stat).
var _started: Array[StatModifier] = []
# The bases and limits the own sheet was built with, as `StatSheet.to_dict()` writes them: what code changed since
# is what differs from this.
var _built: Dictionary = {}
# The stats the inspector lists under "Values".
var _listed: Array[StringName] = []


## Shows `other` instead of the block's own sheet (your game's rules keep it). The inspector values no longer apply
## until `use_own_sheet()`. Emits `rebuilt`.
func use_sheet(other: StatSheet) -> void:
	if other == null:
		push_error("StatBlock.use_sheet: the sheet is null")
		return
	_own = false
	_set_sheet(other)


## Goes back to a new sheet built from the inspector values alone. Emits `rebuilt`.
func use_own_sheet() -> void:
	_own = true
	_rebuild_own(false)


## The final value of `stat` (see `StatSheet.value`).
func value(stat: StringName) -> float:
	return sheet.value(stat)


## The final value of every stat, sorted by stat.
func values() -> Dictionary[StringName, float]:
	return sheet.values()


## The base value of `stat` in the sheet (0 when it has none).
func base(stat: StringName) -> float:
	return sheet.base(stat)


## Sets the base value of `stat` in the sheet. `base_values` in the inspector stays as it was.
func set_base(stat: StringName, amount: float) -> void:
	sheet.set_base(stat, amount)


## Adds `mod` to the sheet (an item equipped, a buff), given by `source` when one is passed. The same one twice stacks.
func add(mod: StatModifier, source: StringName = &"") -> void:
	sheet.add(mod, source)


## Adds every modifier of `mods`, all given by `source` when one is passed (an item with several bonuses).
func add_all(mods: Array[StatModifier], source: StringName = &"") -> void:
	sheet.add_all(mods, source)


## Takes one occurrence of `mod` away (with `source`: one added with that source). False when there is none.
func remove(mod: StatModifier, source: StringName = &"") -> bool:
	return sheet.remove(mod, source)


## Takes every modifier given by `source` away. Returns how many.
func remove_source(source: StringName) -> int:
	return sheet.remove_source(source)


## Every modifier, or those of one `stat`, in the order they were added.
func modifiers(stat: StringName = &"") -> Array[StatModifier]:
	return sheet.modifiers(stat)


## The source each modifier counts as given by, in the same order as `modifiers(stat)`.
func sources(stat: StringName = &"") -> Array[StringName]:
	return sheet.sources(stat)


## One line per modifier of `stat`, with the source it counts as given by: a tooltip.
func describe(stat: StringName) -> PackedStringArray:
	return sheet.describe(stat)


# Builds the own sheet from the inspector. With `keep`, what code did to the current own sheet stays: the bases and
# limits it changed, the modifiers it added and the start modifiers it took away.
func _rebuild_own(keep: bool) -> void:
	if not _own:
		update_configuration_warnings()
		return
	var start_bases: Dictionary[StringName, float] = {}
	for stat in base_values:
		if stat != &"":
			start_bases[stat] = base_values[stat]
	var next := StatSheet.new(start_bases)
	for stat in _limited_stats():
		var low: float = min_values.get(stat, -INF)
		var high: float = max_values.get(stat, INF)
		if low <= high:
			next.set_limits(stat, low, high)
	var inspector := next.to_dict()
	var start := _valid_start()
	var taken_away: Array[StatModifier] = []
	var added: Array[StatModifier] = []
	var added_sources: Array[StringName] = []
	if keep and _sheet != null:
		_carry_over(_sheet, next, inspector, taken_away, added, added_sources)
	for mod in start:
		var index := taken_away.find(mod)
		if index >= 0:
			taken_away.remove_at(index)
		else:
			next.add(mod)
	for i in added.size():
		next.add(added[i], &"" if added_sources[i] == added[i].source else added_sources[i])
	_started = start
	_built = inspector
	_set_sheet(next)
	update_configuration_warnings()


# What code did to `old` since it was built from the inspector: bases and limits that differ from what the inspector
# set go straight into `next`; the modifiers it added (and their sources) and the start modifiers it took away are
# returned in the arrays.
func _carry_over(
	old: StatSheet,
	next: StatSheet,
	inspector: Dictionary,
	taken_away: Array[StatModifier],
	added: Array[StatModifier],
	added_sources: Array[StringName],
) -> void:
	var was := old.to_dict()
	var was_bases: Dictionary = was["bases"]
	var built_bases: Dictionary = _built.get("bases", {})
	for key: Variant in was_bases:
		if not built_bases.has(key) or built_bases[key] != was_bases[key]:
			next.set_base(StringName(str(key)), float(was_bases[key]))
	var was_limits: Dictionary = was["limits"]
	var built_limits: Dictionary = _built.get("limits", {})
	var new_limits: Dictionary = inspector["limits"]
	for key: Variant in was_limits.keys() + built_limits.keys():
		if was_limits.get(key) == built_limits.get(key):
			continue
		var stat := StringName(str(key))
		var side: Dictionary = was_limits.get(key, {})
		if side.is_empty():
			if new_limits.has(key):
				next.clear_limits(stat)
		else:
			next.set_limits(stat, float(side.get("min", -INF)), float(side.get("max", INF)))
	var pending := _started.duplicate()
	var mods := old.modifiers()
	var given := old.sources()
	for i in mods.size():
		var index := pending.find(mods[i])
		if index >= 0 and given[i] == mods[i].source:
			pending.remove_at(index)
		else:
			added.append(mods[i])
			added_sources.append(given[i])
	taken_away.append_array(pending)


# The start modifiers that can go into a sheet: not null, with a stat.
func _valid_start() -> Array[StatModifier]:
	var list: Array[StatModifier] = []
	for mod in start_modifiers:
		if mod != null and mod.stat != &"":
			list.append(mod)
	return list


func _limited_stats() -> Array[StringName]:
	var list: Array[StringName] = []
	for stat in min_values.keys() + max_values.keys():
		var name_of := StringName(str(stat))
		if name_of != &"" and not list.has(name_of):
			list.append(name_of)
	return list


# Listens to `changed` of every start modifier, and only to those. The sheet itself follows the values of the ones it
# holds; the block only has to build it again when one gains or loses its stat.
func _watch(list: Array[StatModifier]) -> void:
	for mod in _watched:
		if mod.changed.is_connected(_on_start_modifier_changed):
			mod.changed.disconnect(_on_start_modifier_changed)
	_watched.clear()
	for mod in list:
		if mod != null and not _watched.has(mod):
			mod.changed.connect(_on_start_modifier_changed)
			_watched.append(mod)


func _on_start_modifier_changed() -> void:
	if _own and _valid_start() != _started:
		_rebuild_own(true)
	else:
		update_configuration_warnings()


func _set_sheet(next: StatSheet) -> void:
	if _sheet != null and _sheet.stat_changed.is_connected(_on_stat_changed):
		_sheet.stat_changed.disconnect(_on_stat_changed)
	_sheet = next
	_sheet.stat_changed.connect(_on_stat_changed)
	_relist()
	rebuilt.emit()


func _on_stat_changed(stat: StringName, new_value: float) -> void:
	_relist()
	stat_changed.emit(stat, new_value)


# The inspector reads the values again by itself; it only needs to hear when a stat appears or goes away. Telling it
# on every value change would rebuild it while a person drags a number.
func _relist() -> void:
	var now := _sheet.stats()
	if now != _listed:
		_listed = now
		notify_property_list_changed()


func _get_property_list() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var shown := sheet.stats()
	if shown.is_empty():
		return list
	list.append({"name": "Values", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP, "hint_string": _PREFIX})
	for stat in shown:
		list.append(
			{
				"name": _PREFIX + String(stat),
				"type": TYPE_FLOAT,
				"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
			}
		)
	return list


func _get(property: StringName) -> Variant:
	var text := String(property)
	if not text.begins_with(_PREFIX):
		return null
	var stat := StringName(text.trim_prefix(_PREFIX))
	return sheet.value(stat) if sheet.stats().has(stat) else null


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	for pair: Array in [["base_values", base_values], ["min_values", min_values], ["max_values", max_values]]:
		var values_in: Dictionary = pair[1]
		if values_in.has(&""):
			warnings.append("%s: a stat name is empty. Type it, like attack, or remove the entry." % pair[0])
	for stat in _limited_stats():
		var low: float = min_values.get(stat, -INF)
		var high: float = max_values.get(stat, INF)
		if low > high:
			warnings.append("min_values: %s has a minimum above its maximum (%s > %s)." % [stat, low, high])
	var unbased: Array[StringName] = []
	for index in start_modifiers.size():
		var mod := start_modifiers[index]
		if mod == null:
			warnings.append("start_modifiers: slot %d is empty. Create a StatModifier or remove the slot." % index)
			continue
		if mod.stat == &"":
			warnings.append("start_modifiers: slot %d has no stat. Type the stat it changes, like attack." % index)
			continue
		if mod.op == StatModifier.Op.MUL and is_zero_approx(mod.amount):
			warnings.append(
				"start_modifiers: slot %d multiplies %s by 0. Type the factor in amount." % [index, mod.stat]
			)
		if not base_values.has(mod.stat) and not unbased.has(mod.stat):
			unbased.append(mod.stat)
	for stat in _limited_stats():
		if not base_values.has(stat) and not unbased.has(stat):
			unbased.append(stat)
	for stat in unbased:
		warnings.append("%s has no base value in base_values, so it starts from 0." % stat)
	return warnings
