@tool
extends EditorPlugin

const PILE := preload("res://addons/deck_kit/nodes/card_pile.gd")
const DECK := preload("res://addons/deck_kit/nodes/deck.gd")
const HAND_VIEW := preload("res://addons/deck_kit/nodes/hand_view.gd")


func _enter_tree() -> void:
	add_custom_type("CardPile", "Node", PILE, preload("res://addons/deck_kit/icons/card_pile.svg"))
	add_custom_type("Deck", "Node", DECK, preload("res://addons/deck_kit/icons/deck.svg"))
	add_custom_type("HandView", "Control", HAND_VIEW, preload("res://addons/deck_kit/icons/hand_view.svg"))


func _exit_tree() -> void:
	remove_custom_type("HandView")
	remove_custom_type("Deck")
	remove_custom_type("CardPile")
