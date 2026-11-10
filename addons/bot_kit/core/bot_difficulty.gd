@tool
class_name BotDifficulty
extends Resource

## How well a Bot3D plays: how far it sees, how fast it reacts and turns, how well it aims, how it fires and how it
## walks. Three come with the kit (`presets/easy.tres`, `normal.tres`, `hard.tres`); a bot without one plays normal.
## Give every bot of a level the same one, or switch them all at once from your menu.
## A preset is shared: to tune one bot only, make its difficulty unique in the inspector (or duplicate the file).

## The name your menu shows.
@export var display_name := ""

@export_group("Seeing")
## Enemies farther than this go unseen.
@export_range(1.0, 300.0, 0.5, "suffix:m") var sight_m := 35.0
## From first seeing an enemy to its first shot.
@export_range(0.0, 5.0, 0.01, "suffix:s") var reaction_s := 0.8

@export_group("Aim")
## How fast it turns toward where it aims.
@export_range(10.0, 1800.0, 1.0, "suffix:°/s") var turn_deg_s := 150.0
## Its largest aim error, picked again on every think.
@export_range(0.0, 45.0, 0.1, "suffix:°") var aim_error_deg := 9.0
## It fires while its aim is this close to where it wants to aim.
@export_range(0.5, 90.0, 0.5, "suffix:°") var fire_cone_deg := 6.0

@export_group("Firing")
## A held trigger stays down this long…
@export_range(0.05, 10.0, 0.05, "suffix:s") var burst_s := 0.8
## …then up this long before the next burst.
@export_range(0.0, 10.0, 0.05, "suffix:s") var burst_pause_s := 0.6

@export_group("Moving")
## How hard it presses its movement keys (1: like a person at full speed).
@export_range(0.1, 1.0, 0.01) var move_scale := 0.78
## In a fight it keeps about this far from its enemy (a weapon can ask for its own distance).
@export_range(0.5, 60.0, 0.5, "suffix:m") var keep_m := 10.0
## Having lost sight of its enemy, how often it walks to where it saw it last.
@export_range(0.0, 1.0, 0.01) var chase_chance := 0.6
## How far it walks for a goal: each BotGoal3D's reach times this (0: it never walks to one).
@export_range(0.0, 5.0, 0.05) var goal_reach_scale := 1.0


## The share of a fight its held trigger is down (0 to 1).
func trigger_share() -> float:
	return burst_s / maxf(burst_s + burst_pause_s, 0.001)
