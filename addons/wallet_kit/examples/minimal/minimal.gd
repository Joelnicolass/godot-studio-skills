extends Control

## A wallet with food, wood, ore and gold. Harvest adds 1 food, 2 wood and 1 ore (food holds 2: the rest is lost).
## Build costs 2 wood and 1 ore. Two substitutes, set on the Wallet in the inspector, cover what is missing:
## 2 food cover 1 wood, and gold covers anything, 1 to 1.

const HARVEST := {&"food": 1, &"wood": 2, &"ore": 1}
const BUILD := {&"wood": 2, &"ore": 1}

@onready var wallet: Wallet = %Wallet
@onready var amounts_label: Label = %Amounts
@onready var log_label: Label = %Log
@onready var build: Button = %Build


func _ready() -> void:
	wallet.changed.connect(func(_key: StringName, _value: int) -> void: _refresh())
	wallet.overflowed.connect(func(key: StringName, lost: int) -> void: _note("%d %s lost" % [lost, key]))
	%Harvest.pressed.connect(func() -> void: wallet.add(HARVEST))
	build.pressed.connect(_on_build)
	_refresh()


func _on_build() -> void:
	var payment := wallet.payment_for(BUILD)
	if wallet.pay(BUILD):
		var parts: PackedStringArray = []
		for key in payment:
			parts.append("%d %s" % [payment[key], key])
		_note("Built, paid " + ", ".join(parts))


func _refresh() -> void:
	var parts: PackedStringArray = []
	for key: StringName in [&"food", &"wood", &"ore", &"gold"]:
		parts.append("%s %d/%d" % [key, wallet.amount(key), wallet.limit(key)])
	amounts_label.text = " · ".join(parts)
	build.disabled = not wallet.can_pay(BUILD)


func _note(line: String) -> void:
	log_label.text = (line + "\n" + log_label.text).strip_edges()
