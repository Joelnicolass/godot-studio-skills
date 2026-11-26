extends Node3D

## DiceKit's smallest example: a die of its own on a DiceRoller (`attack_die.tres`: 3 hit worth 1, 2 blank worth 0,
## 1 crit worth 2), shown by a DiceTray3D. Roll 1, 2 or 3 dice; the label reads the roll once the dice settle. Type a
## seed (0: random) and the same rolls come back in the same order.

@onready var roller: DiceRoller = %Roller
@onready var tray: DiceTray3D = %Tray
@onready var roll_one: Button = %Roll1
@onready var roll_two: Button = %Roll2
@onready var roll_three: Button = %Roll3
@onready var seed_box: SpinBox = %Seed
@onready var result_label: Label = %Result


func _ready() -> void:
	roll_one.pressed.connect(roller.roll.bind(1))
	roll_two.pressed.connect(roller.roll.bind(2))
	roll_three.pressed.connect(roller.roll.bind(3))
	seed_box.value_changed.connect(func(value: float) -> void: roller.rng_seed = int(value))
	roller.rolled.connect(func(_roll: DiceRoll) -> void: result_label.text = "Rolling...")
	tray.settled.connect(_on_settled)


func _on_settled(roll: DiceRoll) -> void:
	var text := "Sum %d · %d hit" % [roll.sum(), roll.count(&"hit")]
	if roll.has(&"crit"):
		text += " · crit!"
	result_label.text = text
