extends "res://addons/spill_kit/tests/spill_test.gd"

## SpillRules and SpillWound: when a hit spills, and the one value that travels.

const K := SpillRules.Kind


func test_heavy_at_its_share_or_by_the_blow() -> void:
	check(SpillRules.kind_for(0.4, 0.4, 0.0, 0.0, 0.4, 0.25, 0.05) == K.HEAVY, "40 % of the max HP is heavy")
	check(SpillRules.kind_for(0.39, 0.39, 9.0, 9.0, 0.4, 0.25, 0.05) == K.LIGHT, "39 % is light")
	check(SpillRules.kind_for(0.01, 0.01, 0.0, 0.0, 0.4, 0.25, 0.05, true) == K.HEAVY, "a heavy blow is heavy whatever its share, even right after a spray")
	check(SpillRules.kind_for(0.0, 0.0, 9.0, 9.0, 0.4, 0.25, 0.05, true) == K.NONE, "no damage, no spill")


func test_light_sprays_keep_apart_and_small_hits_add_up() -> void:
	check(SpillRules.kind_for(0.1, 0.1, 0.1, 0.1, 0.4, 0.25, 0.05) == K.NONE, "too soon after a spray")
	check(SpillRules.kind_for(0.1, 0.1, 0.3, 0.1, 0.4, 0.25, 0.05) == K.LIGHT, "past every_s with enough lost")
	check(SpillRules.kind_for(0.01, 0.03, 0.3, 0.1, 0.4, 0.25, 0.05) == K.NONE, "a tiny hit in a stream waits until they add up")
	check(SpillRules.kind_for(0.01, 0.05, 0.3, 0.1, 0.4, 0.25, 0.05) == K.LIGHT, "the stream adds up to min_lost")
	check(SpillRules.kind_for(0.01, 0.01, 0.3, 0.3, 0.4, 0.25, 0.05) == K.LIGHT, "a lone graze still shows")


func test_the_wound_packs_its_counts() -> void:
	var w := SpillWound.pack(Vector3(1, 2, 3), 5, 2, true)
	check(SpillWound.sprays_of(w) == 5, "5 sprays")
	check(SpillWound.deaths_of(w) == 2, "2 deaths")
	check(SpillWound.is_heavy(w), "heavy")
	check(SpillWound.from_of(w) == Vector3(1, 2, 3), "where it came from")
	var light := SpillWound.pack(Vector3.ZERO, 6, 2, false)
	check(not SpillWound.is_heavy(light) and SpillWound.sprays_of(light) == 6, "light, 6")
	check(SpillWound.deaths_of(SpillWound.pack(Vector3.ZERO, 0, 4, false)) == 0, "deaths count 0 to 3 and over")
	check(SpillWound.deaths_of(SpillWound.pack(Vector3.ZERO, 0, 5, false)) == 1, "the fifth death reads as 1, a new one after 0")
	var nowhere := SpillWound.pack(Vector3.INF, 1, 0, false)
	check(not SpillWound.from_of(nowhere).is_finite() and SpillWound.sprays_of(nowhere) == 1, "from nowhere stays not finite")
	check(SpillWound.sprays_of(SpillWound.pack(Vector3.ZERO, 1000000, 3, true)) == 1000000, "a million sprays still count (float precision)")
	check(SpillWound.sprays_of(Vector4.ZERO) == 0 and SpillWound.deaths_of(Vector4.ZERO) == 0, "zero: nothing yet")


func test_the_dedicated_server_is_told() -> void:
	check(SpillPool3D.is_server(true, "macOS", false), "an export with the dedicated_server feature")
	check(SpillPool3D.is_server(false, "headless", false), "an exported game run headless")
	check(not SpillPool3D.is_server(false, "headless", true), "the editor run headless (these tests) still draws")
	check(not SpillPool3D.is_server(false, "Windows", false), "a game with a screen draws")
	check(SpillPool3D.draws_here(), "this run draws")
