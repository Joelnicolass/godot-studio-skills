extends "res://addons/spill_kit/tests/spill_test.gd"

## Every script and scene of the kit loads (a parse error fails here, not in a game).


func test_every_script_compiles() -> void:
	var seen := 0
	for path in _kit_files(["gd", "tres", "tscn", "gdshader"], true):
		var res := load(path)
		check(res != null, "%s loads" % path)
		if res is GDScript:
			check((res as GDScript).can_instantiate() or (res as GDScript).is_abstract(), "%s compiles" % path)
		seen += 1
	check(seen > 15, "found the kit's files (%d)" % seen)


## No kit depends on another (the game connects them): no file of the kit names one, its nodes or its
## autoloads. The tests, which name them here, aside.
func test_no_other_kit() -> void:
	var kits := [
		"mp_kit", "fsm_kit", "rts_kit", "prop_kit", "grass_kit", "plat_kit", "perception_kit",
		"MpKit", "MpActor", "MpSync", "FsmMachine", "FsmState", "Rts", "GrassField", "Perception",
		"PlatKit", "PropKit",
	]
	var seen := 0
	for path in _kit_files(["gd", "tscn", "tres", "gdshader", "cfg"], false):
		var code := FileAccess.get_file_as_string(path)
		seen += 1
		for kit: String in kits:
			check(not code.contains(kit), "%s names no other kit (%s)" % [path, kit])
	check(seen > 8, "read the kit's files (%d)" % seen)


## What runs on a dedicated server (the source, its rules, its wound) needs no camera or screen;
## the pool builds and draws nothing there.
func test_the_server_side_needs_no_screen() -> void:
	for path in ["nodes/spill_source_3d.gd", "core/spill_rules.gd", "core/spill_wound.gd"]:
		var code := FileAccess.get_file_as_string("res://addons/spill_kit".path_join(path))
		check(not code.is_empty(), "%s read" % path)
		for word in ["Camera3D", "get_camera", "get_texture()", "RenderingServer", "Material"]:
			check(not code.contains(word), "%s does not use %s" % [path, word])


func _kit_files(extensions: Array, with_tests: bool) -> PackedStringArray:
	var out := PackedStringArray()
	var stack := ["res://addons/spill_kit"]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			if with_tests or sub != "tests":
				stack.append(dir.path_join(sub))
		for file in DirAccess.get_files_at(dir):
			if extensions.has(file.get_extension()):
				out.append(dir.path_join(file))
	return out
