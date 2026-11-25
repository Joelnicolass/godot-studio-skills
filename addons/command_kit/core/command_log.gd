class_name CommandLog
extends RefCounted

## Runs `GameCommand`s against your game's state, as plain data: no nodes, no scene. A command runs only when its
## `can_run` says so; the accepted ones go in the log as `{type, seat, args}`, which is enough to save a match, send it,
## take back the last moves (`undo`) or play it all again on a fresh state (`replay`). Rejected commands leave no trace.
## A game keeps one in its rules; `CommandBus` wraps one for the editor.

## `command` ran and is in the log.
signal executed(command: GameCommand)
## `command` did not run: `reason` is the code its `can_run` returned.
signal rejected(command: GameCommand, reason: StringName)
## `command` was taken back and left the log.
signal undone(command: GameCommand)

## Returned by `replay` when an entry's type is not registered.
const UNKNOWN_COMMAND := &"unknown_command"
## Returned by `run` when there is no command to run.
const NO_COMMAND := &"no_command"

## Off: commands still run and emit, but nothing is kept (no undo, no log).
var keep_log := true

var _replaying := false
var _scripts: Dictionary[StringName, Script] = {}
var _done: Array[GameCommand] = []
var _entries: Array[Dictionary] = []


## Lets the log build commands of `script` (a `GameCommand` subclass) from their entries. False, with an error, when
## the script is not a `GameCommand`, its `command_type()` is empty, or another script already took that type.
func register(script: Script) -> bool:
	if script == null or not _is_command_script(script):
		push_error("CommandLog: %s is not a GameCommand script" % script)
		return false
	var type: StringName = script.call(&"command_type")
	if type == &"":
		push_error("CommandLog: %s has no command_type()" % script.resource_path)
		return false
	if _scripts.has(type) and _scripts[type] != script:
		push_error("CommandLog: type %s is already %s" % [type, _scripts[type].resource_path])
		return false
	_scripts[type] = script
	return true


func has_type(type: StringName) -> bool:
	return _scripts.has(type)


## The registered types, sorted.
func types() -> Array[StringName]:
	var list: Array[StringName] = []
	list.assign(_scripts.keys())
	list.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return list


## Runs `command` against `ctx` when its `can_run(ctx)` allows it. Returns `&""` when it ran (and is in the log), or
## the rejection code. Emits `executed` or `rejected`.
func run(command: GameCommand, ctx: Variant = null) -> StringName:
	if command == null:
		push_error("CommandLog: run() got no command")
		return NO_COMMAND
	var reason := command.can_run(ctx)
	if reason != &"":
		rejected.emit(command, reason)
		return reason
	command.run(ctx)
	if keep_log:
		_done.append(command)
		_entries.append(command.to_dict())
	executed.emit(command)
	return &""


## True when the last command in the log can be taken back.
func can_undo() -> bool:
	return not _done.is_empty() and _done[-1].can_undo()


## Takes back the last command in the log and removes it from the log. False when there is none or it cannot be
## undone. Emits `undone`.
func undo(ctx: Variant = null) -> bool:
	if not can_undo():
		return false
	var command: GameCommand = _done.pop_back()
	_entries.pop_back()
	command.undo(ctx)
	undone.emit(command)
	return true


## Builds every entry again and runs it against `ctx` (usually a fresh state built with the same seed). Returns `&""`
## when all of them ran, or the code of the first that did not (`UNKNOWN_COMMAND` for a type that is not registered);
## the ones before it already ran. The entries that ran are added at the end of the log: on an empty log (`clear()`
## first) a full replay leaves it equal to `entries_in`. While it runs, `is_replaying()` is true: a listener that sends
## commands of its own (a bot, an automatic effect) must not send them then, because they are in the log already.
func replay(entries_in: Array, ctx: Variant = null) -> StringName:
	var was_replaying := _replaying
	_replaying = true
	var result := &""
	for entry: Variant in entries_in:
		var command := make(entry as Dictionary)
		if command == null:
			result = UNKNOWN_COMMAND
			break
		var reason := run(command, ctx)
		if reason != &"":
			result = reason
			break
	_replaying = was_replaying
	return result


## True while `replay` runs: commands come from the log, not from a player.
func is_replaying() -> bool:
	return _replaying


## The command an entry describes (`{type, seat, args}`), or null when its type is not registered.
func make(entry: Dictionary) -> GameCommand:
	var type := StringName(entry.get("type", ""))
	var script: Script = _scripts.get(type)
	if script == null:
		return null
	var command := script.call(&"from_args", entry.get("args", {}) as Dictionary) as GameCommand
	if command == null:
		push_error("CommandLog: %s.from_args() returned no command" % type)
		return null
	command.seat = int(entry.get("seat", -1))
	return command


## A copy of the log: one `{type, seat, args}` per accepted command still in it, oldest first.
func entries() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for entry in _entries:
		list.append(entry.duplicate(true))
	return list


## The last command in the log, or null.
func last() -> GameCommand:
	return _done[-1] if not _done.is_empty() else null


func size() -> int:
	return _entries.size()


## Empties the log (the registered types stay).
func clear() -> void:
	_done.clear()
	_entries.clear()


static func _is_command_script(script: Script) -> bool:
	var base := GameCommand as Script
	var current := script
	while current != null:
		if current == base:
			return true
		current = current.get_base_script()
	return false
