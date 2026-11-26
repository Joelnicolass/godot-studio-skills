extends "res://addons/unlock_kit/tests/unlock_test.gd"

## UnlockKit stands alone (CLAUDE rule 1): no file of the addon names another kit.

const ROOT := "res://addons/unlock_kit"
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
	"gesture_kit",
	"command_kit",
	"turn_kit",
	"grid_kit",
	"wallet_kit",
	"stat_kit",
	"deck_kit",
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
	"CommandLog",
	"GameCommands",
	"Purse",
	"Wallet",
	"WalletSubstitute",
	"StatSheet",
	"StatModifier",
	"StatBlock",
	"CardData",
	"CardStack",
	"CardPile",
	"Deck",
	"HandView",
	"DieFace",
	"DieData",
	"DiceRoll",
	"DiceRoller",
	"DiceTray3D",
	"CellFog",
	"GridFog",
	"GestureReader",
	"GestureArea"
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
	check(offenders.is_empty(), "UnlockKit names no other kit: %s" % [offenders])


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
		if file.ends_with(".gd") or file.ends_with(".tscn"):
			found.append(dir_path.path_join(file))
	return found
