@tool
extends EditorPlugin

## The lab's check of SpillKit in a real editor, the way a person uses it:
## - minimal_3d: the dummy's source shows its "Try it" buttons in the inspector; pressing Spray,
##   Heavy spray and Die (puddle) draws drops, marks on the floor and a puddle in the 3D view (the
##   floor found by the editor's physics), and the pool's Clear the floor takes them off; the
##   inspector shows the cost line of the source and of the pool; a source without a type is warned;
##   the saved scene keeps its values and nothing the kit drew;
## - a body's scene alone (no pool, no floor): Spray makes a pool there, which is not saved.
## Nothing unless the editor starts with SPILLKIT_EDITOR_CHECK=1:
##   SPILLKIT_EDITOR_CHECK=1 godot --headless --editor --path spillkit_lab
## Prints EDITOR CHECK PASS (exit 0) or EDITOR CHECK FAIL: n.

const EXAMPLES := "res://addons/spill_kit/examples"
const FOLDER := "res://scratch/editor_check"
const BODY_SCENE := """[gd_scene format=3]

[ext_resource type="Script" path="res://addons/spill_kit/nodes/spill_source_3d.gd" id="1_source"]
[ext_resource type="Resource" path="res://addons/spill_kit/examples/types/blood.tres" id="2_blood"]

[node name="Body" type="StaticBody3D"]
collision_layer = 2

[node name="Spill" type="Node3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.2, 0)
script = ExtResource("1_source")
type = ExtResource("2_blood")
"""

var _fails := 0


func _enter_tree() -> void:
	if OS.get_environment("SPILLKIT_EDITOR_CHECK") == "1":
		_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


## A scene to edit, written in a folder of its own (the addon's files stay as they are).
func _open(text: String, name: String) -> Node:
	var folder := FOLDER.path_join("run_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var path := folder.path_join(name)
	text = RegEx.create_from_string(" uid=\"uid://[a-z0-9]+\"").sub(text, "", true)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	EditorInterface.get_resource_filesystem().scan()
	await _frames(20)
	EditorInterface.open_scene_from_path(path)
	await _frames(20)
	return EditorInterface.get_edited_scene_root()


## Selects [param node] and presses its inspector button that reads [param text], as a person does.
func _press(node: Node, text: String) -> bool:
	EditorInterface.edit_node(node)
	await _frames(5)
	for found in EditorInterface.get_inspector().find_children("*", "Button", true, false):
		var button := found as Button
		if button.text == text:
			button.pressed.emit()
			await _frames(3)
			return true
	return false


## The cost line the inspector shows for [param node].
func _cost_line(node: Node) -> String:
	EditorInterface.edit_node(node)
	await _frames(5)
	var found := EditorInterface.get_inspector().find_children("SpillKitCost", "Label", true, false)
	return (found[0] as Label).text if not found.is_empty() else ""


func _run() -> void:
	await _frames(10)
	if DirAccess.dir_exists_absolute(FOLDER):
		for old in DirAccess.get_directories_at(FOLDER):
			_remove(FOLDER.path_join(old))
	await _check_minimal()
	await _check_body_alone()
	print("EDITOR CHECK PASS" if _fails == 0 else "EDITOR CHECK FAIL: %d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _check_minimal() -> void:
	var root := await _open(FileAccess.get_file_as_string(EXAMPLES.path_join("minimal_3d/minimal_3d.tscn")), "minimal_3d.tscn")
	_check(root != null and root.name == "Minimal3D", "minimal_3d is open")
	if root == null:
		return
	var source := root.get_node_or_null(^"Dummy/Spill") as SpillSource3D
	var pool := root.get_node_or_null(^"SpillPool3D") as SpillPool3D
	_check(source != null and pool != null, "the dummy's source and the pool")
	if source == null or pool == null:
		return
	var type := source.type
	var line := await _cost_line(source)
	_check(line.begins_with("Cost of a hit: 14 drops"), "the source's cost line: %s" % line)
	line = await _cost_line(pool)
	_check(line.begins_with("Cost: 1 type, 276 drops"), "the pool's cost line: %s" % line)
	_check(await _press(source, "Spray"), "the Spray button is in the source's inspector")
	_check(pool.sprays_played(type) == 1, "a spray in the 3D view")
	_check(pool.mark_count(type) == 1, "its mark on the floor: the editor's physics found it")
	var drops := 0
	for child in pool.get_children(true):
		if child is CPUParticles3D and (child as CPUParticles3D).emitting:
			drops += 1
	_check(drops == 1, "its drops are flying")
	await _press(source, "Heavy spray")
	_check(pool.mark_count(type) == 4 and SpillWound.is_heavy(source.wound), "Heavy spray: 3 marks more")
	await _press(source, "Die (puddle)")
	_check(pool.puddles_of(type).size() == 1, "Die (puddle): a puddle")
	await get_tree().create_timer(0.5).timeout
	var puddles := pool.puddles_of(type)
	_check(not puddles.is_empty() and puddles[0].basis.x.length() > pool.puddle_start_m, "it grows in the editor")
	_check(await _press(pool, "Clear the floor"), "the pool's Clear the floor button")
	_check(pool.mark_count(type) == 0 and pool.puddles_of(type).is_empty(), "the floor is clean")
	source.type = null
	_check("\n".join(source._get_configuration_warnings()).contains("type"), "a source without a type is warned")
	source.type = type
	_check(source._get_configuration_warnings().is_empty(), "with its type, no warning")
	await _press(source, "Spray")
	source.heavy_from = 0.3
	EditorInterface.save_scene()
	await _frames(5)
	var saved := FileAccess.get_file_as_string(root.scene_file_path)
	_check(saved.contains("heavy_from = 0.3"), "the saved scene keeps a changed value")
	for word in ["CPUParticles3D", "MultiMesh", "wound"]:
		_check(not saved.contains(word), "the saved scene holds nothing the kit drew (%s)" % word)
	_check(saved.count("[node name=") == root.get_tree().edited_scene_root.find_children("*", "", true, true).size() + 1, "and only the scene's own nodes")


func _check_body_alone() -> void:
	var root := await _open(BODY_SCENE, "body.tscn")
	_check(root != null and root.name == "Body", "a body's scene alone is open")
	if root == null:
		return
	var source := root.get_node_or_null(^"Spill") as SpillSource3D
	_check(SpillPool3D.of(root.get_world_3d()) == null or SpillPool3D.of(root.get_world_3d()).get_parent() != root, "it has no pool of its own")
	_check(await _press(source, "Spray"), "the Spray button")
	var pool := SpillPool3D.of(root.get_world_3d())
	_check(pool != null and pool.get_parent() == root, "a pool was made in the edited scene")
	_check(pool != null and pool.sprays_played(source.type) == 1, "and the drops fly (no floor: no mark)")
	_check(root.get_child_count() == 1, "the made pool is internal: the scene's tree shows only the Spill")
	EditorInterface.mark_scene_as_unsaved()
	EditorInterface.save_scene()
	await _frames(5)
	var saved := FileAccess.get_file_as_string(root.scene_file_path)
	_check(not saved.contains("SpillPool3D") and saved.count("[node name=") == 2, "the saved scene has no pool")


func _remove(folder: String) -> void:
	for name in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join(name)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
