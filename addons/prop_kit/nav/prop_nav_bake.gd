@tool
class_name PropNavBake
extends Resource

## A navmesh baked in zones, saved («Bake» on PropNavZones3D / PropNavZones2D) so a game loads it
## instead of baking: one piece per zone, the grid it was cut on, and the fingerprint of the
## obstructions it was baked with. A game whose props differ from these (a match without its
## forest) finds it stale and bakes again.

## Side of a zone, and the grid's area (world units).
@export var zone_size := 0.0
@export var area := Rect2()
@export var border := 0.0
## One NavigationMesh (3D) or NavigationPolygon (2D) per zone, row by row.
@export var pieces: Array[Resource] = []
## PropObstructions.fingerprint of the props it was baked with, and of the settings that shape
## them (sides, merge gap, carve).
@export var fingerprint := 0
