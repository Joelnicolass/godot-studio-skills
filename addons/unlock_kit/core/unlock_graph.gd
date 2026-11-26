class_name UnlockGraph
extends RefCounted

## What can be unlocked, what needs what and what it costs, as plain data: no nodes, no scene. Each entry has an id,
## the ids it requires (all of them), the ids it requires one of (any of them is enough) and a cost. The graph never
## pays by itself: `buy` asks your game's own pay function, and `unlock` takes no cost. A game keeps one per player in
## its rules; `UnlockTree` builds one from the scene tree (`new_graph`).

## `id` is unlocked now.
signal unlocked(id: StringName)
## `id` is locked again (`lock`).
signal locked(id: StringName)
## What can be unlocked now changed: read `available_ids()` again. Emitted once by a call that changed it, and always
## once by `restore` (the whole state was replaced).
signal availability_changed

var _order: Array[StringName] = []
var _entries: Dictionary[StringName, _Entry] = {}
var _unlocked: Array[StringName] = []
var _is_unlocked: Dictionary[StringName, bool] = {}
var _depths: Dictionary[StringName, int] = {}


## Defines an entry. `needs` lists the ids it requires, all of them; `needs_any` the ids it requires one of (any one
## unlocked is enough). Either may name an id added later. `cost` is `{key: amount}`, for `buy` or for your game to
## charge. An empty or repeated id is an error and adds nothing (false). A negative amount is an error and that key is
## left out.
func add(id: StringName, needs: Array = [], cost: Dictionary = {}, needs_any: Array = []) -> bool:
	if id == &"":
		push_error("UnlockGraph.add: the id is empty")
		return false
	if _entries.has(id):
		push_error("UnlockGraph.add: %s is already an entry" % id)
		return false
	var entry := _Entry.new()
	entry.requires = _clean_ids(needs)
	entry.requires_any = _clean_ids(needs_any)
	for item: Variant in cost:
		var key: StringName = item
		var amount: int = cost[item]
		if amount < 0:
			push_error("UnlockGraph.add: the cost of %s in %s is negative (%d)" % [id, key, amount])
			continue
		entry.cost[key] = amount
	_order.append(id)
	_entries[id] = entry
	_depths.clear()
	if can_unlock(id):
		availability_changed.emit()
	return true


## True when `id` is an entry.
func has(id: StringName) -> bool:
	return _entries.has(id)


## Every entry, in the order they were added.
func ids() -> Array[StringName]:
	return _order.duplicate()


## The ids `id` requires, all of them, as given to `add` (an id that is not an entry stays listed).
func requires(id: StringName) -> Array[StringName]:
	var list: Array[StringName] = []
	if _entries.has(id):
		list.assign(_entries[id].requires)
	return list


## The ids `id` requires one of (any one unlocked is enough), as given to `add`. Empty: no such rule.
func requires_any(id: StringName) -> Array[StringName]:
	var list: Array[StringName] = []
	if _entries.has(id):
		list.assign(_entries[id].requires_any)
	return list


## A copy of what `id` costs, `{key: amount}` (empty when it is free or unknown).
func cost_of(id: StringName) -> Dictionary[StringName, int]:
	var none: Dictionary[StringName, int] = {}
	return _entries[id].cost.duplicate() if _entries.has(id) else none


## True when `id` is unlocked.
func is_unlocked(id: StringName) -> bool:
	return _is_unlocked.has(id)


## True when `id` is an entry, is not unlocked yet, every id of `requires` is unlocked and, if it has `requires_any`,
## one of those is unlocked.
func can_unlock(id: StringName) -> bool:
	return why_not(id) == ""


## Why `id` cannot be unlocked now: `""` when it can; else `"unknown"` (not an entry), `"already_unlocked"` or
## `"locked"` (a requirement is missing: see `missing`). The same shape as a reason of a command: map them to your
## game's own messages.
func why_not(id: StringName) -> String:
	if not _entries.has(id):
		return "unknown"
	if _is_unlocked.has(id):
		return "already_unlocked"
	return "locked" if not missing(id).is_empty() else ""


## What `id` still misses: the ids of `requires` that are not unlocked yet and then, when none of `requires_any` is
## unlocked, all of those (one of them is enough). Empty when nothing is missing.
func missing(id: StringName) -> Array[StringName]:
	var list: Array[StringName] = []
	if not _entries.has(id):
		return list
	var entry := _entries[id]
	for need in entry.requires:
		if not _is_unlocked.has(need):
			list.append(need)
	if not _any_unlocked(entry.requires_any):
		list.append_array(entry.requires_any)
	return list


## Unlocks `id` when `can_unlock(id)`, then emits `unlocked` and `availability_changed`. Otherwise returns false and
## nothing changes (not an error: it is normal play). It takes no cost: use `buy`, or charge before calling it.
func unlock(id: StringName) -> bool:
	if not can_unlock(id):
		return false
	_unlocked.append(id)
	_is_unlocked[id] = true
	unlocked.emit(id)
	availability_changed.emit()
	return true


## Pays and unlocks in one call. When `can_unlock(id)`, it calls `pay` with `cost_of(id)` (also when it is free): your
## function charges all or nothing and returns true when it paid. Then it unlocks. False, and nothing unlocked, when
## it cannot be unlocked (`pay` is not called) or `pay` did not return true. `buy(id, wallet.pay)`.
func buy(id: StringName, pay: Callable) -> bool:
	if not can_unlock(id):
		return false
	var paid: Variant = pay.call(cost_of(id))
	if typeof(paid) != TYPE_BOOL or not paid:
		return false
	return unlock(id)


## Locks `id` again (an undo), then emits `locked` and, if it changed, `availability_changed`. False, and nothing
## changes, when `id` is not unlocked or an unlocked entry needs it: it is in that entry's `requires`, or it is the
## only unlocked one of its `requires_any` (lock that entry first).
func lock(id: StringName) -> bool:
	if not _is_unlocked.has(id):
		return false
	for other in _unlocked:
		if _needs_to_stay(other, id):
			return false
	var before := available_ids()
	_unlocked.erase(id)
	_is_unlocked.erase(id)
	locked.emit(id)
	if available_ids() != before:
		availability_changed.emit()
	return true


## The unlocked entries, in the order they were unlocked.
func unlocked_ids() -> Array[StringName]:
	return _unlocked.duplicate()


## The entries that `can_unlock` now, in the order they were added.
func available_ids() -> Array[StringName]:
	var list: Array[StringName] = []
	for id in _order:
		if can_unlock(id):
			list.append(id)
	return list


## The longest chain of requirements under `id`: 0 for an entry without requirements, else 1 more than its deepest
## requirement of `requires` or `requires_any` (one that is not an entry counts as 0). Views use it for columns. A
## cycle is cut where it closes.
func depth(id: StringName) -> int:
	if not _entries.has(id):
		return 0
	var on_path: Dictionary[StringName, bool] = {}
	return _depth_of(id, on_path)


## Unlocks exactly `saved_ids` (a save), in that order, with no `unlocked` or `locked` signals and one
## `availability_changed`. `restore([])` locks everything. It does not check that the requirements are unlocked. An id
## that is not an entry is an error and is skipped.
func restore(saved_ids: Array) -> void:
	_unlocked.clear()
	_is_unlocked.clear()
	for item: Variant in saved_ids:
		var id: StringName = item
		if not _entries.has(id):
			push_error("UnlockGraph.restore: %s is not an entry" % id)
			continue
		if not _is_unlocked.has(id):
			_unlocked.append(id)
			_is_unlocked[id] = true
	availability_changed.emit()


## What is wrong with the graph, in plain words: requirements that are not entries, an entry that requires itself, and
## cycles (entries that require each other in a circle). Empty when it is fine.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	for id in _order:
		var entry := _entries[id]
		for need in entry.links():
			if need == id:
				found.append("%s requires itself." % id)
			elif not _entries.has(need):
				found.append("%s requires %s, which is not an entry." % [id, need])
	for group in _cycle_groups():
		var names := PackedStringArray()
		for id: StringName in group:
			names.append(String(id))
		found.append("%s require each other in a circle: remove one of those links." % ", ".join(names))
	return found


## Plain data for a save or a network snapshot: `{"entries": [{"id", "requires", "requires_any", "cost"}],
## "unlocked": [ids in unlock order]}`. With `with_entries` false, only `{"unlocked": [...]}`: a player's state,
## for `restore(data["unlocked"])` on a graph that already has the entries.
func to_dict(with_entries := true) -> Dictionary:
	var unlocked_out: Array = []
	for id in _unlocked:
		unlocked_out.append(String(id))
	if not with_entries:
		return {"unlocked": unlocked_out}
	var entries_out: Array = []
	for id in _order:
		var entry := _entries[id]
		var cost_out: Dictionary = {}
		var keys: Array[StringName] = []
		keys.assign(entry.cost.keys())
		keys.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
		for key in keys:
			cost_out[String(key)] = entry.cost[key]
		(
			entries_out
			. append(
				{
					"id": String(id),
					"requires": _plain_ids(entry.requires),
					"requires_any": _plain_ids(entry.requires_any),
					"cost": cost_out,
				}
			)
		)
	return {"entries": entries_out, "unlocked": unlocked_out}


## Rebuilds a graph from `to_dict()` (also after a JSON round trip). No signal reaches you: nothing is connected yet.
static func from_dict(data: Dictionary) -> UnlockGraph:
	var graph := UnlockGraph.new()
	var entries_in: Array = data.get("entries", [])
	for item: Variant in entries_in:
		if item is Dictionary:
			var entry: Dictionary = item
			var needs: Array = entry.get("requires", [])
			var needs_any: Array = entry.get("requires_any", [])
			var cost: Dictionary = entry.get("cost", {})
			graph.add(StringName(str(entry.get("id", ""))), needs, cost, needs_any)
	var unlocked_in: Array = data.get("unlocked", [])
	graph.restore(unlocked_in)
	return graph


# The groups of entries that require each other in a circle (a strongly connected group of two or more), each in the
# order the entries were added, the groups in the order of their first entry. Kit-internal: `UnlockTree` marks them.
func _cycle_groups() -> Array[Array]:
	var state := _Tarjan.new()
	for id in _order:
		if not state.index.has(id):
			_connect(id, state)
	var groups: Array[Array] = []
	for group in state.groups:
		if group.size() < 2:
			continue
		var ordered: Array[StringName] = []
		for id in _order:
			if group.has(id):
				ordered.append(id)
		groups.append(ordered)
	groups.sort_custom(func(a: Array, b: Array) -> bool: return _order.find(a[0]) < _order.find(b[0]))
	return groups


# Tarjan's strongly connected groups, over both kinds of requirement.
func _connect(id: StringName, state: _Tarjan) -> void:
	state.index[id] = state.next
	state.low[id] = state.next
	state.next += 1
	state.stack.append(id)
	state.on_stack[id] = true
	var entry := _entries[id]
	for need in entry.links():
		if not _entries.has(need) or need == id:
			continue
		if not state.index.has(need):
			_connect(need, state)
			state.low[id] = mini(state.low[id], state.low[need])
		elif state.on_stack.has(need):
			state.low[id] = mini(state.low[id], state.index[need])
	if state.low[id] == state.index[id]:
		var group: Array[StringName] = []
		while true:
			var top: StringName = state.stack.pop_back()
			state.on_stack.erase(top)
			group.append(top)
			if top == id:
				break
		state.groups.append(group)


# True when `other` (unlocked) stops being valid without `id`.
func _needs_to_stay(other: StringName, id: StringName) -> bool:
	var entry := _entries[other]
	if entry.requires.has(id):
		return true
	if not entry.requires_any.has(id):
		return false
	for need in entry.requires_any:
		if need != id and _is_unlocked.has(need):
			return false
	return true


func _any_unlocked(list: Array[StringName]) -> bool:
	if list.is_empty():
		return true
	for need in list:
		if _is_unlocked.has(need):
			return true
	return false


func _depth_of(id: StringName, on_path: Dictionary[StringName, bool]) -> int:
	if _depths.has(id):
		return _depths[id]
	var entry := _entries[id]
	if entry.requires.is_empty() and entry.requires_any.is_empty():
		return 0
	on_path[id] = true
	var deepest := 0
	for need in entry.links():
		if _entries.has(need) and not on_path.has(need):
			deepest = maxi(deepest, _depth_of(need, on_path))
	on_path.erase(id)
	_depths[id] = deepest + 1
	return deepest + 1


static func _clean_ids(items: Array) -> Array[StringName]:
	var list: Array[StringName] = []
	for item: Variant in items:
		var id: StringName = item
		if id != &"" and not list.has(id):
			list.append(id)
	return list


static func _plain_ids(list: Array[StringName]) -> Array:
	var out: Array = []
	for id in list:
		out.append(String(id))
	return out


# One entry: what it requires (all), what it requires one of, and what it costs.
class _Entry:
	var requires: Array[StringName] = []
	var requires_any: Array[StringName] = []
	var cost: Dictionary[StringName, int] = {}

	# Every id it points at: `requires`, then `requires_any`.
	func links() -> Array[StringName]:
		var list: Array[StringName] = requires.duplicate()
		list.append_array(requires_any)
		return list


# The bookkeeping of one search for cycles.
class _Tarjan:
	var next := 0
	var index: Dictionary[StringName, int] = {}
	var low: Dictionary[StringName, int] = {}
	var stack: Array[StringName] = []
	var on_stack: Dictionary[StringName, bool] = {}
	var groups: Array[Array] = []
