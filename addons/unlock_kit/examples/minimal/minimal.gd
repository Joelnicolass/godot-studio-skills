extends Control

## A small tech tree in three branches, built in the editor with nested `UnlockEntry` nodes: Farming (a starting tech)
## > Irrigation > Aqueduct, Farming > Pottery, Masonry > Walls and Writing > Library. Aqueduct also requires Masonry
## (a cross link in its `requires`), and Market requires Pottery or Writing (its `requires_any`, drawn dashed). Clicking
## a box buys it with `tree.buy(id, _pay)`: the kit asks `_pay`, and this example keeps its own points.

const START_POINTS := 2
const GIFT := 3

var points := START_POINTS

@onready var tree: UnlockTree = %Tree
@onready var view: UnlockTreeView = %View
@onready var points_label: Label = %Points
@onready var add_points: Button = %AddPoints
@onready var reset_button: Button = %Reset
@onready var log_label: Label = %Log


func _ready() -> void:
	view.entry_pressed.connect(_on_entry_pressed)
	add_points.pressed.connect(_on_add_points)
	reset_button.pressed.connect(_on_reset)
	_refresh()


func _on_entry_pressed(id: StringName) -> void:
	var title := tree.title_of(id)
	var price := _price(id)
	if tree.buy(id, _pay):
		_note("Unlocked %s for %d points" % [title, price])
		_refresh()
		return
	match tree.why_not(id):
		"already_unlocked":
			_note("%s is already unlocked" % title)
		"locked":
			_note("%s needs %s first" % [title, _needs_text(id)])
		_:
			_note("%s costs %d points (you have %d)" % [title, price, points])


# What the kit calls to charge a cost: all or nothing.
func _pay(cost: Dictionary) -> bool:
	var price: int = cost.get(&"points", 0)
	if points < price:
		return false
	points -= price
	return true


func _price(id: StringName) -> int:
	return tree.cost_of(id).get(&"points", 0)


# "Masonry" for a missing requirement of `requires`, "Pottery or Writing" when none of `requires_any` is unlocked.
func _needs_text(id: StringName) -> String:
	var parts := PackedStringArray()
	var any := tree.requires_any(id)
	var one_of := PackedStringArray()
	for need in tree.missing(id):
		if any.has(need):
			one_of.append(tree.title_of(need))
		else:
			parts.append(tree.title_of(need))
	if not one_of.is_empty():
		parts.append(" or ".join(one_of))
	return ", ".join(parts)


# Wired in the editor: the Aqueduct entry's own `unlocked` signal (Node panel > Signals).
func _on_aqueduct_unlocked() -> void:
	_note("Aqueduct.unlocked reached the scene")


func _on_add_points() -> void:
	points += GIFT
	_note("+%d points" % GIFT)
	_refresh()


func _on_reset() -> void:
	points = START_POINTS
	tree.reset()
	_note("Reset: only the starting tech is unlocked")
	_refresh()


func _refresh() -> void:
	points_label.text = "Points: %d" % points


# The newest line first; the last few only.
func _note(line: String) -> void:
	var lines := (line + "\n" + log_label.text).strip_edges().split("\n")
	log_label.text = "\n".join(lines.slice(0, 6))
