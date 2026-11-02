extends "res://addons/perception_kit/tests/perception_test.gd"

## Every script and scene of the kit loads (a parse error fails here, not in a game).


func test_every_script_compiles() -> void:
	var stack := ["res://addons/perception_kit"]
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
					check((res as GDScript).can_instantiate() or (res as GDScript).is_abstract(), "%s compiles" % path)
				seen += 1
	check(seen > 15, "found the kit's files (%d)" % seen)


## The nodes a game ships run in a dedicated server: nothing of theirs needs a camera, a viewport's
## picture or a shader.
func test_sensors_need_no_screen() -> void:
	for file in DirAccess.get_files_at("res://addons/perception_kit/sensors"):
		if not file.ends_with(".gd"):
			continue
		var code := FileAccess.get_file_as_string("res://addons/perception_kit/sensors".path_join(file))
		for word in ["Camera3D", "Camera2D", "get_camera", "get_texture()", "ShaderMaterial", "RenderingServer"]:
			check(not code.contains(word), "%s does not use %s" % [file, word])


## No kit depends on another (the game connects them). The tests, which name them here, aside.
func test_no_other_kit() -> void:
	var stack := ["res://addons/perception_kit"]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			if sub != "tests":
				stack.append(dir.path_join(sub))
		for file in DirAccess.get_files_at(dir):
			if not (file.ends_with(".gd") or file.ends_with(".tscn")):
				continue
			var code := FileAccess.get_file_as_string(dir.path_join(file))
			for kit in ["mp_kit", "fsm_kit", "rts_kit", "prop_kit", "grass_kit", "plat_kit", "MpKit", "FsmMachine", "FsmState"]:
				check(not code.contains(kit), "%s names no other kit (%s)" % [file, kit])
