class_name SpillWound
extends RefCounted

## The one value a SpillSource3D syncs, packed in a Vector4: xyz is where the last spray came from
## (INF: from nowhere, it flies any way), and w counts its sprays and deaths and flags a heavy last
## spray (sprays * 8 + deaths % 4 * 2 + heavy). Every machine compares the counts with what it
## already showed, so a value seen late plays nothing, and two machines that see the same value
## play the same spills.

const SPRAY_STEP := 8
const DEATH_STEP := 2
const DEATHS_KEPT := 4


static func pack(from: Vector3, sprays: int, deaths: int, heavy: bool) -> Vector4:
	return Vector4(from.x, from.y, from.z, float(sprays * SPRAY_STEP + posmod(deaths, DEATHS_KEPT) * DEATH_STEP + (1 if heavy else 0)))


## Where the last spray came from; not finite when it came from nowhere.
static func from_of(wound: Vector4) -> Vector3:
	return Vector3(wound.x, wound.y, wound.z)


## How many sprays (0 = none yet).
static func sprays_of(wound: Vector4) -> int:
	return roundi(wound.w) / SPRAY_STEP


## How many deaths, counted 0 to 3 and over again (it only tells a new death).
static func deaths_of(wound: Vector4) -> int:
	return (roundi(wound.w) / DEATH_STEP) % DEATHS_KEPT


## True if the last spray was heavy.
static func is_heavy(wound: Vector4) -> bool:
	return roundi(wound.w) % 2 == 1
