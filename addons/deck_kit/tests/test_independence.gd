extends "res://addons/deck_kit/tests/deck_test.gd"

## DeckKit stands alone (CLAUDE rule 1): no file of the addon names another kit. And it never draws a random number
## from the global generator: every shuffle takes a RandomNumberGenerator.

const ROOT := "res://addons/deck_kit"
const OTHER_KITS: Array[String] = [
	"mp_kit",
	"fsm_kit",
	"rts_kit",
	"bot_kit",
	"prop_kit",
	"grass_kit",
	"plat_kit",
	"perception_kit",
	"spill_kit",
	"agent_kit",
	"command_kit",
	"turn_kit",
	"grid_kit",
	"wallet_kit",
	"unlock_kit",
	"stat_kit",
	"dice_kit",
	"Mp",
	"Fsm",
	"Rts",
	"Bot3D",
	"Prop",
	"Grass",
	"Perception",
	"Spill",
	"TurnCycle",
	"TurnClock",
	"TurnSeat",
	"CellGrid",
	"HexGrid",
	"SquareGrid",
	"GridLayout",
	"GridBoard",
	"GridView3D",
	"GridCursor",
	"CellFog",
	"GridFog",
	"CommandLog",
	"GameCommands",
	"Purse",
	"Wallet",
	"WalletSubstitute",
	"UnlockGraph",
	"UnlockTree",
	"UnlockEntry",
	"UnlockTreeView",
	"StatSheet",
	"StatModifier",
	"StatBlock",
	"DieFace",
	"DieData",
	"DiceRoll",
	"DiceRoller",
	"DiceTray3D"
]


func test_no_other_kit() -> void:
	var offenders: Array[String] = []
	for path in _scripts(ROOT):
		if path.ends_with("test_independence.gd"):
			continue
		var text := FileAccess.get_file_as_string(path)
		for name in OTHER_KITS:
			var pattern := "addons/%s" % name if name.ends_with("_kit") else name
			if _mentions(text, pattern):
				offenders.append("%s names %s" % [path.get_file(), name])
	check(offenders.is_empty(), "DeckKit names no other kit: %s" % [offenders])


# The global random calls, and Array.shuffle() / pick_random() (they take no arguments; CardStack.shuffle(rng) does).
func test_no_global_random() -> void:
	var globals := "randi|randf|randfn|randi_range|randf_range|randomize|seed|rand_from_seed"
	var calls := RegEx.create_from_string("(?<![\\w.])(%s)\\s*\\(|\\.(shuffle|pick_random)\\s*\\(\\s*\\)" % globals)
	var offenders: Array[String] = []
	for path in _scripts(ROOT):
		if path.begins_with(ROOT.path_join("tests")) or not path.ends_with(".gd"):
			continue
		var number := 0
		for line in FileAccess.get_file_as_string(path).split("\n"):
			number += 1
			var code := line.get_slice("#", 0)
			if calls.search(code) != null:
				offenders.append("%s:%d" % [path.get_file(), number])
	check(offenders.is_empty(), "no global random call in the product: %s" % [offenders])
	check(calls.search("\tlist.shuffle()") != null and calls.search("\tvar x := randi()") != null, "the pattern bites")
	check(calls.search("\tstack.shuffle(rng)") == null and calls.search("\trng.randi_range(0, i)") == null, "not these")


func _mentions(text: String, pattern: String) -> bool:
	if pattern.begins_with("addons/"):
		return text.contains(pattern)
	var regex := RegEx.create_from_string("\\b%s[A-Z]?[A-Za-z0-9]*\\b" % pattern)
	for found in regex.search_all(text):
		var word := found.get_string()
		if (
			word == pattern
			or (
				word.length() > pattern.length()
				and word[pattern.length()] == word[pattern.length()].to_upper()
				and word.begins_with(pattern)
			)
		):
			return true
	return false


func _scripts(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	for sub in DirAccess.get_directories_at(dir_path):
		found.append_array(_scripts(dir_path.path_join(sub)))
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd") or file.ends_with(".tscn") or file.ends_with(".tres"):
			found.append(dir_path.path_join(file))
	return found
