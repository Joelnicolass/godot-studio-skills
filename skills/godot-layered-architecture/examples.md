# Examples — architecture (generic)

Nothing from a concrete title. Copy and adapt names to the current game.

## Match node + pure core

The node shows in the editor and holds the knobs. The core holds the rule and is tested without a scene.

```gdscript
# match/match_rules.gd
class_name MatchRules
extends RefCounted
## Pure rules of one match: who is alive and who won. No nodes.

var lives: Dictionary[int, int] = {}


func _init(slots: Array[int], start_lives: int) -> void:
	for slot in slots:
		lives[slot] = start_lives


func lose_life(slot: int) -> void:
	lives[slot] = maxi(lives.get(slot, 0) - 1, 0)


## The only slot still alive, or 0 while the match goes on.
func winner() -> int:
	var alive: Array[int] = []
	for slot in lives:
		if lives[slot] > 0:
			alive.append(slot)
	return alive[0] if alive.size() == 1 else 0
```

```gdscript
# match/match.gd (root of match/match.tscn)
class_name Match
extends Node
## One match: owns the clock and the lives. Tune it on this node.

signal finished(winner_slot: int)

## How long a round lasts.
@export_range(10.0, 600.0, 5.0, "suffix:s") var round_seconds: float = 60.0
## Lives each player starts with.
@export_range(1, 9) var start_lives: int = 3

var time_left: float = 0.0
var rules: MatchRules


func start(slots: Array[int]) -> void:
	rules = MatchRules.new(slots, start_lives)
	time_left = round_seconds
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	time_left = maxf(time_left - delta, 0.0)
	if time_left <= 0.0 or rules.winner() != 0:
		set_physics_process(false)
		finished.emit(rules.winner())
```

With MpKit, only the server runs that `_physics_process` (`if MpKit.is_networked() and not MpKit.is_server(): return`).

Row in `docs/tuning.md`: "Round length → `match/match.tscn` → `Match` → `round_seconds`".

## Clean (only repos that already declare it) — minimal session

```gdscript
# src/core/game_session.gd
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
