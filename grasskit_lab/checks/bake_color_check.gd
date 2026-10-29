extends SceneTree

## GrassKit's ground-colour bake, rendered for real (it needs a window):
##   godot --path grasskit_lab --script res://checks/bake_color_check.gd
## Plays the example, bakes its ground's colour, and checks the image: its size, soil on the
## painted path, the grass's colour on the meadow (the ground under the grass), no blades in it,
## the colour map in the ground. Prints BAKE COLOR CHECK PASS (exit 0) or BAKE COLOR CHECK FAIL: n.
## With BAKE_COLOR_PNG=<file> it also saves the image.

var _fails := 0


func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _initialize() -> void:
	var scene := (load("res://addons/grass_kit/examples/grass_3d/grass_3d.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	for i in 10:
		await process_frame
	var field := scene.get_node("Field") as GrassField3D
	var ground := field.ground
	var image: Image = await field.bake_ground_color()
	_check(image != null and image.get_size() == ground.new_map_size(), "an image, one texel per paint_texel_size (%s)" % [image.get_size() if image != null else null])
	if image == null:
		_finish()
		return
	if not OS.get_environment("BAKE_COLOR_PNG").is_empty():
		image.save_png(OS.get_environment("BAKE_COLOR_PNG"))
	var path := _at(image, ground, Vector2(0, 20))
	var meadow := _at(image, ground, Vector2(30, 0))
	_check(path.r > path.g and path.a > 0.99, "the painted path is soil (%s)" % path)
	_check(meadow.g > meadow.r and meadow.g > path.g, "the meadow is the ground under the grass (%s)" % meadow)
	var plain := (scene.get_node("Hills") as Node).get(&"ground_color") as Color
	_check(not meadow.is_equal_approx(plain), "taken towards the grass's colour, not the hills' own (%s against %s)" % [meadow, plain])
	var near := _at(image, ground, Vector2(31, 0))
	_check(near.is_equal_approx(meadow) or absf(near.g - meadow.g) < 0.05, "smooth: no blades in it")
	_check(ground.color_texture is GrassMap and (ground.color_texture as GrassMap).source == image, "kept as the ground's colour map")
	_check(field.visible and not field.ground_bake_view, "the field shows again, with its own globals")
	_finish()


func _at(image: Image, ground: GrassGround, at: Vector2) -> Color:
	var texel := (at - ground.area.position) / ground.area.size * Vector2(image.get_size())
	return image.get_pixelv(Vector2i(texel.floor()))


func _finish() -> void:
	print("BAKE COLOR CHECK PASS" if _fails == 0 else "BAKE COLOR CHECK FAIL: %d" % _fails)
	quit(0 if _fails == 0 else 1)
