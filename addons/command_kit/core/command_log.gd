class_name CommandLog
extends RefCounted

## Runs your game's moves as named commands, as plain data: no nodes, no scene. A command is a function of your game
## object: `do_place(seat, cell)` does it, `can_place(seat, cell)` says why not (`""` = it can) and
## `undo_place(seat, cell)` takes it back. The log runs only the valid ones and keeps the accepted ones as
## `{name, seat, args}`, enough to save a match, send it, take back the last moves (`undo`) or play it all again on a
## fresh state (`replay`). Rejected commands leave no trace. A game keeps one in its rules (`CommandLog.new(self)`);
## `GameCommands` shows one in the editor. The log does not keep `game` alive.

## `name` ran and is in the history (when `keep_history` is on).
signal done(seat: int, name: StringName, args: Array)
## `name` did not run: `reason` is what the game said (`can_run`, `can_<name>`) or one of the codes below.
signal rejected(seat: int, name: StringName, args: Array, reason: String)
## `name` was taken back and left the history.
signal undone(seat: int, name: StringName, args: Array)

## There is no `do_<name>` in the game (or there is no game).
const UNKNOWN_COMMAND := "unknown_command"
## The number or the types of the arguments do not match `do_<name>`.
const BAD_ARGUMENTS := "bad_arguments"
## A `can_` function answered `false` (or something that is not a text).
const NOT_ALLOWED := "not_allowed"
## `run`, `undo` or `replay` was called from inside a `can_`, `do_` or `undo_` function of the game.
const BUSY := "busy"

const Scan := preload("res://addons/command_kit/core/command_scan.gd")

## Off: commands still run and emit, but nothing is kept (no undo, no history).
var keep_history := true
## The object with the `do_` / `can_` / `undo_` functions (a Node, or the RefCounted that holds your rules). Changing it
## reads its commands again and keeps the history.
var game: Object:
	get:
		return _game.get_ref() as Object if _game != null else null
	set(value):
		_game = weakref(value) if value != null else null

var _game: WeakRef
var _warned_gone := false
var _scan: Scan
var _scanned: Script
var _replaying := false
var _inside := ""
var _done: Array[_Entry] = []


func _init(game_object: Object = null) -> void:
	game = game_object


## The names of the commands the game has (every `do_<name>`), sorted.
func commands() -> Array[StringName]:
	var list: Array[StringName] = []
	list.assign(_index().commands.keys())
	list.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return list


func has_command(command_name: StringName) -> bool:
	return _index().commands.has(command_name)


## `""` when `name` can run now, else the reason. Changes nothing and emits nothing.
func can_run(seat: int, command_name: StringName, args: Array = []) -> String:
	return _check(seat, command_name, args, [])


## Runs `do_<name>(seat, args...)` when the checks allow it. Returns `""` when it ran, else the reason. The checks, in
## order: the command exists, the arguments fit `do_<name>`, the game's `can_run`, the game's `can_<name>`. Emits
## `done` (after it is in the history) or `rejected`.
func run(seat: int, command_name: StringName, args: Array = []) -> String:
	if _inside != "":
		return _busy("run")
	var ready: Array = []
	var reason := _check(seat, command_name, args, ready)
	if reason != "":
		rejected.emit(seat, command_name, args, reason)
		return reason
	var kept := args.duplicate(true)
	var result: Variant = _call(&"do_%s" % command_name, ready)
	if keep_history:
		var entry := _Entry.new()
		entry.name = command_name
		entry.seat = seat
		entry.args = kept
		entry.returned = result
		_done.append(entry)
	done.emit(seat, command_name, kept.duplicate(true))
	return ""


## True when the last command of the history has an `undo_<name>`.
func can_undo() -> bool:
	if _done.is_empty():
		return false
	var command: Scan.Command = _index().commands.get(_done[-1].name)
	return command != null and command.has_undo


## Takes back the last command: calls `undo_<name>` and removes it from the history. False when there is none or it has
## no `undo_`. Only the last: when it cannot be undone, the ones before it cannot either. Emits `undone`.
func undo() -> bool:
	if _inside != "":
		_busy("undo")
		return false
	if not can_undo():
		return false
	var entry: _Entry = _done.pop_back()
	var command: Scan.Command = _index().commands[entry.name]
	var arguments: Array = []
	if not _prepare(command, entry.seat, entry.args, arguments):
		arguments = _with_seat(entry.seat, entry.args.duplicate(true))
	if command.undo_takes_data:
		arguments.append(entry.returned)
	_call(&"undo_%s" % entry.name, arguments)
	undone.emit(entry.seat, entry.name, entry.args.duplicate(true))
	return true


## A copy of the history, oldest first: one `{"name": StringName, "seat": int, "args": Array}` per accepted command.
func history() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for entry in _done:
		list.append({"name": entry.name, "seat": entry.seat, "args": entry.args.duplicate(true)})
	return list


## Runs every entry of `entries` (what `history()` gave, usually on a fresh state built with the same seed). Returns
## `""` when all of them ran, else the reason of the first that did not: the ones before it already ran. The ones that
## ran are added at the end of the history: on an empty one (`clear()` first) a full replay leaves it equal to
## `entries`.
## While it runs, `is_replaying()` is true: a listener that sends commands of its own (a bot, an automatic effect)
## must not send them then, because they are in the history already.
func replay(entries: Array) -> String:
	if _inside != "":
		return _busy("replay")
	var was_replaying := _replaying
	_replaying = true
	var result := ""
	for entry: Variant in entries:
		var problem := _entry_problem(entry)
		if problem != "":
			result = problem
			break
		var line := entry as Dictionary
		result = run(int(line["seat"]), StringName(line["name"]), line["args"] as Array)
		if result != "":
			break
	_replaying = was_replaying
	return result


## True while `replay` runs: commands come from the history, not from a player.
func is_replaying() -> bool:
	return _replaying


## How many commands are in the history.
func size() -> int:
	return _done.size()


## Empties the history (the commands stay).
func clear() -> void:
	_done.clear()


func _index() -> Scan:
	var target := game
	var script := target.get_script() as Script if target != null else null
	if _scan == null or script != _scanned:
		_scanned = script
		_scan = Scan.new(script)
	return _scan


## `""` when `command_name` can run now, else the reason. Fills `ready` with the arguments to call `do_` with.
func _check(seat: int, command_name: StringName, args: Array, ready: Array) -> String:
	var scan := _index()
	var command: Scan.Command = scan.commands.get(command_name)
	if command == null or game == null:
		if _game != null and not _warned_gone:
			_warned_gone = true
			push_error("CommandLog: the game object is gone: keep a reference to it (the log does not keep it alive)")
		return UNKNOWN_COMMAND
	if not _prepare(command, seat, args, ready):
		return BAD_ARGUMENTS
	if scan.has_general:
		var reason := _ask(&"can_run", [seat, command_name, args.duplicate(true)])
		if reason != "":
			return reason
	if command.has_can:
		return _ask(&"can_%s" % command_name, ready.duplicate(true))
	return ""


## Checks `seat` and `args` against the parameters of `do_<name>` and fills `ready` with what to call it with (a plain
## `Array` goes into an `Array[X]` parameter, as a client of the network would send it). False: they do not fit.
func _prepare(command: Scan.Command, seat: int, args: Array, ready: Array) -> bool:
	var given := args.size() + 1
	if given < command.required or (not command.variadic and given > command.params.size()):
		return false
	var values: Array = [seat]
	values.append_array(args)
	for i in values.size():
		if i >= command.params.size():
			ready.append(values[i])
		elif not _convert(command.params[i], values[i], ready):
			return false
	return true


func _convert(param: Scan.Param, value: Variant, ready: Array) -> bool:
	if param.typed and typeof(value) == param.type:
		var typed: Variant = _typed(param, value)
		ready.append(typed)
		return typed != null
	ready.append(value)
	return _accepts(param.type, value)


## `value` (an Array or a Dictionary) as the typed collection `param` asks for, or null when it does not fit.
func _typed(param: Scan.Param, value: Variant) -> Variant:
	return (
		_typed_array(param, value as Array)
		if param.type == TYPE_ARRAY
		else _typed_dictionary(param, value as Dictionary)
	)


func _typed_array(param: Scan.Param, items: Array) -> Variant:
	if items.is_typed():
		return items if items.get_typed_builtin() == param.value_type else null
	if param.value_type == TYPE_OBJECT:
		return null
	for item: Variant in items:
		if not _same(param.value_type, item):
			return null
	return Array(items, param.value_type, &"", null)


func _typed_dictionary(param: Scan.Param, map: Dictionary) -> Variant:
	if map.get_typed_key_builtin() != TYPE_NIL or map.get_typed_value_builtin() != TYPE_NIL:
		var same := map.get_typed_key_builtin() == param.key_type and map.get_typed_value_builtin() == param.value_type
		return map if same else null
	if param.key_type == TYPE_OBJECT or param.value_type == TYPE_OBJECT:
		return null
	for key: Variant in map:
		if not _same(param.key_type, key) or not _same(param.value_type, map[key]):
			return null
	return Dictionary(map, param.key_type, &"", null, param.value_type, &"", null)


static func _same(expected: int, value: Variant) -> bool:
	return expected == TYPE_NIL or typeof(value) == expected or (expected == TYPE_FLOAT and typeof(value) == TYPE_INT)


static func _accepts(expected: int, value: Variant) -> bool:
	var actual := typeof(value)
	if expected == TYPE_NIL or expected == actual:
		return true
	if expected == TYPE_OBJECT:
		return value == null
	if expected == TYPE_FLOAT:
		return actual == TYPE_INT
	if expected == TYPE_STRING or expected == TYPE_STRING_NAME:
		return actual == TYPE_STRING or actual == TYPE_STRING_NAME
	return false


func _entry_problem(entry: Variant) -> String:
	if not entry is Dictionary:
		return UNKNOWN_COMMAND
	var line := entry as Dictionary
	var entry_name: Variant = line.get("name")
	if typeof(entry_name) != TYPE_STRING and typeof(entry_name) != TYPE_STRING_NAME:
		return UNKNOWN_COMMAND
	if not line.get("args") is Array or typeof(line.get("seat")) != TYPE_INT:
		return BAD_ARGUMENTS
	return ""


## Calls a function of the game and returns what it gave. While it runs, `run`, `undo` and `replay` answer BUSY.
func _call(method: StringName, arguments: Array) -> Variant:
	var outer := _inside
	_inside = String(method)
	var result: Variant = game.callv(method, arguments)
	_inside = outer
	return result


## `can_run` and `can_<name>`: the reason they gave, `""` when they let it run. `true` or nothing (an untyped function
## that returned nothing) lets it run, `false` rejects with NOT_ALLOWED, anything else is a mistake and rejects too.
func _ask(method: StringName, arguments: Array) -> String:
	var result: Variant = _call(method, arguments)
	match typeof(result):
		TYPE_STRING, TYPE_STRING_NAME:
			return String(result)
		TYPE_NIL:
			return ""
		TYPE_BOOL:
			return "" if result else NOT_ALLOWED
	push_error('CommandLog: %s must return a String: "" when it can run, else the reason' % method)
	return NOT_ALLOWED


func _busy(called: String) -> String:
	push_error(
		"CommandLog: %s called %s(); a command cannot run another: emit a signal or do it after" % [_inside, called]
	)
	return BUSY


static func _with_seat(seat: int, args: Array) -> Array:
	var list: Array = [seat]
	list.append_array(args)
	return list


## One command in the history, with what its `do_` function returned (for `undo_`; it is not in `history()`).
class _Entry:
	extends RefCounted

	var name: StringName = &""
	var seat := 0
	var args: Array = []
	var returned: Variant = null
