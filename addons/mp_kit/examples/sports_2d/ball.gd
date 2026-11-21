extends Node2D

## The ball: the server's (MpActor, owner 0). The server moves it, sticks it to its carrier's feet, lets a player take it
## when it rolls close, gives it away to a slide that reaches its carrier (where the slider SAW the carrier: lag
## compensation), bounces it off the touchlines and says when it goes in a goal. Every peer draws it smoothly,
## a little in the past (MpActor › Smoothing BUFFERED), like any thing of the server. The carrier's own screen draws it
## at its own predicted feet instead, so dribbling never lags behind its legs.

## A team scored (0: home, in the right goal; 1: away, in the left one). Server.
signal scored(team: int)

const FRICTION := 420.0
## A tackle pokes it away this fast.
const POKE_SPEED := 250.0
const DRIBBLE := 20.0
const PICK_RADIUS := 22.0
## A player who just kicked it cannot take it back at once.
const KICK_COOLDOWN_S := 0.3
## The field, and each goal's mouth (half its height) on the goal lines.
const FIELD := Rect2(40, 40, 880, 460)
const GOAL_HALF := 70.0

const Player := preload("res://addons/mp_kit/examples/sports_2d/player.gd")

## The player slot that carries it (0: nobody). Synced (sync_extra): every screen knows who has it.
var holder := 0
var velocity := Vector2.ZERO
var _kicked_by := 0
var _kicked_s := 0.0

@onready var net: MpActor = $MpActor


func _ready() -> void:
	add_to_group(&"sports_ball")
	## After the kit draws the proxies (10000): the carrier's own screen moves the drawing to its own feet.
	process_priority = 10001


## Server: kicked by `slot` at `speed` (a pass, a shot, or a ball poked away by a tackle).
func kick(speed: Vector2, slot: int) -> void:
	holder = 0
	velocity = speed
	_kicked_by = slot
	_kicked_s = KICK_COOLDOWN_S


## Server: to the center spot, nobody's.
func reset() -> void:
	holder = 0
	velocity = Vector2.ZERO
	position = FIELD.get_center()
	net.snap()


## The player who carries it, or null (on every screen: found by its slot).
func carrier() -> Player:
	if holder <= 0:
		return null
	for player in get_tree().get_nodes_in_group(Player.GROUP):
		if MpActor.of(player).owner_slot == holder:
			return player as Player
	return null


func _physics_process(delta: float) -> void:
	if not net.is_authority():
		return
	_kicked_s -= delta
	var feet := carrier()
	if feet != null:
		var tackler := _tackled_by(feet)
		if tackler == null:
			position = feet.position + feet.facing * DRIBBLE
			velocity = Vector2.ZERO
			return
		kick((feet.position - tackler.position).normalized() * POKE_SPEED, tackler.net.owner_slot)
		feet.knock(tackler.position)
	holder = 0
	velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	position += velocity * delta
	if _in_goal():
		return
	_bounce()
	_pick_up()


## A sliding opponent of `feet` that reaches it where it SAW it (its own view of the past: MpActor.seen_position_of), so
## a slide that touched on the slider's screen wins the ball, whatever its ping.
func _tackled_by(feet: Player) -> Player:
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		var player := node as Player
		if player.slide_ticks <= 0 or player.team() == feet.team():
			continue
		var seen: Vector2 = player.net.seen_position_of(feet)
		if seen.distance_to(player.position) <= Player.TACKLE_REACH:
			return player
	return null


func _in_goal() -> bool:
	if absf(position.y - FIELD.get_center().y) > GOAL_HALF:
		return false
	if position.x < FIELD.position.x:
		scored.emit(1)
		return true
	if position.x > FIELD.end.x:
		scored.emit(0)
		return true
	return false


func _bounce() -> void:
	if position.y < FIELD.position.y or position.y > FIELD.end.y:
		velocity.y = -velocity.y
		position.y = clampf(position.y, FIELD.position.y, FIELD.end.y)
	if position.x < FIELD.position.x or position.x > FIELD.end.x:
		velocity.x = -velocity.x
		position.x = clampf(position.x, FIELD.position.x, FIELD.end.x)


func _pick_up() -> void:
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		var player := node as Player
		var slot := player.net.owner_slot
		if player.stun_ticks > 0 or (slot == _kicked_by and _kicked_s > 0.0):
			continue
		if player.position.distance_to(position) <= PICK_RADIUS:
			holder = slot
			return


## Every frame, after the kit drew the proxy: its carrier's own screen draws it at its own (predicted) feet.
func _process(_delta: float) -> void:
	var mine := holder > 0 and holder == MpKit.local_slot() and not net.is_authority()
	var feet := carrier() if mine else null
	if feet != null:
		$Body.global_position = feet.global_position + feet.facing * DRIBBLE
	else:
		$Body.position = Vector2.ZERO
