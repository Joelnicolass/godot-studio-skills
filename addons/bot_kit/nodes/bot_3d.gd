@tool
@icon("res://addons/bot_kit/editor/bot_3d.svg")
class_name Bot3D
extends Node3D

## A bot that plays your character the way a person does. Put it on the character (a child of its body) and have the
## character read `bot.input` where a person's reads `Input`: the bot only presses keys, so the character moves, jumps
## and shoots with its own code, and a network game sends those keys like a player's.
## - It sees the nearest enemy (a node of `target_group`) within its difficulty's sight with a clear line.
## - In a fight it turns toward it at a person's speed, with an aim error, reacts before its first shot, fires inside a
##   cone in bursts, aims ahead of a walking enemy and lobs throws in an arc, keeps its distance and steps sideways.
## - It picks, among its `weapons`, the one that suits the distance (`weapon_changed`).
## - With nobody in sight it walks the level's navigation mesh: to a BotGoal3D (a pickup), to where it last saw an
##   enemy, or anywhere it can reach; stuck, it jumps and picks another way.
## - Your own behaviours are BotMode children (flee, guard, follow). Its difficulty is a BotDifficulty.
## It runs where `enabled` is on: in a network game, only where the game is decided (the server).

## It saw a new enemy, or lost the one it had (null).
signal target_changed(new_target: Node3D)
## It wants another weapon: switch your character to it.
signal weapon_changed(new_weapon: BotWeapon)
## It does something else now: &"fight", &"roam" or the name of one of its BotMode children.
signal mode_changed(new_mode: StringName)
## It wanted to move and did not for `stuck_s`: it jumped and picked another way.
signal stuck

const FIGHT := &"fight"
const ROAM := &"roam"
## Physics priority: before your character (0) and before a network input that builds its frame from the keys (-100).
const THINK_PRIORITY := -150
## A goal it could not reach is not tried again for this long.
const SKIP_UNREACHABLE_S := 5.0
const DEFAULT_DIFFICULTY := preload("res://addons/bot_kit/presets/normal.tres")

## Off: it lets go of every key, forgets its enemy and its goal, and waits. Turn it off on the machines that do not
## decide the game (a network client) and while its character is dead.
@export var enabled := true:
	set(value):
		if enabled == value:
			return
		enabled = value
		if is_inside_tree() and not Engine.is_editor_hint():
			if value:
				_wake()
			else:
				_rest()
## The character it plays. Empty: its parent.
@export var body: Node3D:
	set(value):
		body = value
		_own_rids.clear()
		_rids_found = false
		update_configuration_warnings()
## What turns up and down to look (a head or a camera holder): its rotation.x is the pitch. Optional.
@export var head: Node3D
## How well it plays. Empty: the kit's normal (`presets/normal.tres`).
@export var difficulty: BotDifficulty:
	set(value):
		difficulty = value
		update_gizmos()
## What it fights with, each with its range and how its trigger works. Empty: one weapon on `fire_action`, any range,
## held in bursts.
@export var weapons: Array[BotWeapon] = []:
	set(value):
		weapons = value
		update_configuration_warnings()
## Its enemies are the nodes of this group (its own character never). Put your characters in it.
@export var target_group := &"bot_target":
	set(value):
		target_group = value
		update_configuration_warnings()
## On: it turns its character (yaw) and `head` (pitch) itself. Off: it only writes the look values (`yaw_value`,
## `pitch_value`) and your character applies them, as a network input does.
@export var turn_body := true

@export_group("Controls")
@export var move_left := &"ui_left"
@export var move_right := &"ui_right"
@export var move_forward := &"ui_up"
@export var move_back := &"ui_down"
@export var jump_action := &"ui_accept"
## Fires a weapon that names no action of its own.
@export var fire_action := &"fire"
## The values it writes for where it looks, in radians: `input.get_value(yaw_value)` (around +Y, 0 = facing -Z) and
## `input.get_value(pitch_value)` (positive = up).
@export var yaw_value := &"yaw"
@export var pitch_value := &"pitch"

@export_group("Eyes")
## Where it looks from, above its character's feet.
@export_range(0.0, 5.0, 0.01, "suffix:m") var eye_height_m := 1.6:
	set(value):
		eye_height_m = value
		update_gizmos()
## Where it aims on an enemy, above that enemy's feet (a weapon can aim elsewhere).
@export_range(0.0, 5.0, 0.01, "suffix:m") var aim_height_m := 1.1:
	set(value):
		aim_height_m = value
		update_gizmos()
## What blocks its sight and its line of fire (walls). Its own character never does.
@export_flags_3d_physics var sight_mask := 1
## It looks up and down at most this much.
@export_range(0.0, 89.0, 1.0, "suffix:°") var pitch_limit_deg := 80.0

@export_group("Fight")
## How much it wants to fight while it sees an enemy (against its roam and your modes).
@export_range(0.0, 10.0, 0.05) var fight_want := 1.0
## It changes its sideways step about this often.
@export_range(0.1, 5.0, 0.05, "suffix:s") var strafe_s := 0.9
## Each time it changes its step, the chance it also jumps.
@export_range(0.0, 1.0, 0.01) var jump_chance := 0.3

@export_group("Roam")
## How much it wants to roam (it always may; a mode that wants more wins).
@export_range(0.0, 10.0, 0.05) var roam_want := 0.1
## The navigation layers it walks.
@export_flags_3d_navigation var navigation_layers := 1
## A point is reached this close.
@export_range(0.05, 5.0, 0.05, "suffix:m") var arrive_m := 0.6
## A random point it walks to must be reachable to within this.
@export_range(0.1, 5.0, 0.1, "suffix:m") var reach_slack_m := 1.0
## Wanting to move but moving less than `stuck_m` in `stuck_s`: stuck.
@export_range(0.2, 10.0, 0.05, "suffix:s") var stuck_s := 1.2
@export_range(0.05, 5.0, 0.05, "suffix:m") var stuck_m := 0.5
## It asks for its path again this often (the level changes, its goal walks).
@export_range(0.1, 10.0, 0.1, "suffix:s") var repath_s := 1.0

@export_group("Thinking")
## How often it looks around and decides (its enemy, weapon, aim error, goal, mode). Bots start at different times.
@export_range(0.02, 2.0, 0.01, "suffix:s") var think_s := 0.2
## Its random numbers (0: different every run). The same seed plays the same way.
@export var random_seed := 0

## Draws, while the game runs, its enemy, path, goal and what it does.
@export var show_in_game := false

## The keys it presses: read it like `Input` from your character.
var input := BotInput.new()
## The enemy it fights, or null.
var target: Node3D
## Since it first saw `target`.
var seen_s := 0.0
## Where it saw an enemy last (Vector3.INF: nowhere). It walks there after a fight, by its difficulty's chase_chance.
var last_seen := Vector3.INF
## The weapon it uses, or null (no `weapons`, or none picked yet).
var weapon: BotWeapon
## What it does: FIGHT, ROAM or a BotMode child's name.
var mode := StringName()
## Where it walks now (Vector3.INF: nowhere).
var goal := Vector3.INF

## (node: Node3D) -> bool: whether a node of `target_group` is an enemy (a team, a dead body). Empty: all are.
var is_enemy: Callable = Callable()
## () -> Node3D: your own choice of enemy (another perception, a scripted fight), called on each think instead of its
## sight. Return null for none.
var choose_target: Callable = Callable()
## (weapon: BotWeapon, distance_m: float, score: float) -> float: your game's rules on a weapon's score (heat, ammo,
## an enemy's back). `score` is the weapon's own at that distance; return 0 for "not now".
var weapon_score: Callable = Callable()

var _rng := RandomNumberGenerator.new()
var _think_left_s := 0.0
var _thought := false
var _error := Vector2.ZERO
var _yaw := 0.0
var _pitch := 0.0
var _moved := false
var _taps: Array[StringName] = []
var _mode_node: BotMode
var _weapon_ok := true
var _firing := false
var _bursting := true
var _burst_left_s := 0.0
var _tap_left_s := 0.0
var _held_s := 0.0
var _hold_goal_s := 0.0
var _strafe := 1.0
var _strafe_left_s := 0.0
var _target_id := 0
var _target_last := Vector3.INF
var _target_velocity := Vector3.ZERO
var _goal_node: BotGoal3D
var _skipped: Dictionary[BotGoal3D, float] = {}
var _path := BotPath.new()
var _stuck_from := Vector3.INF
var _stuck_left_s := 0.0
var _own_rids: Array[RID] = []
var _rids_found := false
var _no_mesh_s := 0.0
var _warned_no_mesh := false
var _debug: BotDebug


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if body == null:
		body = get_parent() as Node3D
	process_physics_priority = THINK_PRIORITY
	if random_seed != 0:
		_rng.seed = random_seed
	else:
		_rng.randomize()
	_strafe = 1.0 if _rng.randf() < 0.5 else -1.0
	_think_left_s = _rng.randf() * think_s
	_read_look()


func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		input.release_all()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not enabled or not is_instance_valid(body):
		return
	for action in _taps:
		input.release(action)
	_taps.clear()
	if turn_body:
		_read_look()
	_follow_target(delta)
	_think_left_s -= delta
	if _think_left_s <= 0.0:
		_think_left_s = think_s
		_think()
	_moved = false
	_firing = false
	_run(delta)
	if not _moved:
		_release_move()
	_check_stuck(delta)
	_show(delta)


# --- What a mode uses ------------------------------------------------------------------------------------------------


## The difficulty it plays with (its own, or the kit's normal).
func current_difficulty() -> BotDifficulty:
	return difficulty if difficulty != null else DEFAULT_DIFFICULTY


## Where it looks from.
func eye_position() -> Vector3:
	return feet() + Vector3.UP * eye_height_m


## Where its character stands (in the editor, before it runs: its parent).
func feet() -> Vector3:
	if is_instance_valid(body):
		return body.global_position
	var parent := get_parent() as Node3D
	return parent.global_position if parent != null else global_position


## Whether nothing in `sight_mask` stands between its eyes and `point` (its own character never does; a hit on `of`,
## the node it looks at, counts as seen).
func can_see(point: Vector3, of: Node = null) -> bool:
	var query := PhysicsRayQueryParameters3D.create(eye_position(), point, sight_mask, _rids())
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider := hit.get("collider") as Node
	return of != null and collider != null and (collider == of or of.is_ancestor_of(collider) or collider.is_ancestor_of(of))


## Presses its movement keys to go along `direction` (world space; flat; length 1 = full speed, scaled by its
## difficulty's move_scale). Not called in a frame: it stands.
func move(direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z).limit_length(1.0)
	_moved = flat.length_squared() > 0.0001
	var local := Basis(Vector3.UP, _yaw).inverse() * flat * current_difficulty().move_scale
	_axis(move_left, move_right, local.x)
	_axis(move_forward, move_back, local.z)


## Walks the navigation mesh toward `point` and looks where it goes. False when it is there, or there is no way (or no
## navigation mesh): then it stands.
func walk_to(point: Vector3, delta: float) -> bool:
	var map := _map()
	if point == Vector3.INF or not BotPath.map_ready(map):
		_path.clear()
		return false
	var from := body.global_position
	var next := _path.next(map, from, point, navigation_layers, arrive_m, repath_s, delta)
	if next == Vector3.INF:
		return false
	var to := next - from
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return true
	look_toward(to, delta)
	move(to.normalized())
	return true


## Turns toward `direction` at its difficulty's speed, looking level.
func look_toward(direction: Vector3, delta: float) -> void:
	turn_to(BotAim.yaw_of(direction), 0.0, delta)


## Turns toward `yaw` and `pitch` (radians) at its difficulty's speed.
func turn_to(yaw: float, pitch: float, delta: float) -> void:
	var step := deg_to_rad(current_difficulty().turn_deg_s) * delta
	var limit := deg_to_rad(pitch_limit_deg)
	_yaw = BotAim.turn_yaw(_yaw, yaw, step)
	_pitch = move_toward(_pitch, clampf(pitch, -limit, limit), step)
	input.set_value(yaw_value, _yaw)
	input.set_value(pitch_value, _pitch)
	if turn_body:
		var rotation_now := body.global_rotation
		rotation_now.y = _yaw
		body.global_rotation = rotation_now
		if head != null:
			head.rotation.x = _pitch


## Aims at its enemy with its weapon (ahead of its walk, an arc for a throw, its aim error) and pulls the trigger
## when it reacted, the aim is inside its cone and the line is clear. What its fight does each frame.
func aim_and_fire(delta: float) -> void:
	if target == null:
		_release_fire()
		return
	var level := current_difficulty()
	var eye := eye_position()
	var height := aim_height_m if weapon == null or weapon.aim_height_m < 0.0 else weapon.aim_height_m
	var aim := target.global_position + Vector3.UP * height
	if weapon != null:
		aim = BotAim.lead(eye, aim, _target_velocity, weapon.projectile_speed_m_s, weapon.lead_max_s)
	var to := aim - eye
	var want_yaw := BotAim.yaw_of(to)
	var want_pitch := BotAim.pitch_of(to)
	var lobbed := weapon != null and weapon.lobs()
	if lobbed:
		want_pitch = BotAim.lob_pitch(weapon.projectile_speed_m_s, weapon.gravity_m_s2, Vector2(to.x, to.z).length(), to.y)
	turn_to(want_yaw + _error.x, want_pitch + _error.y, delta)
	var ready := seen_s >= level.reaction_s and _weapon_ok
	ready = ready and BotAim.degrees_off(_yaw, _pitch, want_yaw, want_pitch) <= level.fire_cone_deg
	if ready and weapon != null and weapon.fire_within_m > 0.0:
		ready = flat_distance_to(target.global_position) <= weapon.fire_within_m
	if ready and not lobbed:
		ready = can_see(aim, target)
	_pull_trigger(ready, delta)


## Holds `action` down (0 to 1).
func press(action: StringName, strength := 1.0) -> void:
	input.press(action, strength)


func release(action: StringName) -> void:
	input.release(action)


## Presses `action` for one physics frame.
func tap(action: StringName) -> void:
	input.press(action)
	_taps.append(action)


func jump() -> void:
	tap(jump_action)


## Lets go of every key.
func stop() -> void:
	input.release_all()
	_taps.clear()


## A random point of the navigation mesh it can walk to (Vector3.INF: none).
func random_reachable_point() -> Vector3:
	var map := _map()
	if not BotPath.map_ready(map):
		return Vector3.INF
	for i in 8:
		var point := NavigationServer3D.map_get_random_point(map, navigation_layers, false)
		if BotPath.reaches(map, body.global_position, point, navigation_layers, reach_slack_m):
			return point
	return Vector3.INF


## The flat distance from its character to `point`.
func flat_distance_to(point: Vector3) -> float:
	var to := point - body.global_position
	return Vector2(to.x, to.z).length()


## The path it walks now (for drawing).
func path_points() -> PackedVector3Array:
	return _path.points.slice(_path.index) if goal != Vector3.INF else PackedVector3Array()


# --- Thinking --------------------------------------------------------------------------------------------------------


func _think() -> void:
	_thought = true
	var seen := _pick_target()
	if seen != target:
		target = seen
		_target_id = seen.get_instance_id() if seen != null else 0
		seen_s = 0.0
		_bursting = true
		_burst_left_s = current_difficulty().burst_s
		_target_last = Vector3.INF
		_target_velocity = Vector3.ZERO
		target_changed.emit(target)
	var error := deg_to_rad(current_difficulty().aim_error_deg)
	_error = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * error
	if target != null:
		last_seen = target.global_position
		_choose_weapon(flat_distance_to(target.global_position))
	_choose_mode()


func _pick_target() -> Node3D:
	if choose_target.is_valid():
		var chosen := choose_target.call() as Node3D
		return chosen if is_instance_valid(chosen) and chosen.is_inside_tree() else null
	var best: Node3D = null
	var best_m := current_difficulty().sight_m
	var eye := eye_position()
	for node in get_tree().get_nodes_in_group(target_group):
		var other := node as Node3D
		if other == null or not _may_target(other):
			continue
		var distance := eye.distance_to(other.global_position)
		if distance < best_m and can_see(other.global_position + Vector3.UP * aim_height_m, other):
			best = other
			best_m = distance
	return best


func _may_target(other: Node3D) -> bool:
	if other == body or body.is_ancestor_of(other) or other.is_ancestor_of(body):
		return false
	if other.is_queued_for_deletion() or not other.is_visible_in_tree():
		return false
	return not is_enemy.is_valid() or bool(is_enemy.call(other))


## The weapon that suits `distance_m` best. A weapon with `chance` under 1 is switched to only that often; the one in
## hand keeps its score while in range.
func _choose_weapon(distance_m: float) -> void:
	if weapons.is_empty():
		_weapon_ok = true
		return
	var best: BotWeapon = null
	var best_score := 0.0
	for each in weapons:
		if each == null:
			continue
		var score := each.score_at(distance_m)
		if score > 0.0 and each != weapon and each.chance < 1.0 and _rng.randf() >= each.chance:
			score = 0.0
		if weapon_score.is_valid():
			score = float(weapon_score.call(each, distance_m, score))
		if score > best_score:
			best = each
			best_score = score
	_weapon_ok = best != null
	if best != null and best != weapon:
		_release_fire()
		weapon = best
		_held_s = 0.0
		_tap_left_s = 0.0
		weapon_changed.emit(best)


## The mode that wants it most; a tie keeps the one it runs.
func _choose_mode() -> void:
	var names: Array[StringName] = []
	var wants: Array[float] = []
	var nodes: Array[BotMode] = []
	if target != null:
		names.append(FIGHT)
		wants.append(fight_want)
		nodes.append(null)
	names.append(ROAM)
	wants.append(roam_want)
	nodes.append(null)
	for child in get_children():
		var each := child as BotMode
		if each != null and each.enabled:
			names.append(StringName(each.name))
			wants.append(each._want(self))
			nodes.append(each)
	var best := -1
	var current_want := -INF
	for i in names.size():
		if names[i] == mode:
			current_want = wants[i]
		if wants[i] > 0.0 and (best < 0 or wants[i] > wants[best]):
			best = i
	if best < 0 or names[best] == mode or wants[best] <= current_want:
		return
	_leave_mode()
	mode = names[best]
	_mode_node = nodes[best]
	if _mode_node != null:
		_mode_node._enter(self)
	else:
		goal = Vector3.INF
		_goal_node = null
	mode_changed.emit(mode)


func _leave_mode() -> void:
	if _mode_node != null and is_instance_valid(_mode_node):
		_mode_node._exit(self)
	_mode_node = null
	_release_fire()
	_path.clear()


func _run(delta: float) -> void:
	match mode:
		FIGHT:
			if target == null:
				_release_fire()
				return
			aim_and_fire(delta)
			_fight_move(delta)
		ROAM:
			_roam(delta)
		_:
			if _mode_node != null and is_instance_valid(_mode_node):
				_mode_node._tick(self, delta)
	_thought = false


# --- Fighting --------------------------------------------------------------------------------------------------------


func _pull_trigger(ready: bool, delta: float) -> void:
	var action := _fire_action()
	var trigger := BotWeapon.Trigger.HOLD if weapon == null else weapon.trigger
	var level := current_difficulty()
	match trigger:
		BotWeapon.Trigger.HOLD:
			if seen_s >= level.reaction_s:
				_burst_left_s -= delta
				if _burst_left_s <= 0.0:
					_bursting = not _bursting
					_burst_left_s = level.burst_s if _bursting else level.burst_pause_s
			_firing = ready and _bursting
			if _firing:
				input.press(action)
			else:
				input.release(action)
		BotWeapon.Trigger.TAP:
			_tap_left_s -= delta
			_firing = ready
			if ready and _tap_left_s <= 0.0:
				tap(action)
				_tap_left_s = weapon.tap_every_s
		BotWeapon.Trigger.CHARGE:
			if _held_s > 0.0:
				# Once it starts charging it lets go only at its goal: the shot leaves on the release.
				_held_s += delta
				_firing = true
				if _held_s >= _hold_goal_s:
					input.release(action)
					_held_s = 0.0
				else:
					input.press(action)
			elif ready:
				var quick := _rng.randf() < weapon.tap_chance
				_hold_goal_s = 0.05 if quick else _rng.randf_range(weapon.charge_s * 0.4, weapon.charge_s)
				_held_s = delta
				_firing = true
				input.press(action)
			else:
				input.release(action)


## Keeps its distance (its weapon's, or the difficulty's) and steps sideways, never off the navigation mesh.
func _fight_move(delta: float) -> void:
	_strafe_left_s -= delta
	if _strafe_left_s <= 0.0:
		_strafe_left_s = strafe_s * _rng.randf_range(0.6, 1.4)
		_strafe = -_strafe
		if _rng.randf() < jump_chance:
			jump()
	var to := target.global_position - body.global_position
	to.y = 0.0
	var distance := to.length()
	if distance < 0.01:
		return
	var toward := to / distance
	var keep := current_difficulty().keep_m if weapon == null or weapon.keep_m < 0.0 else weapon.keep_m
	var approach := toward * clampf((distance - keep) / maxf(keep, 0.5), -1.0, 1.0)
	var side := toward.cross(Vector3.UP) * _strafe
	var step := (side + approach).limit_length(1.0)
	if not _stays_on_mesh(step):
		_strafe = -_strafe
		step = (-side + approach).limit_length(1.0)
		if not _stays_on_mesh(step):
			step = approach if _stays_on_mesh(approach) else Vector3.ZERO
	move(step)


## Whether a step along `direction` stays on the navigation mesh (true without one).
func _stays_on_mesh(direction: Vector3) -> bool:
	var map := _map()
	if direction.length_squared() < 0.0001 or not BotPath.map_ready(map):
		return true
	var at := body.global_position
	if not NavigationServer3D.map_get_closest_point_owner(map, at).is_valid():
		return true
	var under := NavigationServer3D.map_get_closest_point(map, at)
	if Vector2(under.x - at.x, under.z - at.z).length() > 0.5 or absf(under.y - at.y) > 1.5:
		# Off the mesh already (on a crate, in the air): no step would stay on it.
		return true
	var probe := at + direction.normalized() * 0.8
	var closest := NavigationServer3D.map_get_closest_point(map, probe)
	return Vector2(closest.x - probe.x, closest.z - probe.z).length() < 0.35 and absf(closest.y - probe.y) < 1.5


func _fire_action() -> StringName:
	return weapon.fire_action if weapon != null and not weapon.fire_action.is_empty() else fire_action


func _release_fire() -> void:
	input.release(_fire_action())
	_held_s = 0.0
	_firing = false


# --- Roaming ---------------------------------------------------------------------------------------------------------


func _roam(delta: float) -> void:
	if _thought:
		_keep_goal_fresh()
	if goal == Vector3.INF:
		return
	if not walk_to(goal, delta):
		goal = Vector3.INF
		_goal_node = null


## On each think: a goal worth more than the one it walks to (or none) takes over.
func _keep_goal_fresh() -> void:
	if _goal_node != null and (not is_instance_valid(_goal_node) or not _goal_node.is_for(self, body.global_position)):
		goal = Vector3.INF
		_goal_node = null
	if _goal_node == null:
		var better := _best_goal()
		if better != null:
			_goal_node = better
			goal = better.global_position
			_path.clear()
			return
	if goal != Vector3.INF:
		return
	if last_seen != Vector3.INF:
		var at := last_seen
		last_seen = Vector3.INF
		if _rng.randf() < current_difficulty().chase_chance:
			goal = at
			return
	goal = random_reachable_point()
	if goal == Vector3.INF:
		_warn_no_mesh()


## The reachable BotGoal3D of the highest priority, the nearest of those.
func _best_goal() -> BotGoal3D:
	var now := Time.get_ticks_msec() / 1000.0
	var from := body.global_position
	var candidates: Array[BotGoal3D] = []
	for node in get_tree().get_nodes_in_group(BotGoal3D.GROUP):
		var each := node as BotGoal3D
		if each != null and _skipped.get(each, 0.0) <= now and each.is_for(self, from):
			candidates.append(each)
	candidates.sort_custom(func(a: BotGoal3D, b: BotGoal3D) -> bool:
		if not is_equal_approx(a.priority, b.priority):
			return a.priority > b.priority
		return from.distance_squared_to(a.global_position) < from.distance_squared_to(b.global_position)
	)
	var map := _map()
	for each in candidates:
		if not BotPath.map_ready(map) or BotPath.reaches(map, from, each.global_position, navigation_layers, reach_slack_m + arrive_m):
			return each
		_skipped[each] = now + SKIP_UNREACHABLE_S
	return null


# --- Inside ----------------------------------------------------------------------------------------------------------


func _wake() -> void:
	_think_left_s = 0.0
	_read_look()


func _rest() -> void:
	_leave_mode()
	mode = StringName()
	stop()
	if _target_id != 0:
		target = null
		_target_id = 0
		target_changed.emit(null)
	goal = Vector3.INF
	_goal_node = null
	last_seen = Vector3.INF
	_stuck_from = Vector3.INF
	_show(0.0)


func _read_look() -> void:
	if not is_instance_valid(body):
		return
	_yaw = body.global_rotation.y
	if head != null:
		_pitch = head.rotation.x


## The enemy's walk (from its positions: any node), and how long it has been seen.
func _follow_target(delta: float) -> void:
	if _target_id == 0:
		return
	# A freed node compares equal to null: its id tells it went.
	if not is_instance_id_valid(_target_id) or not target.is_inside_tree():
		target = null
		_target_id = 0
		target_changed.emit(null)
		return
	seen_s += delta
	var at := target.global_position
	if _target_last != Vector3.INF and delta > 0.0:
		_target_velocity = _target_velocity.lerp((at - _target_last) / delta, 0.5)
	_target_last = at


func _check_stuck(delta: float) -> void:
	if not _moved:
		_stuck_from = Vector3.INF
		return
	var at := body.global_position
	if _stuck_from == Vector3.INF:
		_stuck_from = at
		_stuck_left_s = stuck_s
		return
	_stuck_left_s -= delta
	if _stuck_left_s > 0.0:
		return
	if at.distance_to(_stuck_from) < stuck_m:
		jump()
		_strafe = -_strafe
		_path.clear()
		if mode == ROAM:
			if _goal_node != null:
				_skipped[_goal_node] = Time.get_ticks_msec() / 1000.0 + SKIP_UNREACHABLE_S
			_goal_node = null
			goal = random_reachable_point()
		stuck.emit()
	_stuck_from = at
	_stuck_left_s = stuck_s


func _axis(negative: StringName, positive: StringName, amount: float) -> void:
	if amount < -0.001:
		input.press(negative, -amount)
		input.release(positive)
	elif amount > 0.001:
		input.press(positive, amount)
		input.release(negative)
	else:
		input.release(negative)
		input.release(positive)


func _release_move() -> void:
	for action: StringName in [move_left, move_right, move_forward, move_back]:
		input.release(action)


func _map() -> RID:
	return get_world_3d().navigation_map if is_inside_tree() else RID()


func _rids() -> Array[RID]:
	if not _rids_found and is_instance_valid(body):
		_rids_found = true
		var stack: Array[Node] = [body]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			if node is CollisionObject3D:
				_own_rids.append((node as CollisionObject3D).get_rid())
			stack.append_array(node.get_children())
	return _own_rids


func _warn_no_mesh() -> void:
	if _warned_no_mesh or BotPath.map_ready(_map()):
		return
	_no_mesh_s += think_s
	if _no_mesh_s >= 2.0:
		_warned_no_mesh = true
		push_warning("Bot3D %s: no navigation mesh in this world, so it cannot roam. Add a NavigationRegion3D and bake it." % get_path())


func _show(_delta: float) -> void:
	if not show_in_game or not enabled:
		if _debug != null:
			_debug.queue_free()
			_debug = null
		return
	if _debug == null:
		_debug = BotDebug.new()
		add_child(_debug, false, Node.INTERNAL_MODE_BACK)
	_debug.show_bot(self, _firing)


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if body == null and not get_parent() is Node3D:
		out.append("Put the bot on your character (a child of its body), or set body.")
	if String(target_group).is_empty():
		out.append("target_group is empty: it sees no enemy (unless your game sets choose_target).")
	for i in weapons.size():
		var each := weapons[i]
		if each != null and each.min_m > each.max_m:
			out.append("Weapon %d: min_m is above max_m, so it is never picked." % i)
	return out
