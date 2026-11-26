@tool
extends PanelContainer

## One card of the example's hand as a scene: `HandView.card_scene` makes one per card, sets `card` and places it.
## Change this scene (a frame, a cost in a corner, the fields of your own card type) and every card in the hand
## follows. `@tool`, so the editor shows it too.

## The card to show. The HandView sets it.
var card: CardData:
	set(value):
		card = value
		if is_node_ready():
			_show()

@onready var _title: Label = %Title
@onready var _text: Label = %Text
@onready var _tags: Label = %Tags


func _ready() -> void:
	_show()


func _show() -> void:
	if card == null:
		return
	_title.text = card.title if card.title != "" else String(card.id)
	_text.text = card.text
	_tags.text = " · ".join(PackedStringArray(card.tags))
