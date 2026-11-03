@tool
class_name SpillSource3D
extends Node3D

## Where a body spills. Put it in the body where the drops leave (its chest, its shell), give it a
## type, and call hit() where the game takes HP off and die() when the body dies.
##
## In a network game its one value, wound, makes every machine play the same drops, marks and
## puddle: sync it (with spawn on, so a machine that meets the body late starts from it) and call
## hit() and die() only where damage is decided. A machine that meets the body late plays nothing
## that came before. The world's SpillPool3D draws it (one is made if there is none).

## What this body spills.
@export var type: SpillType:
	set(value):
		type = value
		update_configuration_warnings()
## The pool that draws it. Empty: this world's SpillPool3D.
@export var pool: SpillPool3D
## How far under this node the floor may be for its marks and puddle; farther (in the air), none.
## 0: the pool's floor_reach_m. A low source (a bug's shell) wants less than a chest.
@export_range(0.0, 20.0, 0.05, "suffix:m") var floor_reach_m := 0.0
@export_group("Rules")
## A hit that takes at least this share of the max HP spills heavy.
@export_range(0.0, 1.0, 0.01) var heavy_from := 0.4
## Light sprays keep at least this far apart; the hits in between add up.
@export_range(0.0, 5.0, 0.01, "suffix:s") var every_s := 0.25
## The damage (a share of the max HP) that has to add up before a light spray; a hit that comes
## alone (no other for every_s) spills anyway.
@export_range(0.0, 1.0, 0.01) var min_lost := 0.05
@export_group("Try it")
## A light spray here, flying the way this node faces (-Z), in the editor's 3D view too.
@export_tool_button("Spray", "Play") var spray_button := _try_spray
## A heavy spray here, flying the way this node faces (-Z).
@export_tool_button("Heavy spray", "Play") var heavy_button := _try_heavy
## The body dies: a puddle grows under it.
@export_tool_button("Die (puddle)", "Play") var die_button := _try_die
## Takes every mark and puddle off the floor.
@export_tool_button("Clear the floor", "Clear") var clear_button := _try_clear

## The last spray and death, packed (SpillWound): the value to sync. hit(), spray() and die() write
## it; every machine plays what changed.
var wound := Vector4.ZERO:
	set = _set_wound

var _shown_sprays := 0
var _shown_deaths := 0
var _lost_share := 0.0
var _last_spray_us := -1
var _last_hit_us := -1


func _ready() -> void:
	# What the body already had when this machine met it is the past: it is not played.
	_shown_sprays = SpillWound.sprays_of(wound)
	_shown_deaths = SpillWound.deaths_of(wound)
	if Engine.is_editor_hint() or type == null:
		return
	var drawing := current_pool()
	if drawing != null:
		drawing.prepare(type)


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if type == null:
		out.append("Assign a type (a SpillType): what this body spills.")
	else:
		out.append_array(type.problems())
	return out


## A hit of [param damage] on a body of [param max_hp], coming from [param from] (the hit point or
## the attacker: the drops fly away from it; none: any way). [param heavy]: a blow that always
## spills heavy (a finisher). The rules: heavy at heavy_from of the max HP; light sprays every_s
## apart, small hits adding up to min_lost. True if it spilled.
func hit(damage: float, max_hp: float, from := Vector3.INF, heavy := false) -> bool:
	if damage <= 0.0 or max_hp <= 0.0:
		return false
	var now := Time.get_ticks_usec()
	var share := damage / max_hp
	_lost_share += share
	var kind := SpillRules.kind_for(
		share, _lost_share, _since_s(_last_spray_us, now), _since_s(_last_hit_us, now),
		heavy_from, every_s, min_lost, heavy)
	_last_hit_us = now
	if kind == SpillRules.Kind.NONE:
		return false
	_lost_share = 0.0
	_last_spray_us = now
	spray(kind == SpillRules.Kind.HEAVY, from)
	return true


## Spills now, whatever the rules (a wound of the game's own): a light or [param heavy] spray
## coming from [param from] (none: any way).
func spray(heavy := false, from := Vector3.INF) -> void:
	var source := from if from.is_finite() else Vector3.INF
	wound = SpillWound.pack(source, SpillWound.sprays_of(wound) + 1, SpillWound.deaths_of(wound), heavy)


## The body died: a puddle grows on the floor under this node. A body that comes back can die again.
func die() -> void:
	wound = SpillWound.pack(
		SpillWound.from_of(wound), SpillWound.sprays_of(wound), SpillWound.deaths_of(wound) + 1,
		SpillWound.is_heavy(wound))


## The pool that draws this source: pool, or this world's (made if there is none). Null on a
## dedicated server or out of the tree.
func current_pool() -> SpillPool3D:
	if pool != null:
		return pool
	return SpillPool3D.for_node(self) if is_inside_tree() else null


## What one spill of this source costs, as the inspector shows it.
func cost_text() -> String:
	if type == null:
		return "Cost: no type yet."
	return "Cost of a hit: %d drops (heavy %d); marks on the floor: %d (heavy %d). A death: 1 puddle." % [
		type.drops, type.heavy_drops, type.marks_per_spray, type.marks_per_heavy]


## The physics body above [param node] (the one that spills): the floor rays go through it.
static func body_above(node: Node) -> PhysicsBody3D:
	var at := node.get_parent()
	while at != null:
		if at is PhysicsBody3D:
			return at
		at = at.get_parent()
	return null


func _set_wound(value: Vector4) -> void:
	wound = value
	# Before it is ready (a scene's value, the network's first) it is the past: _ready takes it.
	if is_node_ready():
		_show()


func _show() -> void:
	var sprays := SpillWound.sprays_of(wound)
	var deaths := SpillWound.deaths_of(wound)
	var sprayed := sprays != _shown_sprays
	var died := deaths != _shown_deaths
	_shown_sprays = sprays
	_shown_deaths = deaths
	if not (sprayed or died) or type == null or not is_inside_tree():
		return
	var drawing := current_pool()
	if drawing == null:
		return
	var exclude: Array[RID] = []
	var body := body_above(self)
	if body != null:
		exclude.append(body.get_rid())
	var at := global_position
	if sprayed:
		var from := SpillWound.from_of(wound)
		var away := at - from if from.is_finite() else Vector3.ZERO
		drawing.spill(type, at, away, SpillWound.is_heavy(wound), exclude, floor_reach_m)
	if died:
		drawing.puddle(type, at, exclude, floor_reach_m)


static func _since_s(then_us: int, now_us: int) -> float:
	return INF if then_us < 0 else float(now_us - then_us) / 1000000.0


func _try_spray() -> void:
	_try(func() -> void: spray(false, global_position + global_basis.z))


func _try_heavy() -> void:
	_try(func() -> void: spray(true, global_position + global_basis.z))


func _try_die() -> void:
	_try(die)


func _try_clear() -> void:
	var drawing := current_pool()
	if drawing != null:
		drawing.clear()


# The editor's buttons: the pool takes the type's values again first (you may have changed them).
func _try(action: Callable) -> void:
	if type == null:
		push_warning("SpillSource3D '%s': assign a type first." % name)
		return
	var drawing := current_pool()
	if drawing == null:
		return
	drawing.prepare(type)
	drawing.refresh(type)
	action.call()
