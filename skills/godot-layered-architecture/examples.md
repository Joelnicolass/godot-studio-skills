# Examples — architecture (generic)

Nothing from a concrete title. Copy and adapt names to the current game.

## Clean — minimal session

```gdscript
# src/core/autoload/game_session.gd
extends Node

var is_running: bool = false
var score: Dictionary[int, int] = {}


func start(slots: Array[int]) -> void:
	is_running = true
	score.clear()
	for slot in slots:
		score[slot] = 0
	set_process(true)


func abort() -> void:
	is_running = false
	set_process(false)


func add_score(slot: int, delta: int) -> void:
	if not is_running:
		return
	score[slot] = score.get(slot, 0) + delta


# The snapshot is the network edge: the only place where an untyped Dictionary is fine.
func to_snapshot() -> Dictionary:
	return {"is_running": is_running, "score": score.duplicate()}


func apply_snapshot(data: Dictionary) -> void:
	set_process(false)
	is_running = bool(data.get("is_running", false))
	score.assign(data.get("score", {}))
```

## Standard — Match node in the world

```gdscript
# scenes/world/match.gd
extends Node

signal finished(winner_slot: int)

@export var round_seconds: float = 60.0
@export var start_lives: int = 3

var time_left: float = 0.0
var lives: Dictionary[int, int] = {}


func start(slots: Array[int]) -> void:
	time_left = round_seconds
	lives.clear()
	for slot in slots:
		lives[slot] = start_lives
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not MpKit.is_networked() or MpKit.is_server():
		time_left = maxf(time_left - delta, 0.0)
		if time_left <= 0.0:
			set_physics_process(false)
			finished.emit(0)
```
