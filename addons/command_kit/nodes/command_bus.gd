@tool
class_name CommandBus
extends Node

## Validated commands in the scene tree. It owns a `CommandLog` with the command scripts listed in the inspector, or
## shows one your game's rules already keep (`use_log`). Every call goes to the log: `run`, `undo`, `replay`,
## `entries`. A HUD asks it to run what the player clicked and listens to `rejected` to say why not.

## `command` ran and is in the log.
signal executed(command: GameCommand)
## `command` did not run: `reason` is the code its `can_run` returned.
signal rejected(command: GameCommand, reason: StringName)
## `command` was taken back and left the log.
signal undone(command: GameCommand)
## The bus shows another log now (`use_log`, `use_own_log`, or new `commands`): read the log again.
signal rebuilt

## The command scripts (each a `GameCommand` subclass) this bus can build from log entries. Changing it builds an
## empty log again.
@export var commands: Array[Script] = []:
	set(value):
		commands = value
		_rebuild_own()
## Off: commands still run and emit, but nothing is kept (no undo, no log).
@export var keep_log := true:
	set(value):
		keep_log = value
		if _own and _log != null:
			_log.keep_log = value

## What commands run against when `run`, `undo` or `replay` get no `ctx`: usually your match state.
var context: Variant = null
## The log this bus shows.
var command_log: CommandLog:
	get:
		if _log == null:
			_rebuild_own()
		return _log

var _log: CommandLog
var _own := true


## Runs `command` against `ctx` (or `context`). Returns `&""` when it ran, or the rejection code.
func run(command: GameCommand, ctx: Variant = null) -> StringName:
	return command_log.run(command, _ctx(ctx))


func can_undo() -> bool:
	return command_log.can_undo()


func undo(ctx: Variant = null) -> bool:
	return command_log.undo(_ctx(ctx))


func replay(entries_in: Array, ctx: Variant = null) -> StringName:
	return command_log.replay(entries_in, _ctx(ctx))


func is_replaying() -> bool:
	return command_log.is_replaying()


func make(entry: Dictionary) -> GameCommand:
	return command_log.make(entry)


func entries() -> Array[Dictionary]:
	return command_log.entries()


func size() -> int:
	return command_log.size()


func clear() -> void:
	command_log.clear()


## Shows `other` instead of the bus's own log (your game's rules keep it). `commands` and `keep_log` no longer apply
## until `use_own_log()`. Emits `rebuilt`.
func use_log(other: CommandLog) -> void:
	_own = false
	_set_log(other)


## Goes back to an empty log built from the inspector values. Emits `rebuilt`.
func use_own_log() -> void:
	_own = true
	_rebuild_own()


func _ctx(ctx: Variant) -> Variant:
	return ctx if ctx != null else context


func _rebuild_own() -> void:
	if not _own:
		return
	var next := CommandLog.new()
	next.keep_log = keep_log
	for script in commands:
		if script != null and _is_command_script(script) and script.call(&"command_type") != &"":
			next.register(script)
	_set_log(next)
	update_configuration_warnings()


func _set_log(next: CommandLog) -> void:
	if _log != null:
		_log.executed.disconnect(_on_executed)
		_log.rejected.disconnect(_on_rejected)
		_log.undone.disconnect(_on_undone)
	_log = next
	_log.executed.connect(_on_executed)
	_log.rejected.connect(_on_rejected)
	_log.undone.connect(_on_undone)
	rebuilt.emit()


func _on_executed(command: GameCommand) -> void:
	executed.emit(command)


func _on_rejected(command: GameCommand, reason: StringName) -> void:
	rejected.emit(command, reason)


func _on_undone(command: GameCommand) -> void:
	undone.emit(command)


static func _is_command_script(script: Script) -> bool:
	var current := script
	while current != null:
		if current == (GameCommand as Script):
			return true
		current = current.get_base_script()
	return false


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var seen: Dictionary[StringName, String] = {}
	for script in commands:
		if script == null:
			warnings.append("commands has an empty slot.")
			continue
		var file := script.resource_path.get_file()
		if not _is_command_script(script):
			warnings.append("%s does not extend GameCommand." % file)
			continue
		var type: StringName = script.call(&"command_type")
		if type == &"":
			warnings.append("%s has no command_type()." % file)
		elif seen.has(type):
			warnings.append("%s and %s both use the type %s." % [seen[type], file, type])
		else:
			seen[type] = file
	return warnings
