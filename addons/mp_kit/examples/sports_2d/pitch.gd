extends Node2D

## A pick-up match, two against two. MpWorld seats four players (slots 1 and 3 home, on the left; 2 and 4 away) and
## the match starts once all four are in: MpFlow.start_seats is 0 (its default, every seat) and MpMatch holds the world
## until then. The ball is the server's; a goal scores in MpState and puts everybody back for a kickoff.
## Keys: arrows run, Space slides (it wins the ball from a carrier it reaches), Enter kicks the ball it carries.

const Ball := preload("res://addons/mp_kit/examples/sports_2d/ball.gd")
const Player := preload("res://addons/mp_kit/examples/sports_2d/player.gd")

@onready var ball: Ball = $Ball
@onready var spawn_points: Node2D = $MpWorld/SpawnPoints
@onready var score: Label = $MpWorld/Hud/Score


func _ready() -> void:
	ball.scored.connect(_on_scored)
	var state := MpState.of(self)
	state.watch(&"home", func(_value: Variant) -> void: _show_score(), 0)
	state.watch(&"away", func(_value: Variant) -> void: _show_score(), 0)


func _show_score() -> void:
	var state := MpState.of(self)
	score.text = "%d - %d" % [int(state.get_value(&"home", 0)), int(state.get_value(&"away", 0))]


## Server: a goal. The score, and a kickoff.
func _on_scored(team: int) -> void:
	MpState.of(self).add(&"home" if team == 0 else &"away")
	ball.reset()
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		var player := node as Player
		var marker := spawn_points.get_child((player.net.owner_slot - 1) % spawn_points.get_child_count()) as Node2D
		player.reset_to(marker.position)


func _draw() -> void:
	var field := Ball.FIELD
	draw_rect(field, Color("2f6b3a"))
	var line := Color(1, 1, 1, 0.6)
	draw_rect(field, line, false, 2.0)
	draw_line(Vector2(field.get_center().x, field.position.y), Vector2(field.get_center().x, field.end.y), line, 2.0)
	draw_arc(field.get_center(), 60.0, 0.0, TAU, 48, line, 2.0)
	for x: float in [field.position.x, field.end.x]:
		var mouth := Rect2(x - 12.0, field.get_center().y - Ball.GOAL_HALF, 12.0, Ball.GOAL_HALF * 2.0)
		if x > field.get_center().x:
			mouth.position.x = x
		draw_rect(mouth, Color(1, 1, 1, 0.85))
