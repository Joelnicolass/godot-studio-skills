class_name SpillRules
extends RefCounted

## When a hit on a body spills and how much: nothing, a light spray or a heavy one. Pure: the shares
## and the times come in, SpillSource3D keeps them.

enum Kind {
	NONE,
	LIGHT,
	HEAVY,
}


## How a hit spills. [param drop_share]: this hit's damage over the body's max HP;
## [param lost_share]: the damage not shown yet (this hit's too), over the max HP;
## [param since_spray_s]: the time since the last spray; [param since_hit_s]: since the hit before.
## A hit that takes at least [param heavy_from], or a [param heavy_blow] (a finisher, whatever its
## share), is HEAVY. Otherwise sprays keep at least [param every_s] apart; past that, a hit spills
## (LIGHT) once the damage not shown reaches [param min_lost], or when it comes alone (no other hit
## for every_s): a stream of tiny hits adds up, and a lone graze still shows.
static func kind_for(
	drop_share: float,
	lost_share: float,
	since_spray_s: float,
	since_hit_s: float,
	heavy_from: float,
	every_s: float,
	min_lost: float,
	heavy_blow := false
) -> Kind:
	if drop_share <= 0.0:
		return Kind.NONE
	if heavy_blow or drop_share >= heavy_from:
		return Kind.HEAVY
	if since_spray_s < every_s:
		return Kind.NONE
	if lost_share >= min_lost or since_hit_s >= every_s:
		return Kind.LIGHT
	return Kind.NONE
