class_name PawnCatalog
extends Resource
## The pawn types in slot order: slot 1 takes the first, and after the last it starts over.

## One file per type.
@export var types: Array[PawnType] = []


func type_for_slot(slot: int) -> PawnType:
	if types.is_empty():
		return null
	return types[(maxi(slot, 1) - 1) % types.size()]
