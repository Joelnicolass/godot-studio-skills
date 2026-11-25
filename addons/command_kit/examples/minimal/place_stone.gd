extends GameCommand

## The example's only command: the seat whose turn it is puts a stone on an empty cell. Undoable.
## The state (`ctx`) is a Dictionary: `{"stones": {Vector2i: seat}, "turn": seat}`.

const SCRIPT_PATH := "res://addons/command_kit/examples/minimal/place_stone.gd"

var cell := Vector2i.ZERO


static func command_type() -> StringName:
	return &"place_stone"


static func from_args(data: Dictionary) -> GameCommand:
	var command: GameCommand = (load(SCRIPT_PATH) as GDScript).new()
	command.set(&"cell", data.get("cell", Vector2i.ZERO))
	return command


func args() -> Dictionary:
	return {"cell": cell}


func can_run(ctx: Variant) -> StringName:
	var state := ctx as Dictionary
	if seat != int(state["turn"]):
		return &"not_your_turn"
	if (state["stones"] as Dictionary).has(cell):
		return &"occupied"
	return &""


func run(ctx: Variant) -> void:
	ctx["stones"][cell] = seat
	ctx["turn"] = 1 - seat


func can_undo() -> bool:
	return true


func undo(ctx: Variant) -> void:
	(ctx["stones"] as Dictionary).erase(cell)
	ctx["turn"] = seat
