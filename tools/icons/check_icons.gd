extends SceneTree

## Checks, with no window, that every class of classes.tsv the open project has carries its icon:
## the class is registered with an `icon`, the file is the one of its kit and it loads as a texture.
## The kit's emblem has to load too.
##
##   godot --headless --path <kit>_lab -s <repo>/tools/icons/check_icons.gd
##
## The project has to be imported first (`--headless --path <kit>_lab --import`).

func _init() -> void:
	var here: String = (get_script() as Script).resource_path.get_base_dir()
	var registered: Dictionary = {}
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		registered[entry["class"]] = entry

	var failures: PackedStringArray = []
	var checked: int = 0
	var kits: Dictionary = {}
	var table: FileAccess = FileAccess.open(here.path_join("classes.tsv"), FileAccess.READ)
	if table == null:
		printerr("check_icons: classes.tsv not found next to this script")
		quit(1)
		return
	table.get_line()
	while not table.eof_reached():
		var columns: PackedStringArray = table.get_line().split("\t")
		if columns.size() < 6:
			continue
		var kit: String = columns[0]
		var class_id: String = columns[1]
		var script_path: String = "res://" + columns[5]
		if not DirAccess.dir_exists_absolute("res://addons/" + kit):
			continue
		kits[kit] = true
		checked += 1
		var expected: String = "res://addons/%s/icons/%s.svg" % [kit, script_path.get_file().get_basename()]
		if not registered.has(class_id):
			failures.append("%s: not a registered class" % class_id)
			continue
		var icon: String = registered[class_id]["icon"]
		if icon.is_empty():
			failures.append("%s: no @icon" % class_id)
		elif icon != expected:
			failures.append("%s: icon is %s, expected %s" % [class_id, icon, expected])
		else:
			_check_texture(class_id, icon, failures)

	for kit: String in kits:
		_check_texture(kit + " emblem", "res://addons/%s/icons/%s.svg" % [kit, kit], failures)

	for failure: String in failures:
		printerr("  FAIL ", failure)
	print("check_icons: %d classes of %s, %d failures" % [checked, ", ".join(kits.keys()), failures.size()])
	quit(1 if failures.size() > 0 or checked == 0 else 0)


func _check_texture(label: String, path: String, failures: PackedStringArray) -> void:
	if not FileAccess.file_exists(path):
		failures.append("%s: %s does not exist" % [label, path])
		return
	var texture: Texture2D = load(path) as Texture2D
	if texture == null:
		failures.append("%s: %s does not load as a Texture2D" % [label, path])
	elif texture.get_width() != 16 or texture.get_height() != 16:
		failures.append("%s: %s is %d x %d, not 16 x 16" % [label, path, texture.get_width(), texture.get_height()])
