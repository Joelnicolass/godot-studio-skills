extends RefCounted

## What a script offers as commands, read from its function list (no instance, no @tool needed): every `do_<name>` is a
## command, with an optional `can_<name>` and `undo_<name>` beside it, and an optional general `can_run`. Used by
## `CommandLog` to run them and by `GameCommands` for its editor warnings. Not a class of its own: no `class_name`.


## One parameter of a `do_` function.
class Param:
	extends RefCounted

	## Its type (`TYPE_NIL`: any).
	var type := TYPE_NIL
	## An `Array[X]` or `Dictionary[K, V]` parameter: the types of its items (`value_*` is X for an array).
	var typed := false
	var key_type := TYPE_NIL
	var value_type := TYPE_NIL


## One command found: its `do_` function and the `can_` and `undo_` that go with it.
class Command:
	extends RefCounted

	var name: StringName = &""
	## The parameters of `do_<name>`, the seat first.
	var params: Array[Param] = []
	## How many parameters a call must give (the seat included): the ones with no default value.
	var required := 0
	## `do_<name>(seat, ...rest)` takes any number of arguments.
	var variadic := false
	var has_can := false
	var can_count := 0
	var has_undo := false
	var undo_count := 0
	## `undo_<name>` has one parameter more than `do_<name>`: it gets what `do_<name>` returned.
	var undo_takes_data := false


const DO := "do_"
const CAN := "can_"
const UNDO := "undo_"
## The general check, run before every `can_<name>`: `can_run(seat, command, args)`.
const GENERAL := &"can_run"

## The commands found, by name.
var commands: Dictionary[StringName, Command] = {}
## True when the script has the general `can_run(seat, command, args)`.
var has_general := false
## Things that are probably a mistake, one sentence each (the editor shows them as warnings).
var problems := PackedStringArray()


func _init(script: Script = null) -> void:
	if script == null:
		return
	var methods: Dictionary[StringName, Dictionary] = {}
	for info: Dictionary in script.get_script_method_list():
		var method := StringName(info["name"])
		if not methods.has(method):
			methods[method] = info
	var names: Array[StringName] = []
	names.assign(methods.keys())
	names.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	has_general = methods.has(GENERAL)
	for method in names:
		var text := String(method)
		if text.begins_with(DO) and text.length() > DO.length():
			_add_command(text.substr(DO.length()), methods)
	for method in names:
		var text := String(method)
		if method != GENERAL and text.begins_with(CAN) and text.length() > CAN.length():
			_check_partner(text, CAN, "can_%s has no do_%s: a typo?", methods)
		elif text.begins_with(UNDO) and text.length() > UNDO.length():
			_check_partner(text, UNDO, "undo_%s has no do_%s: a typo?", methods)
	if commands.is_empty():
		problems.append("The script has no do_<name> function: nothing to run.")


## The commands as text for the inspector: `place (can, undo), pass`. Empty when there are none.
func text() -> String:
	var parts := PackedStringArray()
	var names: Array[StringName] = []
	names.assign(commands.keys())
	names.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for command_name in names:
		var command := commands[command_name]
		var extras := PackedStringArray()
		if command.has_can:
			extras.append("can")
		if command.has_undo:
			extras.append("undo")
		parts.append(command_name if extras.is_empty() else "%s (%s)" % [command_name, ", ".join(extras)])
	return ", ".join(parts)


func _add_command(command_name: String, methods: Dictionary[StringName, Dictionary]) -> void:
	var do_info := methods[StringName(DO + command_name)]
	var command := Command.new()
	command.name = StringName(command_name)
	var params: Array = do_info["args"]
	for info: Dictionary in params:
		command.params.append(_param(info))
	var defaults: Array = do_info["default_args"]
	command.variadic = (int(do_info["flags"]) & METHOD_FLAG_VARARG) != 0
	command.required = params.size() - defaults.size()
	if params.is_empty():
		problems.append("do_%s has no parameters: the first one is the seat (an int)." % command_name)
	var can_name := StringName(CAN + command_name)
	if methods.has(can_name) and can_name != GENERAL:
		var can_info := methods[can_name]
		command.has_can = true
		command.can_count = (can_info["args"] as Array).size()
		if command.can_count != params.size():
			problems.append(
				(
					"can_%s takes %d parameters and do_%s %d: they must match."
					% [command_name, command.can_count, command_name, params.size()]
				)
			)
		var returned := int((can_info["return"] as Dictionary)["type"])
		if returned != TYPE_NIL and returned != TYPE_STRING and returned != TYPE_STRING_NAME:
			problems.append('can_%s must return a String ("" when it can run, else the reason).' % command_name)
	elif can_name == GENERAL and methods.has(can_name):
		problems.append("A command called run clashes with the general can_run(seat, command, args).")
	var undo_name := StringName(UNDO + command_name)
	if methods.has(undo_name):
		var undo_info := methods[undo_name]
		command.has_undo = true
		command.undo_count = (undo_info["args"] as Array).size()
		command.undo_takes_data = command.undo_count == params.size() + 1
		if command.undo_count != params.size() and not command.undo_takes_data:
			problems.append(
				(
					"undo_%s takes %d parameters: the same as do_%s (%d), or one more for what it returned."
					% [command_name, command.undo_count, command_name, params.size()]
				)
			)
	commands[command.name] = command


func _param(info: Dictionary) -> Param:
	var param := Param.new()
	param.type = int(info["type"])
	var hint := int(info["hint"])
	var parts := String(info["hint_string"]).split(";")
	if param.type == TYPE_ARRAY and hint == PROPERTY_HINT_ARRAY_TYPE:
		param.typed = true
		param.value_type = _type_named(parts[0])
	elif param.type == TYPE_DICTIONARY and hint == PROPERTY_HINT_DICTIONARY_TYPE and parts.size() == 2:
		param.typed = true
		param.key_type = _type_named(parts[0])
		param.value_type = _type_named(parts[1])
	return param


## The type a hint string names: `int`, `Vector2i`, `Variant` (any); a class name is an object.
func _type_named(type_name: String) -> int:
	for type in TYPE_MAX:
		if type != TYPE_NIL and type_string(type) == type_name:
			return type
	return TYPE_NIL if type_name == "Variant" else TYPE_OBJECT


func _check_partner(text: String, prefix: String, message: String, methods: Dictionary[StringName, Dictionary]) -> void:
	var command_name := text.substr(prefix.length())
	if not methods.has(StringName(DO + command_name)):
		problems.append(message % [command_name, command_name])
