@tool
@icon("res://addons/unlock_kit/icons/unlock_entry.svg")
class_name UnlockEntry
extends Node

## One entry of an `UnlockTree`: a tech, a talent, a skill. Put it under the tree (as deep as you like). An entry inside
## another entry requires it, so the scene tree is the unlock tree (Farming > Irrigation > Aqueduct). A plain `Node`
## between them only groups entries (a branch) and adds no requirement. `requires` adds more entries it needs, all of
## them (a cross link); `requires_any` adds entries it needs one of. Extend it with your own `@tool` script and typed
## `@export` fields for what the entry gives in your game.

## This entry is unlocked now (emitted by its tree). Connect it in the editor to wire an effect per entry.
signal unlocked
## This entry is locked again (emitted by its tree).
signal locked

# Added, taken out, moved or renamed: the tree builds its graph again (once per frame; not when the tree leaves too).
const _TREE_CHANGES: Array[int] = [
	NOTIFICATION_PARENTED,
	NOTIFICATION_ENTER_TREE,
	NOTIFICATION_EXIT_TREE,
	NOTIFICATION_PATH_RENAMED,
	NOTIFICATION_MOVED_IN_PARENT,
]
const _NODE_LISTS: Array[String] = ["requires", "requires_any"]

## The id your rules use. Empty: the node's name. Type it yourself when games are saved: renaming the node changes it.
@export var id: StringName = &"":
	set(value):
		id = value
		_changed()
## What a view shows. Empty: the id.
@export var title := "":
	set(value):
		title = value
		_changed()
## What it does, for a tooltip.
@export_multiline var description := "":
	set(value):
		description = value
		_changed()
## The picture a view shows in its box.
@export var icon: Texture2D:
	set(value):
		icon = value
		_changed()
## What it costs, `{key: amount}` (3 points, 2 wood). The kit never charges by itself: `UnlockTree.buy` hands it to
## your game's pay function.
@export var cost: Dictionary[StringName, int] = {}:
	set(value):
		cost = value
		_changed()
## More entries it requires besides its parent entry (a cross link): all of them must be unlocked first. Only
## `UnlockEntry` nodes of the same tree count.
@export var requires: Array[Node] = []:
	set(value):
		requires = value
		_changed()
## Entries it requires one of: any one of them unlocked is enough (the wheel or pottery). Views draw these links
## dashed. Only `UnlockEntry` nodes of the same tree count.
@export var requires_any: Array[Node] = []:
	set(value):
		requires_any = value
		_changed()
## On: unlocked when the tree builds its graph and on `reset` (a starting tech): free, whatever it requires.
@export var start_unlocked := false:
	set(value):
		start_unlocked = value
		_changed()
## Where an `UnlockTreeView` puts this entry's box, in pixels from its top-left corner. (0, 0): the automatic column.
@export var view_position := Vector2.ZERO:
	set(value):
		view_position = value
		_changed()


## The id of this entry in the graph: `id`, or the node's name when `id` is empty.
func entry_id() -> StringName:
	return id if id != &"" else StringName(name)


## True when its tree has it unlocked.
func is_unlocked() -> bool:
	var tree := _unlock_tree()
	return tree != null and tree.is_unlocked(entry_id())


# `requires` and `requires_any` are `Array[Node]`: an array typed with this script itself would keep the script alive
# at exit (a leak Godot reports). The inspector still offers only `UnlockEntry` nodes.
func _validate_property(property: Dictionary) -> void:
	if str(property["name"]) in _NODE_LISTS:
		property["hint_string"] = "%d/%d:UnlockEntry" % [TYPE_OBJECT, PROPERTY_HINT_NODE_TYPE]


func _notification(what: int) -> void:
	if what in _TREE_CHANGES:
		_changed()


func _changed() -> void:
	var tree := _unlock_tree()
	if tree != null:
		tree._queue_rebuild()
	update_configuration_warnings()


# The nearest `UnlockTree` above this entry, or null.
func _unlock_tree() -> UnlockTree:
	var node := get_parent()
	while node != null:
		if node is UnlockTree:
			return node
		node = node.get_parent()
	return null


# The nearest `UnlockEntry` above this one, below its tree (the entry it requires by nesting), or null.
func _parent_entry() -> UnlockEntry:
	var node := get_parent()
	while node != null and not node is UnlockTree:
		if node is UnlockEntry:
			return node
		node = node.get_parent()
	return null


# The `UnlockEntry` nodes of `list`, skipping empty slots and other nodes.
static func _entries_in(list: Array[Node]) -> Array[UnlockEntry]:
	var found: Array[UnlockEntry] = []
	for node in list:
		var other := node as UnlockEntry
		if other != null:
			found.append(other)
	return found


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var tree := _unlock_tree()
	if tree == null:
		warnings.append("UnlockEntry belongs to a tree: put it under an UnlockTree (as deep as you like).")
		return warnings
	_check_list(requires, "requires", tree, warnings)
	_check_list(requires_any, "requires_any", tree, warnings)
	for key in cost:
		if cost[key] < 0:
			warnings.append("cost: %s is negative." % key)
	if start_unlocked:
		_check_start(warnings)
	# What depends on the other entries comes from the tree, worked out once per rebuild.
	warnings.append_array(tree._warnings_of(self))
	return warnings


func _check_list(list: Array[Node], label: String, tree: UnlockTree, warnings: PackedStringArray) -> void:
	for index in list.size():
		var other := list[index] as UnlockEntry
		if list[index] == null:
			warnings.append("%s: slot %d is empty. Pick an entry there or remove the slot." % [label, index])
		elif other == null:
			warnings.append("%s: slot %d is not an UnlockEntry." % [label, index])
		elif other._unlock_tree() != tree:
			warnings.append("%s: %s is not in this entry's UnlockTree." % [label, other.entry_id()])


# A starting entry under one that does not start unlocked: a state `unlock` could never reach.
func _check_start(warnings: PackedStringArray) -> void:
	var needed: Array[UnlockEntry] = _entries_in(requires)
	var parent := _parent_entry()
	if parent != null:
		needed.push_front(parent)
	for other in needed:
		if not other.start_unlocked:
			warnings.append(
				(
					"start_unlocked, but it requires %s, which does not start unlocked. Tick start_unlocked there too."
					% other.entry_id()
				)
			)
	var any := _entries_in(requires_any)
	if any.is_empty():
		return
	for other in any:
		if other.start_unlocked:
			return
	warnings.append("start_unlocked, but none of requires_any starts unlocked. Tick start_unlocked on one of them.")
