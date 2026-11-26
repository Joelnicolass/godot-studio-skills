extends Control

## BotKit's turn-based example: a villager builds a house one turn at a time. Its BotBrain weighs three BotOption
## children (gather, build, rest) from the villager's energy and wood, and the villager does the one that wins. The
## bars are the scores the brain weighed on the last turn.
## Space: one turn. A: turns on their own (auto_think). N: noise on and off. R: again (same seed, same turns).

const Villager := preload("res://addons/bot_kit/examples/turn_based/villager.gd")

## N turns the brain's noise to this, and back to 0.
const NOISE := 0.3
## Bar length per point of score.
const BAR_PX := 70.0
const BAR_ROW_PX := 34.0
const LOG_LINES := 8

var _log := PackedStringArray()

@onready var villager: Villager = %Villager
@onready var brain: BotBrain = %BotBrain
@onready var help: Label = %Help
@onready var state: Label = %State
@onready var scores: Control = %Scores
@onready var turns_log: Label = %Log


func _ready() -> void:
	villager.acted.connect(_on_acted)
	scores.draw.connect(_draw_scores)
	_show()


## One turn: the brain thinks about its parent, the villager, which does what it chose.
func turn() -> void:
	if not villager.is_done():
		brain.think()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE:
			turn()
		KEY_A:
			brain.auto_think = not brain.auto_think and not villager.is_done()
		KEY_N:
			brain.noise = 0.0 if brain.noise > 0.0 else NOISE
		KEY_R:
			villager.restart()
			brain.last_choices.clear()
			_log.clear()
		_:
			return
	_show()


func _on_acted(choice: BotChoice) -> void:
	_log.append(
		(
			"%d. %s   energy %d, wood %d, house %d/%d"
			% [villager.turns, choice.id, villager.energy, villager.wood, villager.house, Villager.HOUSE_PARTS]
		)
	)
	if _log.size() > LOG_LINES:
		_log.remove_at(0)
	if villager.is_done():
		brain.auto_think = false
	_show()


func _show() -> void:
	help.text = (
		"Space: one turn   A: turns on their own (%s)   N: noise %d %%   R: again"
		% ["on" if brain.auto_think else "off", roundi(brain.noise * 100.0)]
	)
	if villager.is_done():
		state.text = "The house is built, in %d turns. R: again." % villager.turns
	else:
		state.text = (
			"Turn %d   energy %d/%d   wood %d   house %d/%d"
			% [
				villager.turns + 1,
				villager.energy,
				Villager.MAX_ENERGY,
				villager.wood,
				villager.house,
				Villager.HOUSE_PARTS
			]
		)
	turns_log.text = "\n".join(_log)
	scores.queue_redraw()


func _draw_scores() -> void:
	var font := get_theme_default_font()
	var font_size := get_theme_default_font_size()
	var dim := Color(0.6, 0.64, 0.72)
	if brain.last_choices.is_empty():
		var hint := "Space: the brain weighs its options."
		scores.draw_string(font, Vector2(0, font_size), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, dim)
		return
	var title := "What it weighed on turn %d:" % villager.turns
	scores.draw_string(font, Vector2(0, font_size), title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, dim)
	for i in brain.last_choices.size():
		var choice := brain.last_choices[i]
		var top := (i + 1) * BAR_ROW_PX
		var baseline := top + font_size + 4.0
		var won := choice == brain.current
		var color := Color(1.0, 0.85, 0.35) if won else Color(0.65, 0.7, 0.8)
		scores.draw_string(
			font, Vector2(0, baseline), String(choice.id), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color
		)
		var length := maxf(choice.score, 0.0) * BAR_PX
		scores.draw_rect(Rect2(110, top + 6, length, BAR_ROW_PX - 14), color)
		var note := "%.2f%s" % [choice.score, "   chosen" if won else ""]
		scores.draw_string(font, Vector2(120 + length, baseline), note, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
