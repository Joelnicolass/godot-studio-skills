# gdlint: disable=max-public-methods
@tool
@icon("res://addons/unlock_kit/icons/unlock_tree.svg")
class_name UnlockTree
extends Node

## A tech tree, talent tree or skill tree in the scene tree. Its `UnlockEntry` descendants are the entries, in tree
## order: an entry inside another requires it. It owns an `UnlockGraph` built from them, or shows one your game's rules
## already keep (`use_graph`, with one graph per player from `new_graph`); the entries still give titles, icons and
## descriptions to views. Every call goes to the graph: `buy`, `can_unlock`, `unlock`, `cost_of`.

## `id` is unlocked now. Its `UnlockEntry` emits its own `unlocked` too.
signal unlocked(id: StringName)
## `id` is locked again. Its `UnlockEntry` emits its own `locked` too.
signal locked(id: StringName)
## What can be unlocked now changed: read `available_ids()` again.
signal availability_changed
## The tree shows another graph now, or its entries changed (a new graph object when it owns it): read everything again.
signal rebuilt

## The graph this tree shows. A new object each time the tree builds its own again (an entry changed).
var graph: UnlockGraph:
	get:
		if _graph == null or _pending:
			_flush()
		return _graph

var _graph: UnlockGraph
var _own := true
var _pending := false
var _scheduled := false
var _by_id: Dictionary[StringName, UnlockEntry] = {}
var _cyclic: Dictionary[StringName, bool] = {}
var _cyclic_ready := false


## A new graph built from the entries, with the `start_unlocked` entries unlocked: one per player for your rules, then
## `use_graph(player.unlocks)` shows the active one. It is not connected to the tree: changing an entry later does not
## touch it.
func new_graph() -> UnlockGraph:
	var next := UnlockGraph.new()
	for item in entries():
		var item_id := item.entry_id()
		if next.has(item_id):
			continue
		var cost: Dictionary[StringName, int] = {}
		for key in item.cost:
			if item.cost[key] >= 0:
				cost[key] = item.cost[key]
		next.add(item_id, _requirements_of(item), cost, _ids_of(UnlockEntry._entries_in(item.requires_any)))
	next.restore(_start_ids())
	return next


## Shows `other` instead of the tree's own graph (your game's rules keep it, one per player). The entries no longer
## build it, but still give titles, icons and descriptions to views by id; an id without an entry is a warning. Emits
## `rebuilt`.
func use_graph(other: UnlockGraph) -> void:
	if other == null:
		push_error("UnlockTree.use_graph: the graph is null")
		return
	_own = false
	_pending = false
	_set_graph(other)
	var lost := PackedStringArray()
	for item_id in other.ids():
		if not _by_id.has(item_id):
			lost.append(String(item_id))
	if not lost.is_empty():
		push_warning("UnlockTree.use_graph: no UnlockEntry for %s (a view shows the id as its title)" % ", ".join(lost))


## Goes back to a graph built from the entries, at the start (only the `start_unlocked` entries). Emits `rebuilt`.
func use_own_graph() -> void:
	_own = true
	_pending = false
	_set_graph(new_graph())


## True when `id` is an entry, is not unlocked yet and its requirements are met.
func can_unlock(id: StringName) -> bool:
	return graph.can_unlock(id)


## `""` when `id` can be unlocked; else `"unknown"`, `"already_unlocked"` or `"locked"`.
func why_not(id: StringName) -> String:
	return graph.why_not(id)


## Unlocks `id` when `can_unlock(id)`, with no cost: for a cost, use `buy`.
func unlock(id: StringName) -> bool:
	return graph.unlock(id)


## Pays and unlocks in one call: when `id` can be unlocked, `pay` gets `cost_of(id)` and returns true when it charged
## (all or nothing); then `id` is unlocked. `tree.buy(id, wallet.pay)`.
func buy(id: StringName, pay: Callable) -> bool:
	return graph.buy(id, pay)


## Locks `id` again (an undo). False when it is not unlocked or an unlocked entry needs it.
func lock(id: StringName) -> bool:
	return graph.lock(id)


## A copy of what `id` costs, `{key: amount}` (empty when it is free).
func cost_of(id: StringName) -> Dictionary[StringName, int]:
	return graph.cost_of(id)


## True when `id` is unlocked.
func is_unlocked(id: StringName) -> bool:
	return graph.is_unlocked(id)


## The unlocked entries, in the order they were unlocked (save these).
func unlocked_ids() -> Array[StringName]:
	return graph.unlocked_ids()


## The entries that can be unlocked now, in the graph's order (tree order for its own graph).
func available_ids() -> Array[StringName]:
	return graph.available_ids()


## What `id` still misses: its `requires` not unlocked yet, then all of its `requires_any` when none is unlocked.
func missing(id: StringName) -> Array[StringName]:
	return graph.missing(id)


## The ids `id` requires, all of them: its parent entry, then its `requires`.
func requires(id: StringName) -> Array[StringName]:
	return graph.requires(id)


## The ids `id` requires one of: its `requires_any`.
func requires_any(id: StringName) -> Array[StringName]:
	return graph.requires_any(id)


## Unlocks exactly `saved_ids` (a save), with no `unlocked` signals and one `availability_changed`.
func restore(saved_ids: Array) -> void:
	graph.restore(saved_ids)


## Back to the start: everything locked, then (in the tree's own graph) the `start_unlocked` entries unlocked again.
## No `locked` or `unlocked` signals; one `availability_changed`.
func reset() -> void:
	graph.restore(_start_ids() if _own else [])


## Plain data of the graph, like `UnlockGraph.to_dict()`. `to_dict(false)`: only what is unlocked.
func to_dict(with_entries := true) -> Dictionary:
	return graph.to_dict(with_entries)


## The `UnlockEntry` of `id`, or null when no entry of this tree has it (the first one in tree order, when two do).
func entry(id: StringName) -> UnlockEntry:
	if _pending:
		_flush()
	return _indexed(id)


## The `UnlockEntry` descendants, in tree order (an entry inside another `UnlockTree` belongs to that one).
func entries() -> Array[UnlockEntry]:
	var list: Array[UnlockEntry] = []
	_collect(self, list)
	return list


## What a view shows for `id`: its entry's `title`, or the id when the entry has none (or there is no entry).
func title_of(id: StringName) -> String:
	var found := entry(id)
	return found.title if found != null and found.title != "" else String(id)


func _ready() -> void:
	if _graph == null:
		_flush()


# A branch (a plain Node) moved among the tree's children changes the tree order: its entries are not told.
func _notification(what: int) -> void:
	if what == NOTIFICATION_CHILD_ORDER_CHANGED:
		_queue_rebuild()


# Called by the entries when they change: one rebuild at the end of the frame, or sooner when someone reads.
func _queue_rebuild() -> void:
	_pending = true
	if not _scheduled:
		_scheduled = true
		_flush_pending.call_deferred()


# When the whole tree left the scene with its entries (a scene closing), it waits: the next read rebuilds it.
func _flush_pending() -> void:
	_scheduled = false
	if _pending and is_inside_tree():
		_flush()


func _flush() -> void:
	_pending = false
	if not _own and _graph != null:
		_index()
		rebuilt.emit()
		return
	var next := new_graph()
	# What was unlocked stays unlocked. Nothing is played in the editor: there the tree always shows its start.
	if _graph != null and not Engine.is_editor_hint():
		var keep: Array[StringName] = []
		for item_id in _graph.unlocked_ids():
			if next.has(item_id):
				keep.append(item_id)
		for item_id in next.unlocked_ids():
			if not keep.has(item_id):
				keep.append(item_id)
		next.restore(keep)
	_set_graph(next)


func _start_ids() -> Array[StringName]:
	var list: Array[StringName] = []
	for item in entries():
		if item.start_unlocked and not list.has(item.entry_id()):
			list.append(item.entry_id())
	return list


# The parent entry, then its `requires`.
func _requirements_of(item: UnlockEntry) -> Array[StringName]:
	var found := UnlockEntry._entries_in(item.requires)
	var parent := item._parent_entry()
	if parent != null:
		found.push_front(parent)
	return _ids_of(found)


static func _ids_of(list: Array[UnlockEntry]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for item in list:
		if not ids.has(item.entry_id()):
			ids.append(item.entry_id())
	return ids


func _collect(node: Node, list: Array[UnlockEntry]) -> void:
	for child in node.get_children():
		if child is UnlockTree:
			continue
		if child is UnlockEntry:
			list.append(child)
		_collect(child, list)


func _index() -> void:
	_by_id.clear()
	_cyclic_ready = false
	for item in entries():
		if not _by_id.has(item.entry_id()):
			_by_id[item.entry_id()] = item


func _indexed(id: StringName) -> UnlockEntry:
	return _by_id[id] if _by_id.has(id) else null


# Kit-internal, for `UnlockEntry`'s editor warnings: what depends on the other entries, from indexes built once per
# rebuild (no entry walks all the others).
func _warnings_of(item: UnlockEntry) -> PackedStringArray:
	var warnings := PackedStringArray()
	var item_id := item.entry_id()
	var first := entry(item_id)
	if first != null and first != item:
		warnings.append(
			(
				"%s already has the id %s and counts; this one is left out. Give each entry its own id."
				% [first.name, item_id]
			)
		)
		return warnings
	if not _cyclic_ready:
		_cyclic.clear()
		for group in graph._cycle_groups():
			for cyclic_id: StringName in group:
				_cyclic[cyclic_id] = true
		_cyclic_ready = true
	if _cyclic.has(item_id):
		warnings.append("This entry and others require each other in a circle: remove one of those links.")
	return warnings


func _set_graph(next: UnlockGraph) -> void:
	if _graph != null:
		_graph.unlocked.disconnect(_on_unlocked)
		_graph.locked.disconnect(_on_locked)
		_graph.availability_changed.disconnect(_on_availability_changed)
	_graph = next
	_graph.unlocked.connect(_on_unlocked)
	_graph.locked.connect(_on_locked)
	_graph.availability_changed.connect(_on_availability_changed)
	_index()
	if Engine.is_editor_hint():
		update_configuration_warnings()
		for item in entries():
			item.update_configuration_warnings()
	rebuilt.emit()


func _on_unlocked(id: StringName) -> void:
	unlocked.emit(id)
	var found := _indexed(id)
	if found != null:
		found.unlocked.emit()


func _on_locked(id: StringName) -> void:
	locked.emit(id)
	var found := _indexed(id)
	if found != null:
		found.locked.emit()


func _on_availability_changed() -> void:
	availability_changed.emit()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if entries().is_empty():
		warnings.append("No entries: add UnlockEntry nodes under this tree (an entry inside another requires it).")
	warnings.append_array(graph.problems())
	return warnings
