@tool
class_name GameCommands
extends Node

## Validated commands in the scene tree. Put it as a child of your game, or point `game` at it: every `do_<name>`
## function of that node is a command, with its optional `can_<name>` and `undo_<name>`. It owns a `CommandLog`, or
## shows one your game's rules already keep (`use_log`). Every call goes to the log: `run`, `undo`, `replay`,
## `history`. A HUD asks it to run what the player clicked and listens to `rejected` to say why not.

## `name` ran and is in the history.
signal done(seat: int, name: StringName, args: Array)
## `name` did not run: `reason` is what the game said or one of the `CommandLog` codes.
signal rejected(seat: int, name: StringName, args: Array, reason: String)
## `name` was taken back and left the history.
signal undone(seat: int, name: StringName, args: Array)
## The node shows another log now (`use_log`, `use_own_log`): read the log again.
signal rebuilt

const Scan := preload("res://addons/command_kit/core/command_scan.gd")
const _FOUND := &"found_commands"

## The node with the `do_` / `can_` / `undo_` functions. Empty: the parent.
@export var game: Node:
	set(value):
		game = value
		_retarget()
		update_configuration_warnings()
		notify_property_list_changed()
## Off: commands still run and emit, but nothing is kept (no undo, no history).
@export var keep_history := true:
	set(value):
		keep_history = value
		if _own and _log != null:
			_log.keep_history = value

## The log this node shows.
var command_log: CommandLog:
	get:
		if _log == null:
			_rebuild_own()
		return _log

var _log: CommandLog
var _own := true


func _notification(what: int) -> void:
	if what == NOTIFICATION_PARENTED:
		_retarget()
		update_configuration_warnings()
		notify_property_list_changed()


## `""` when it can run now, else the reason. Changes nothing.
func can_run(seat: int, command_name: StringName, args: Array = []) -> String:
	return command_log.can_run(seat, command_name, args)


## Runs `do_<name>(seat, args...)`. Returns `""` when it ran, else the reason. See `CommandLog.run`.
func run(seat: int, command_name: StringName, args: Array = []) -> String:
	return command_log.run(seat, command_name, args)


func can_undo() -> bool:
	return command_log.can_undo()


func undo() -> bool:
	return command_log.undo()


func history() -> Array[Dictionary]:
	return command_log.history()


func replay(entries: Array) -> String:
	return command_log.replay(entries)


func is_replaying() -> bool:
	return command_log.is_replaying()


func size() -> int:
	return command_log.size()


func clear() -> void:
	command_log.clear()


func commands() -> Array[StringName]:
	return command_log.commands()


func has_command(command_name: StringName) -> bool:
	return command_log.has_command(command_name)


## Shows `other` instead of the node's own log (your game's rules keep it). `game` and `keep_history` no longer apply
## until `use_own_log()`. Emits `rebuilt`.
func use_log(other: CommandLog) -> void:
	_own = false
	_set_log(other)


## Goes back to an empty log of its own. Emits `rebuilt`.
func use_own_log() -> void:
	_own = true
	_rebuild_own()


## True while the node shows its own log (not one from `use_log`).
func owns_log() -> bool:
	return _own


func _target() -> Node:
	return game if game != null else get_parent()


func _retarget() -> void:
	if _own and _log != null:
		_log.game = _target()


func _rebuild_own() -> void:
	if not _own:
		return
	var next := CommandLog.new(_target())
	next.keep_history = keep_history
	_set_log(next)


func _set_log(next: CommandLog) -> void:
	if _log != null:
		_log.done.disconnect(_on_done)
		_log.rejected.disconnect(_on_rejected)
		_log.undone.disconnect(_on_undone)
	_log = next
	_log.done.connect(_on_done)
	_log.rejected.connect(_on_rejected)
	_log.undone.connect(_on_undone)
	rebuilt.emit()


func _on_done(seat: int, command_name: StringName, args: Array) -> void:
	done.emit(seat, command_name, args)


func _on_rejected(seat: int, command_name: StringName, args: Array, reason: String) -> void:
	rejected.emit(seat, command_name, args, reason)


func _on_undone(seat: int, command_name: StringName, args: Array) -> void:
	undone.emit(seat, command_name, args)


## What the editor knows about the target without running it: its script's function list.
func _scan_target() -> Scan:
	var target := _target()
	return Scan.new(target.get_script() as Script if target != null else null)


func _get_property_list() -> Array[Dictionary]:
	return [{"name": _FOUND, "type": TYPE_STRING, "usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY}]


func _get(property: StringName) -> Variant:
	if property != _FOUND:
		return null
	var found := _scan_target().text()
	return found if found != "" else "(none)"


func _get_configuration_warnings() -> PackedStringArray:
	var target := _target()
	if target == null:
		return PackedStringArray(["No game: put this node under the node with the do_ functions, or set game."])
	if target.get_script() == null:
		return PackedStringArray(["%s has no script: add the do_<name> functions of your game there." % target.name])
	return _scan_target().problems
