@icon("res://addons/mp_kit/icons/mp_seat_bots.svg")
class_name MpSeatBots
extends Node

## A bot in every seat nobody plays. Put one in the world and set `bot_scene` (your bot: a Node that presses the seat's
## keys, or sends its moves). On the server, when the match starts and whenever a seat is abandoned, each vacant seat
## gets a bot; a player who takes the seat (a late player) or comes back gets it as the bot left it, and the bot goes; a
## closed seat (close_seat) never gets one again. Solo, every seat but the player's gets one.
## The kit hands your bot what it needs before adding it, if the bot has these properties: `slot` (int), `pawn` (the
## seat's pawn) and `input` (the pawn's MpInput, for MpInput.bot_press). With a pawn, the bot goes under it; in a game
## with no pawns (no Player Scene), under this node.

## A bot started playing `slot`.
signal bot_added(slot: int, bot: Node)
## The bot of `slot` left it (a player took the seat, it was closed, or this node left the match).
signal bot_removed(slot: int)

## Your bot.
@export var bot_scene: PackedScene
## The spawner of the seats' pawns. Empty: the world's MpWorld › Players (none: a game with no pawns).
@export var players: MpSlotSpawner
## Solo: bots in the other seats too (the MpWorld's `seats`).
@export var fill_solo := true

var _bots: Dictionary[int, Node] = {}
var _inputs: Dictionary[int, MpInput] = {}


func _ready() -> void:
	if MpKit.is_authority():
		_start.call_deferred()  # once the world's spawner is set up


func _start() -> void:
	if not is_inside_tree():
		return
	if players == null:
		var world := MpWorld.of(get_tree().root) if is_inside_tree() else null
		players = world.get_node_or_null(^"Players") as MpSlotSpawner if world else null
	if not MpKit.is_networked():
		if fill_solo:
			var world := MpWorld.of(get_tree().root)
			var seats: int = world.seats if world else 0
			for slot in range(1, seats + 1):
				if slot != MpKit.local_slot():
					_add(slot)
		return
	var gate := Mp.gate()
	gate.started.connect(func(_why: String) -> void: fill())
	gate.seat_abandoned.connect(func(slot: int, _why: String) -> void: _fill_one(slot))
	gate.joined_late.connect(remove)
	gate.seat_admitted.connect(func(slot: int, _back: bool) -> void: remove(slot))
	gate.seat_closed.connect(remove)
	if gate.phase == MpMatchGate.Phase.RUNNING:
		fill()


## Server: a bot in every vacant seat that has none (the match calls it at the start).
func fill() -> void:
	if not MpKit.is_authority() or not MpKit.is_networked():
		return
	for slot in Mp.gate().vacant_slots():
		_add(slot)


## The bot playing `slot`, or null.
func bot_of(slot: int) -> Node:
	var bot: Node = _bots.get(slot)
	return bot if is_instance_valid(bot) else null


## Server: the bot of `slot` leaves it (its pawn stays as it is).
func remove(slot: int) -> void:
	var bot := bot_of(slot)
	_bots.erase(slot)
	var input: MpInput = _inputs.get(slot)
	_inputs.erase(slot)
	if is_instance_valid(input):
		input.bot_release_all()
	if bot == null:
		return
	bot.queue_free()
	bot_removed.emit(slot)


func _fill_one(slot: int) -> void:
	if Mp.gate().vacant_slots().has(slot):
		_add(slot)


func _add(slot: int) -> void:
	if bot_scene == null or bot_of(slot) != null:
		return
	var pawn: Node = players.spawn_slot(slot) if players != null and players.pawn_scene != null else null
	var bot := bot_scene.instantiate()
	var input := _input_of(pawn)
	if "slot" in bot:
		bot.set(&"slot", slot)
	if pawn != null and "pawn" in bot:
		bot.set(&"pawn", pawn)
	if input != null and "input" in bot:
		bot.set(&"input", input)
	_bots[slot] = bot
	if input != null:
		_inputs[slot] = input
	(pawn if pawn != null else self).add_child(bot, true)
	bot_added.emit(slot, bot)


## The pawn's MpInput: marked %MpInput, or its first MpInput child.
func _input_of(pawn: Node) -> MpInput:
	if pawn == null:
		return null
	var marked := pawn.get_node_or_null(^"%MpInput") as MpInput
	if marked != null:
		return marked
	for child in pawn.get_children():
		if child is MpInput:
			return child
	return null


func _exit_tree() -> void:
	for slot: int in _bots.keys():
		remove(slot)
