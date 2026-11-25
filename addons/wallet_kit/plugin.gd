@tool
extends EditorPlugin

const WALLET := preload("res://addons/wallet_kit/nodes/wallet.gd")


func _enter_tree() -> void:
	add_custom_type("Wallet", "Node", WALLET, null)


func _exit_tree() -> void:
	remove_custom_type("Wallet")
