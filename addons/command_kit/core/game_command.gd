class_name GameCommand
extends RefCounted

## One thing a player (or a bot, or the network) asks the game to do, as plain data. Extend it once per kind of order:
##
##   class_name MoveUnit
##   extends GameCommand
##
##   var unit_id := 0
##   var to := Vector2i.ZERO
##
##   static func command_type() -> StringName:
##       return &"move_unit"
##
##   static func from_args(data: Dictionary) -> GameCommand:
##       var cmd := MoveUnit.new()
##       cmd.unit_id = int(data.get("unit_id", 0))
##       cmd.to = data.get("to", Vector2i.ZERO)
##       return cmd
##
##   func args() -> Dictionary:
##       return {"unit_id": unit_id, "to": to}
##
##   func can_run(ctx: Variant) -> StringName:
##       return &"" if ctx.has_unit(unit_id) else &"unknown_unit"
##
##   func run(ctx: Variant) -> void:
##       ctx.move(unit_id, to)
##
## `ctx` is whatever your rules need (your match state): the kit never looks inside it. A `CommandLog` (or a
## `CommandBus`) runs the command, keeps it in its log when it was accepted, and builds it again from the log.

## Who asked for it: a seat, a player slot, -1 for nobody in particular. Kept in the log.
var seat := -1


## The name of this kind of command in the log. Every subclass returns its own, unique in its log.
static func command_type() -> StringName:
	return &""


## Builds this kind of command from `args()`. Every subclass that goes in a log defines it.
static func from_args(_data: Dictionary) -> GameCommand:
	return null


## The type of this command (its script's `command_type()`).
func type() -> StringName:
	var script := get_script() as Script
	return script.call(&"command_type") if script != null else &""


## The command's own data, plain values only (numbers, strings, StringName, vectors, arrays, dictionaries): what
## `from_args` needs to build it again.
func args() -> Dictionary:
	return {}


## Why it cannot run now (a code such as `&"not_your_turn"`), or `&""` when it can. It must not change `ctx`.
func can_run(_ctx: Variant) -> StringName:
	return &""


## Does it. Only called after `can_run` returned `&""`.
func run(_ctx: Variant) -> void:
	pass


## True when `undo` can take it back. Off by default: a command that rolled dice or showed hidden cards usually can't.
func can_undo() -> bool:
	return false


## Takes back what `run` did, leaving `ctx` as it was before.
func undo(_ctx: Variant) -> void:
	push_error("GameCommand: %s cannot be undone" % type())


## The log entry: `{"type": StringName, "seat": int, "args": Dictionary}`.
func to_dict() -> Dictionary:
	return {"type": type(), "seat": seat, "args": args().duplicate(true)}
