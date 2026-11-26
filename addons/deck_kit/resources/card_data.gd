@tool
@icon("res://addons/deck_kit/icons/card_data.svg")
class_name CardData
extends Resource

## One card: its id, what it shows and its tags. Piles hold the same `CardData` as many times as there are copies.
## A game that needs numbers on its cards extends it with typed fields (`class_name EventCard extends CardData` and
## `@export var food := 0`): never a free Dictionary of data.

## What saves and loads know the card by (`to_dict` writes it, `from_dict` finds it). Unique within a game.
@export var id: StringName = &"":
	set(value):
		id = value
		emit_changed()
## The name on the card. Views show the id when it is empty.
@export var title: String = "":
	set(value):
		title = value
		emit_changed()
## What the card says. Views show it where the art goes when the card has no art.
@export_multiline var text: String = "":
	set(value):
		text = value
		emit_changed()
## The picture on the card.
@export var art: Texture2D:
	set(value):
		art = value
		emit_changed()
## Kinds the card belongs to (`event`, `attack`): `has_tag`, `CardStack.count_tag` and views read them.
@export var tags: Array[StringName] = []:
	set(value):
		tags = value
		emit_changed()


## True when the card has `tag`.
func has_tag(tag: StringName) -> bool:
	return tags.has(tag)
