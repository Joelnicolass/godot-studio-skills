extends CharacterBody2D

## RtsKit's minimal unit: the kit hands its RtsUnit an order; this script, the game's part, walks
## there and says when it is done. A game's unit does the same with its own movement (a
## NavigationAgent2D) and fights the order's target. GUIDE.md › 2 is this script in 3D.

## Pixels per second.
@export var speed := 160.0
## How close counts as there, in pixels.
@export var arrive := 4.0

var order: RtsUnitOrder

@onready var unit: RtsUnit = $RtsUnit
@onready var ring: CanvasItem = $Ring


func _ready() -> void:
	unit.order_started.connect(_on_order_started)
	unit.order_ended.connect(_on_order_ended)
	unit.selected_changed.connect(func(on: bool) -> void: ring.visible = on)


func _on_order_started(next: RtsUnitOrder, _replaced: RtsUnitOrder) -> void:
	order = next


func _on_order_ended(old: RtsUnitOrder, _result: StringName) -> void:
	if old == order:
		order = null


func _physics_process(delta: float) -> void:
	if order == null:
		return
	# spot_2d() is this unit's place in the formation; it follows a guarded body that walks.
	var to := order.spot_2d() - global_position
	if to.length() <= arrive:
		velocity = Vector2.ZERO
		if order.type.ends_on_its_own:
			unit.complete()  # the next queued order, if any, starts by itself
		return
	velocity = to.normalized() * minf(speed, to.length() / delta)
	move_and_slide()
