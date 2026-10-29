extends Node2D

## FsmKit's minimal example: arrows move the square, Enter hits it. The label follows the
## machine's state_changed signal, which is how the rest of a game hears about a state.

@onready var states: FsmMachine = $Mover/States
@onready var label: Label = $Hud/State


func _ready() -> void:
	states.state_changed.connect(_show)
	_show(&"", states.current_name())


func _show(_from: StringName, to: StringName) -> void:
	label.text = "State: %s    (arrows: move, Enter: hit)" % to
