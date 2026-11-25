extends "res://addons/command_kit/core/game_command.gd"

## Test command: adds `amount` to `ctx.total`. Undoable. Rejects amounts below 1.

var amount := 1


static func command_type() -> StringName:
	return &"add"


static func from_args(data: Dictionary) -> GameCommand:
	var command := (load("res://addons/command_kit/tests/fixture_add.gd") as GDScript).new() as GameCommand
	command.set(&"amount", int(data.get("amount", 1)))
	return command


func args() -> Dictionary:
	return {"amount": amount}


func can_run(ctx: Variant) -> StringName:
	if amount < 1:
		return &"bad_amount"
	if bool((ctx as Dictionary).get("locked", false)):
		return &"locked"
	return &""


func run(ctx: Variant) -> void:
	ctx["total"] = int(ctx["total"]) + amount


func can_undo() -> bool:
	return true


func undo(ctx: Variant) -> void:
	ctx["total"] = int(ctx["total"]) - amount
