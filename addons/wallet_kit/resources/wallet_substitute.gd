@tool
@icon("res://addons/wallet_kit/icons/wallet_substitute.svg")
class_name WalletSubstitute
extends Resource

## One rule for paying: `rate` of `key` cover 1 that is missing of another key. A `Wallet` takes a list of them in its
## `substitutes`, in the order they are tried.

## The key that pays instead (for example `gold`).
@export var key: StringName = &"":
	set(value):
		key = value
		emit_changed()
## The keys it can cover when they are missing. Empty: every key but itself. List only what it may cover: a key left
## out (culture, morale) is never covered.
@export var covers: Array[StringName] = []:
	set(value):
		covers = value
		emit_changed()
## How many of `key` pay for 1 that is missing. With 2, two wood cover one gold.
@export_range(1, 99, 1, "or_greater") var rate := 1:
	set(value):
		rate = value
		emit_changed()
