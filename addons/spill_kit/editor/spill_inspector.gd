@tool
extends EditorInspectorPlugin

## The cost line at the top of a SpillPool3D's inspector (what it keeps: drops, marks, puddles, draw
## calls) and of a SpillSource3D's (what one hit and one death leave). It follows the values as
## they change.


## A label that reads its node's cost_text() a few times a second.
class CostLabel:
	extends Label

	const EVERY_S := 0.25

	var target: WeakRef
	var _wait_s := 0.0

	func _ready() -> void:
		autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_read()

	func _process(delta: float) -> void:
		_wait_s -= delta
		if _wait_s <= 0.0:
			_wait_s = EVERY_S
			_read()

	func _read() -> void:
		var node: Object = target.get_ref()
		if node != null and node.has_method(&"cost_text"):
			text = node.call(&"cost_text")


func _can_handle(object: Object) -> bool:
	return object is SpillPool3D or object is SpillSource3D


func _parse_begin(object: Object) -> void:
	var label := CostLabel.new()
	label.name = "SpillKitCost"
	label.target = weakref(object)
	add_custom_control(label)
