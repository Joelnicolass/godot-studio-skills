extends Node

## Test game: a counter with one command of every kind. Typed state, no dictionaries.

var total := 0
var rng := RandomNumberGenerator.new()
var locked := false
## When 0 or more, the general check lets only that seat through.
var only_seat := -1
## Every can_ function that ran, in order.
var checked: Array[String] = []
var last_items: Array = []
var last_label := &""
var last_factor := 0.0
var last_rest: Array = []
var last_cells: Array[Vector2i] = []
var last_weights: Dictionary[StringName, float] = {}
## Set by a test to make `do_nested` call back into the log.
var log_of_the_game: CommandLog


func can_run(seat: int, command: StringName, _args: Array) -> String:
	checked.append("can_run %s" % command)
	if only_seat >= 0 and seat != only_seat:
		return "not_your_turn"
	return ""


func can_add(_seat: int, amount: int) -> String:
	checked.append("can_add")
	if amount < 1:
		return "bad_amount"
	if locked:
		return "locked"
	return ""


func do_add(_seat: int, amount: int) -> void:
	total += amount


func undo_add(_seat: int, amount: int) -> void:
	total -= amount


## No undo: a die cannot be taken back.
func do_roll(_seat: int) -> void:
	total += rng.randi_range(1, 6)


## Returns what it took, so that undo_take can give it back.
func do_take(_seat: int, amount: int) -> int:
	var taken := mini(amount, total)
	total -= taken
	return taken


func undo_take(_seat: int, _amount: int, taken: int) -> void:
	total += taken


func do_scale(_seat: int, factor: float) -> void:
	last_factor = factor


func do_label(_seat: int, label: StringName, suffix := "x") -> void:
	last_label = StringName("%s%s" % [label, suffix])


func do_shout(_seat: int, text: String) -> void:
	last_label = StringName(text.to_upper())


## Changes the array it was given.
func do_push(_seat: int, items: Array) -> void:
	items.append(99)
	last_items = items


func do_pick(_seat: int, who: Node) -> void:
	total += 1 if who != null else 0


func do_any(_seat: int, thing) -> void:
	last_rest = [thing]


func do_many(_seat: int, ...rest: Array) -> void:
	last_rest = rest


func do_defaults(_seat: int, first: int, second := 5) -> void:
	total += first + second


func do_nested(_seat: int, which: StringName) -> void:
	if which == &"undo":
		log_of_the_game.undo()
	elif which == &"replay":
		log_of_the_game.replay([])
	else:
		log_of_the_game.run(0, &"add", [1])


## Not a command: it does not start with do_.
func helper_total() -> int:
	return total


func do_path(_seat: int, cells: Array[Vector2i]) -> void:
	last_cells = cells


func do_weights(_seat: int, weights: Dictionary[StringName, float]) -> void:
	last_weights = weights


func do_nodes(_seat: int, nodes: Array[Node]) -> void:
	total += nodes.size()
