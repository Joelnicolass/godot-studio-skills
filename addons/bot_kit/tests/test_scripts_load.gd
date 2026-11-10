extends "res://addons/bot_kit/tests/bot_test.gd"

## Every script, preset and scene of the kit loads (a parse error fails here, not in a game).


func test_every_file_loads() -> void:
	var stack := ["res://addons/bot_kit"]
	var seen := 0
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			stack.append(dir.path_join(sub))
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".gd") or file.ends_with(".tres") or file.ends_with(".tscn"):
				var path := dir.path_join(file)
				var res := load(path)
				check(res != null, "%s loads" % path)
				if res is GDScript:
					check((res as GDScript).can_instantiate(), "%s compiles" % path)
				seen += 1
	check(seen > 15, "found the kit's files (%d)" % seen)


func test_presets_rise_in_skill() -> void:
	var easy := load("res://addons/bot_kit/presets/easy.tres") as BotDifficulty
	var normal := load("res://addons/bot_kit/presets/normal.tres") as BotDifficulty
	var hard := load("res://addons/bot_kit/presets/hard.tres") as BotDifficulty
	check(easy != null and normal != null and hard != null, "three presets")
	check(easy.sight_m < normal.sight_m and normal.sight_m < hard.sight_m, "farther sight")
	check(easy.reaction_s > normal.reaction_s and normal.reaction_s > hard.reaction_s, "quicker reaction")
	check(easy.turn_deg_s < normal.turn_deg_s and normal.turn_deg_s < hard.turn_deg_s, "quicker turn")
	check(easy.aim_error_deg > normal.aim_error_deg and normal.aim_error_deg > hard.aim_error_deg, "smaller error")
	check(easy.trigger_share() < normal.trigger_share() and normal.trigger_share() < hard.trigger_share(), "more trigger")
	var bot := Bot3D.new()
	check(bot.current_difficulty() == normal, "a bot without one plays normal")
	bot.free()


## What a server runs needs no camera, picture or shader (the debug drawing is only made when asked).
func test_nodes_need_no_screen() -> void:
	for dir in ["res://addons/bot_kit/nodes", "res://addons/bot_kit/core"]:
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".gd") or file == "bot_debug.gd":
				continue
			var code := FileAccess.get_file_as_string(dir.path_join(file))
			for word in ["Camera3D", "get_camera", "get_texture()", "ShaderMaterial", "RenderingServer"]:
				check(not code.contains(word), "%s does not use %s" % [file, word])


## No kit depends on another (the game connects them), and no game is named. The tests, which name them here, aside.
func test_no_other_kit_or_game() -> void:
	var stack := ["res://addons/bot_kit"]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			if sub != "tests":
				stack.append(dir.path_join(sub))
		for file in DirAccess.get_files_at(dir):
			if not (file.ends_with(".gd") or file.ends_with(".tscn") or file.ends_with(".tres")):
				continue
			var code := FileAccess.get_file_as_string(dir.path_join(file))
			for word in ["mp_kit", "MpKit", "MpInput", "fsm_kit", "FsmMachine", "FsmState", "perception_kit", "Perception",
					"rts_kit", "prop_kit", "grass_kit", "plat_kit", "spill_kit", "Intervendoom", "Eternauta", "Sacrifice"]:
				check(not code.contains(word), "%s names no other kit or game (%s)" % [file, word])
