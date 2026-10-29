@tool
extends EditorPlugin

## The lab's check of GrassKit in a real editor, the way a person uses it:
## - the grass shows around the 3D view's camera with the editor's smaller radius, the field warns
##   that its ground is flat, «Bake ground» reads the hills, saves next to the scene, and undoes;
## - selecting the field brings its toolbar; a brush paints where the mouse is (Ctrl erases), the
##   stroke undoes and redoes, the keys size the brush, saving the scene keeps the map;
## - the «Kind» brush names a kind and paints where it grows; the menu fills and clears a map;
## - the area's and a clearing's handles drag and undo, keeping what is painted where it is;
## - a field added to the scene sets itself up and bakes; a quality preset button undoes.
## Nothing unless the editor starts with GRASSKIT_EDITOR_CHECK=1:
##   GRASSKIT_EDITOR_CHECK=1 godot --headless --editor --path grasskit_lab
## (headless, the field is told to draw anyway). With a window, GRASSKIT_EDITOR_SHOTS=<folder>
## saves what the 3D view shows while painting. Prints EDITOR CHECK PASS (exit 0) or
## EDITOR CHECK FAIL: n.

const SOURCE := "res://addons/grass_kit/examples/grass_3d/grass_3d.tscn"
const GROUND := "res://addons/grass_kit/examples/grass_3d/grass_3d_grass_ground.res"
const FOLDER := "res://scratch/editor_check"

var _fails := 0
## This run's copy of the example: a folder of its own, so nothing a past run left open or cached
## gets in the way.
var COPY := ""


func _enter_tree() -> void:
	if OS.get_environment("GRASSKIT_EDITOR_CHECK") == "1":
		_run.call_deferred()
	elif not OS.get_environment("GRASSKIT_EDITOR_SHOTS").is_empty():
		_shots.call_deferred(OS.get_environment("GRASSKIT_EDITOR_SHOTS"))


func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


## A copy of the example and of its ground, so nothing here touches the addon's own files.
func _open_copy() -> Node:
	for old in DirAccess.get_directories_at(FOLDER):
		_remove(FOLDER.path_join(old))
	var folder := FOLDER.path_join("run_%d" % Time.get_ticks_usec())
	COPY = folder.path_join("grass.tscn")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var ground_copy := COPY.get_basename() + "_grass_ground.res"
	DirAccess.copy_absolute(ProjectSettings.globalize_path(GROUND), ProjectSettings.globalize_path(ground_copy))
	var text := FileAccess.get_file_as_string(SOURCE)
	text = RegEx.create_from_string(" uid=\"uid://[a-z0-9]+\"").sub(text, "", true)
	text = text.replace(GROUND, ground_copy)
	var file := FileAccess.open(COPY, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	EditorInterface.get_resource_filesystem().scan()
	await _frames(30)
	EditorInterface.open_scene_from_path(COPY)
	EditorInterface.set_main_screen_editor("3D")
	await _frames(30)
	return EditorInterface.get_edited_scene_root()


func _remove(folder: String) -> void:
	for name in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join(name)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))


func _field(root: Node) -> GrassField3D:
	return root.find_children("*", "GrassField3D", true, false)[0] as GrassField3D


## GrassKit's own plugin, as the editor runs it.
func _grass_plugin() -> EditorPlugin:
	for node in get_tree().root.find_children("*", "EditorPlugin", true, false):
		var script := node.get_script() as Script
		if script != null and script.resource_path == "res://addons/grass_kit/plugin.gd":
			return node as EditorPlugin
	return null


func _history(object: Object) -> UndoRedo:
	var manager := EditorInterface.get_editor_undo_redo()
	return manager.get_history_undo_redo(manager.get_object_history_id(object))


## The density the field's ground has at `at` (x, z): 1 where nothing is painted.
func _density(ground: GrassGround, at: Vector2) -> float:
	var image := ground.export_map(GrassGround.DENSITY)
	if image == null:
		return 1.0
	var texel := (at - ground.area.position) / ground.area.size * Vector2(image.get_size())
	return image.get_pixelv(Vector2i(texel.floor())).r


func _click(plugin: EditorPlugin, camera: Camera3D, at: Vector2, pressed: bool, ctrl := false) -> int:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	event.ctrl_pressed = ctrl
	event.meta_pressed = ctrl
	return plugin._forward_3d_gui_input(camera, event)


func _move(plugin: EditorPlugin, camera: Camera3D, at: Vector2, ctrl := false) -> int:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.ctrl_pressed = ctrl
	event.meta_pressed = ctrl
	return plugin._forward_3d_gui_input(camera, event)


func _key(plugin: EditorPlugin, camera: Camera3D, keycode: Key) -> int:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return plugin._forward_3d_gui_input(camera, event)


func _run() -> void:
	GrassField3D.draw_anywhere = true
	await _frames(10)
	var root := await _open_copy()
	_check(root != null and root.scene_file_path == COPY, "the copy of the example is open")
	var field := _field(root)
	field.enabled = false
	field.enabled = true
	await _frames(30)
	_check(field.stats.cells > 0, "the grass shows in the editor, around the 3D view's camera (%s)" % field.stats)
	var play_ring := field.quality.blades_in_ring()
	_check(field.stats.blades < play_ring, "with the editor's smaller radius (%d < %d)" % [field.stats.blades, play_ring])
	_check(field.get_child_count() == 0 and field.get_child_count(true) > 0, "its cells are internal: not in the scene")
	var warnings := "\n".join(field._get_configuration_warnings())
	_check(warnings.contains("Bake ground"), "it warns that the ground is flat (%s)" % warnings)
	await get_tree().physics_frame
	field.bake_button.call()
	var saved := COPY.get_basename() + "_grass_ground.res"
	_check(field.ground.data != null and field.ground.resource_path == saved, "«Bake ground» reads the hills, the ground kept next to the scene (%s)" % field.ground.resource_path)
	var hills := root.get_node("Hills")
	_check(absf(field.ground.height_at(Vector2(4, 7)) - float(hills.call(&"height_at", 4.0, 7.0))) < 0.1, "with the hills' height")
	var on_disk := ResourceLoader.load(saved, "", ResourceLoader.CACHE_MODE_IGNORE) as GrassGround
	_check(on_disk != null and on_disk.data != null, "and saved")
	warnings = "\n".join(field._get_configuration_warnings())
	_check(not warnings.contains("Bake ground"), "the warning is gone (%s)" % warnings)
	_history(field).undo()
	_check(field.ground.data == null, "Ctrl+Z: the ground is flat again")
	_history(field).redo()
	_check(field.ground.data != null, "Ctrl+Shift+Z: baked again")
	var clear := root.find_children("*", "GrassClear3D", true, false)[0] as GrassClear3D
	_check(clear.get_gizmos().size() > 0, "the GrassClear3D has its gizmo")

	# The brushes.
	var plugin := _grass_plugin()
	_check(plugin != null, "GrassKit's plugin runs")
	var tool: Node = plugin.get(&"_tool")
	EditorInterface.edit_node(field)
	await _frames(5)
	var bars: Array[Control] = tool.call(&"bars")
	_check(tool.get(&"field") == field and bars[0].visible and bars[0].get_parent() != null, "selecting the field shows its toolbar in the 3D view")
	tool.call(&"_set_tool", 1)
	var viewport := EditorInterface.get_editor_viewport_3d(0)
	var camera := viewport.get_camera_3d()
	camera.global_transform = Transform3D(Basis.looking_at(Vector3(0, -1, -0.001)), Vector3(-20, 40, 30))
	await _frames(3)
	var middle := Vector2(viewport.size) * 0.5
	var aim: Variant = field.ground.ray_hit(camera.project_ray_origin(middle), camera.project_ray_normal(middle))
	_check(aim != null, "the brush aims at the ground under the mouse (%s)" % [aim])
	var spot := Vector2(aim.x, aim.z) if aim != null else Vector2.ZERO
	var brush: GrassBrush = tool.get(&"brush")
	# As a person sets them: the sliders under the 3D view.
	(tool.get(&"_size") as EditorSpinSlider).value = 3.0
	(tool.get(&"_strength") as EditorSpinSlider).value = 1.0
	(tool.get(&"_noise") as EditorSpinSlider).value = 0.0
	_check(brush.radius == 3.0 and brush.strength == 1.0 and brush.noise == 0.0, "the sliders set the brush")
	var before := _density(field.ground, spot)
	var hover := _move(plugin, camera, middle)
	_check(hover == EditorPlugin.AFTER_GUI_INPUT_PASS and RID(tool.get(&"_cursor")).is_valid(), "hovering draws the brush's circle and leaves the view's input alone")
	_check(field._editor_focus.distance_to(spot) < 0.5, "the grass follows the brush")
	var took := _click(plugin, camera, middle, true, true)
	for k in 4:
		_move(plugin, camera, middle + Vector2(k * 6, 0), true)
	_click(plugin, camera, middle + Vector2(18, 0), false, true)
	_check(took == EditorPlugin.AFTER_GUI_INPUT_STOP, "a click with a brush up paints instead of selecting")
	_check(field.ground.density_texture is GrassMap and _density(field.ground, spot) < 0.1 and before > 0.9, "Ctrl + drag erases the grass there (%.2f, was %.2f)" % [_density(field.ground, spot), before])
	_check(_density(field.ground, spot + Vector2(-30, 0)) > 0.9, "and only there")
	var painted := field.ground.density_texture
	_history(field).undo()
	_check(field.ground.density_texture == painted and absf(_density(field.ground, spot) - before) < 0.01, "Ctrl+Z: the stroke goes")
	_history(field).redo()
	_check(field.ground.density_texture == painted and _density(field.ground, spot) < 0.1, "Ctrl+Shift+Z: back")
	var empty := GrassGround.new()
	empty.area = field.ground.area
	var kept_ground := field.ground
	empty.take_over_path(COPY.get_basename() + "_empty_ground.res")
	field.ground = empty
	tool.call(&"edit", field)
	_click(plugin, camera, middle, true, true)
	_click(plugin, camera, middle, false, true)
	_check(empty.density_texture is GrassMap, "on a ground with no map, the first stroke makes one")
	_history(field).undo()
	_check(empty.density_texture == null, "Ctrl+Z: and takes it away")
	field.ground = kept_ground
	tool.call(&"edit", field)
	_click(plugin, camera, middle + Vector2(0, 40), true)
	_click(plugin, camera, middle + Vector2(0, 40), false)
	EditorInterface.edit_node(field)
	await _frames(3)
	var radius := brush.radius
	_key(plugin, camera, KEY_BRACKETRIGHT)
	_check(brush.radius > radius, "] makes the brush bigger (%.1f > %.1f)" % [brush.radius, radius])
	EditorInterface.save_scene()
	await _frames(5)
	on_disk = ResourceLoader.load(saved, "", ResourceLoader.CACHE_MODE_IGNORE) as GrassGround
	var kept := on_disk.export_map(GrassGround.DENSITY) if on_disk != null else null
	_check(kept != null and _density(on_disk, spot) < 0.1, "saving the scene keeps the painted map in the ground")

	# A kind with no name yet, the «Kind» brush, and the menu.
	var look := GrassLook.new()
	var blade := GrassMesh.new()
	blade.weight = 9.0
	var bush := GrassMesh.new()
	bush.mesh = SphereMesh.new()
	look.meshes = [blade, bush]
	field.look = look
	tool.call(&"edit", field)
	tool.set(&"kind_index", 1)
	tool.call(&"_set_tool", 4)
	_click(plugin, camera, middle, true)
	_click(plugin, camera, middle, false)
	_check(bush.map_name == &"kind_2" and field.ground.kind_maps.has(&"kind_2"), "the «Kind» brush names the kind and paints where it grows (%s)" % bush.map_name)
	await _frames(3)
	_history(field).undo()
	_check(bush.map_name == &"" and not field.ground.kind_maps.has(&"kind_2"), "Ctrl+Z: no name, no map")
	tool.call(&"_set_tool", 2)
	tool.set(&"height", 0.4)
	tool.call(&"_on_menu", 10)
	var size_map := field.ground.export_map(GrassGround.SIZE)
	_check(size_map != null and absf(size_map.get_pixel(3, 3).r - 0.2) < 0.01, "GrassKit ▸ Fill the size map: the Height brush's value everywhere")
	tool.call(&"_on_menu", 11)
	_check(field.ground.size_texture == null, "GrassKit ▸ Clear the size map")
	_history(field).undo()
	_check(field.ground.size_texture != null, "Ctrl+Z: back")
	var colour := field.ground.color_texture
	await tool.call(&"_bake_colour")
	_check(field.ground.color_texture == colour and not field.ground_bake_view and field.visible, "GrassKit ▸ Bake ground colour headless: nothing baked, nothing left hidden (it needs a window)")

	# Handles.
	var gizmos: EditorNode3DGizmoPlugin = plugin.get(&"_gizmos")
	var area := field.ground.area
	var narrower := Rect2(area.position, area.size - Vector2(20, 0))
	gizmos.get(&"_dragging")[field] = narrower
	gizmos._commit_handle(field.get_gizmos()[0], 1, false, area, false)
	_check(field.ground.area == narrower and _density(field.ground, spot) < 0.1, "dragging the area's east side in: the painted path stays where it was")
	_check(not field.ground.has_ground(Vector2(area.end.x - 10, 0)), "no ground past the new side")
	gizmos.get(&"_dragging")[field] = area
	gizmos._commit_handle(field.get_gizmos()[0], 1, false, narrower, false)
	_check(field.ground.area == area and field.ground.has_ground(Vector2(area.end.x - 10, 0)), "and out again: the new part is baked")
	_history(field).undo()
	_history(field).undo()
	_check(field.ground.area == area and _density(field.ground, spot) < 0.1, "Ctrl+Z twice: the area as it was")
	var old_radius := clear.radius
	clear.radius = old_radius + 2.0
	gizmos._commit_handle(clear.get_gizmos()[0], 0, false, old_radius, false)
	_history(clear).undo()
	_check(is_equal_approx(clear.radius, old_radius), "a clearing's radius handle drags and undoes")

	# A new field, and a preset.
	var fresh := GrassField3D.new()
	fresh.name = "Fresh"
	root.add_child(fresh)
	fresh.owner = root
	await _frames(5)
	_check(fresh.ground != null and fresh.look != null and fresh.quality != null and fresh.wind != null, "a field added to the scene sets itself up")
	_check(fresh.ground.area.encloses(Rect2(-79, -79, 158, 158)) and fresh.ground.data != null, "fitted to the hills and baked (%s)" % fresh.ground.area)
	fresh.queue_free()
	var density := field.quality.density
	field.quality.low_button.call()
	_check(field.quality.density == GrassQuality.preset(GrassQuality.Level.LOW).density, "the quality's Low button")
	_history(field.quality).undo()
	_check(field.quality.density == density, "Ctrl+Z: the quality as it was")
	GrassField3D.draw_anywhere = false
	print("EDITOR CHECK PASS" if _fails == 0 else "EDITOR CHECK FAIL: %d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _shots(folder: String) -> void:
	await _frames(30)
	var root := await _open_copy()
	var field := _field(root)
	await get_tree().physics_frame
	field.bake_button.call()
	var viewport := EditorInterface.get_editor_viewport_3d(0)
	var camera := viewport.get_camera_3d()
	camera.global_transform = Transform3D(Basis.looking_at(Vector3(-0.5, -0.45, -1.0)), Vector3(12, 14, 28))
	EditorInterface.edit_node(root.find_children("*", "GrassClear3D", true, false)[0])
	await _frames(90)
	viewport.get_texture().get_image().save_png(folder.path_join("editor_3d.png"))
	# Painting: the field selected, the «Grass» brush up over the painted path.
	var plugin := _grass_plugin()
	var tool: Node = plugin.get(&"_tool")
	EditorInterface.edit_node(field)
	await _frames(10)
	tool.call(&"_set_tool", 1)
	camera.global_transform = Transform3D(Basis.looking_at(Vector3(0.2, -0.7, -1.0)), Vector3(-10, 22, 48))
	await _frames(20)
	_move(plugin, camera, Vector2(viewport.size) * Vector2(0.45, 0.55))
	await _frames(60)
	viewport.get_texture().get_image().save_png(folder.path_join("editor_paint.png"))
	get_tree().root.get_texture().get_image().save_png(folder.path_join("editor_window.png"))
	# Bake ground colour from the menu, and its undo.
	await tool.call(&"_bake_colour")
	var baked := field.ground.color_texture
	print("%s Bake ground colour makes the colour map" % ("PASS" if baked is GrassMap else "FAIL"))
	_history(field).undo()
	print("%s Ctrl+Z: the colour map as it was" % ("PASS" if field.ground.color_texture != baked else "FAIL"))
	_history(field).redo()
	field.look = root.get(&"flowers")
	tool.call(&"edit", field)
	tool.set(&"kind_index", 1)
	tool.call(&"_set_tool", 4)
	await _frames(60)
	viewport.get_texture().get_image().save_png(folder.path_join("editor_kind.png"))
	get_tree().quit(0)
