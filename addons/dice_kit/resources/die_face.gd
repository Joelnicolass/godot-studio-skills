@tool
@icon("res://addons/dice_kit/icons/die_face.svg")
class_name DieFace
extends Resource

## One face of a die: the number it adds to a roll's sum, the symbols a roll counts (hit, blank, shield) and an icon
## for views. Any of them may stay empty: a numbered die has only values, a die of symbols only tags. A `DieData` lists
## its faces; the same face may be in the list more than once to come up more often.

## What this face adds to `DiceRoll.sum()`. A symbol that adds nothing keeps 0.
@export var value := 0:
	set(new_value):
		value = new_value
		emit_changed()
## The symbols on this face, counted by `DiceRoll.count(tag)`. A symbol may be there more than once: a face
## `[hit, hit, shield]` counts 2 hits and 1 shield. Empty: no symbol.
@export var tags: Array[StringName] = []:
	set(new_tags):
		tags = new_tags
		emit_changed()
## The picture views draw for this face (`DiceTray3D` puts it on top). Empty: they write the value and the tags.
@export var icon: Texture2D:
	set(new_icon):
		icon = new_icon
		emit_changed()

## A shortcut for a face with one symbol: reads the first of `tags` (empty when there is none); writing it leaves
## `tags` with only that one (or with none, for an empty name).
var tag: StringName:
	get:
		return tags[0] if not tags.is_empty() else &""
	set(new_tag):
		var list: Array[StringName] = []
		if new_tag != &"":
			list.append(new_tag)
		tags = list


## A face worth `p_value`, with the one symbol `p_tag` and the picture `p_icon`. All optional, so the editor can create
## one; for several symbols, set `tags` afterwards.
func _init(p_value := 0, p_tag := &"", p_icon: Texture2D = null) -> void:
	value = p_value
	tag = p_tag
	icon = p_icon
