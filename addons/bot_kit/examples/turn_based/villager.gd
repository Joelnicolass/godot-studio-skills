extends Node

## The villager the brain plays, one turn at a time: its energy, its wood and its house, and what each choice does to
## them. Its BotBrain child thinks about it (the brain's parent) and the villager does what the brain chose.

## It took a turn: did `choice`.
signal acted(choice: BotChoice)

const MAX_ENERGY := 10
## Gathering costs this much energy and brings this much wood.
const GATHER_ENERGY := 2
const GATHER_WOOD := 2
## Building a part of the house costs this much energy and wood.
const BUILD_ENERGY := 3
const BUILD_WOOD := 3
## Resting gives this much energy back.
const REST_ENERGY := 4
## Parts of a whole house.
const HOUSE_PARTS := 5

var energy := MAX_ENERGY
var wood := 0
var house := 0
var turns := 0

@onready var brain: BotBrain = $BotBrain


func _ready() -> void:
	brain.chose.connect(_do)


func is_done() -> bool:
	return house >= HOUSE_PARTS


## Back to the first turn. The brain forgets what it did and starts its own rng again from its seed: the same turns.
func restart() -> void:
	energy = MAX_ENERGY
	wood = 0
	house = 0
	turns = 0
	brain.current = null
	brain.rng_seed = brain.rng_seed


func _do(choice: BotChoice) -> void:
	turns += 1
	match choice.id:
		&"Gather":
			energy -= GATHER_ENERGY
			wood += GATHER_WOOD
		&"Build":
			energy -= BUILD_ENERGY
			wood -= BUILD_WOOD
			house += 1
		&"Rest":
			energy = mini(energy + REST_ENERGY, MAX_ENERGY)
	acted.emit(choice)
