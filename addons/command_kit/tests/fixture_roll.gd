extends "res://addons/command_kit/core/game_command.gd"

## Test command: adds a die roll from `ctx.rng` to `ctx.total`. Not undoable (a roll cannot be taken back).


static func command_type() -> StringName:
	return &"roll"


static func from_args(_data: Dictionary) -> GameCommand:
	return (load("res://addons/command_kit/tests/fixture_roll.gd") as GDScript).new() as GameCommand


func run(ctx: Variant) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	ctx["total"] = int(ctx["total"]) + rng.randi_range(1, 6)
