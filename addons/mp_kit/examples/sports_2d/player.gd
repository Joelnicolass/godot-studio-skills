extends CharacterBody2D

## A player of the pick-up match, written like a single-player script. Arrows run, Space slides, Enter kicks the ball
## it carries. Running and sliding are predicted (MpActor › Prediction): its own screen moves it at once, the server
## runs the same mp_move with the same keys, and what mp_move reads travels with its pose (MpActor › Sync › sync_extra:
## velocity, facing, slide_ticks, stun_ticks), so a slide is never corrected. What only the server can decide (a tackle
## that wins the ball, the knock) it writes into those same values, and its own screen replays from them.

const RUN := 230.0
const ACCEL := 1400.0
const BRAKE := 900.0
const SLIDE_SPEED := 520.0
const SLIDE_TICKS := 18
const SLIDE_BRAKE := 650.0
## After a slide it gets up before it runs again.
const RECOVER_TICKS := 12
## A tackled player is knocked away and down this long.
const KNOCK_SPEED := 260.0
const KNOCKED_TICKS := 40
## A slide wins the ball from a carrier this close (where the slider SAW it: lag compensation, in ball.gd).
const TACKLE_REACH := 30.0
const KICK_SPEED := 620.0
const TEAM_COLORS: Array[Color] = [Color("e05d5d"), Color("5d9de0")]
const GROUP := &"sports_player"

## Synced with the pose (sync_extra): mp_move reads them, so the reconciliation starts from the server's.
var facing := Vector2.RIGHT
var slide_ticks := 0
var stun_ticks := 0

@onready var net: MpActor = $MpActor
@onready var input: MpInput = $MpInput


func _ready() -> void:
	add_to_group(GROUP)
	$Body.color = TEAM_COLORS[team()]
	$Tag.text = "P%d" % net.owner_slot


## Home (0: slots 1 and 3, the left goal) or away (1: slots 2 and 4).
func team() -> int:
	return (net.owner_slot - 1) % 2 if net.owner_slot > 0 else 0


## Movement only: the server runs it once per frame of keys, the owner at once and again when it reconciles.
func mp_move(keys: MpInput, delta: float) -> void:
	if slide_ticks > 0:
		slide_ticks -= 1
		velocity = velocity.move_toward(Vector2.ZERO, SLIDE_BRAKE * delta)
		if slide_ticks == 0:
			stun_ticks = RECOVER_TICKS
	elif stun_ticks > 0:
		stun_ticks -= 1
		velocity = velocity.move_toward(Vector2.ZERO, BRAKE * delta)
	else:
		var move := keys.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
		if move.length() > 0.1:
			facing = move.normalized()
		velocity = velocity.move_toward(move * RUN, ACCEL * delta)
		if keys.is_action_just_pressed(&"ui_select"):
			slide_ticks = SLIDE_TICKS
			velocity = facing * SLIDE_SPEED
	move_and_slide()


## Server and solo: the rules. Enter kicks the ball it carries (who has the ball, and a tackle, are the ball's rules).
func _physics_process(_delta: float) -> void:
	if not net.is_authority():
		return
	var ball: Node2D = get_tree().get_first_node_in_group(&"sports_ball")
	if ball != null and ball.holder == net.owner_slot and input.is_action_just_pressed(&"ui_accept"):
		ball.kick(facing * KICK_SPEED, net.owner_slot)


## Server: knocked away from `from` and down for a while. Written into the synced values mp_move reads: this player's
## own screen replays from them (a correction it could not predict, smoothed).
func knock(from: Vector2) -> void:
	slide_ticks = 0
	stun_ticks = KNOCKED_TICKS
	velocity = (position - from).normalized() * KNOCK_SPEED


## Server: back to `at` for a kickoff (a jump, not a step to smooth).
func reset_to(at: Vector2) -> void:
	position = at
	velocity = Vector2.ZERO
	slide_ticks = 0
	stun_ticks = 0
	net.snap()


func _process(_delta: float) -> void:
	$Facing.rotation = facing.angle()
	$Body.rotation = facing.angle() + PI / 2.0 if slide_ticks > 0 or stun_ticks > RECOVER_TICKS else 0.0
