extends SceneTree

## Draws the textures of the example's paint (a PBR type of its own): a mark and a puddle, each an
## albedo (its shape in the alpha, a grain in its shade), a normal map (a rounded edge and brush
## ridges) and an ORM (occlusion in the ridges, dry and rough at the thin edge, wet in the middle).
## With a fixed seed, so they come out the same every run. The PNGs are in the repo; run it again
## only to change them:
##   godot --headless --path <project> --script res://addons/spill_kit/examples/substances_3d/textures/make_paint_textures.gd

const DIR := "res://addons/spill_kit/examples/substances_3d/textures"
const SIZE_PX := 128
const SEED := 2911


func _initialize() -> void:
	_draw("mark", 0.55, 0.24, 9)
	_draw("puddle", 0.82, 0.1, 0)
	quit()


func _draw(named: String, radius_share: float, wobble: float, satellites: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + named.length()
	var grain := FastNoiseLite.new()
	grain.seed = rng.randi()
	grain.frequency = 0.09
	var phases := PackedFloat32Array()
	for i in 4:
		phases.append(rng.randf() * TAU)
	var half := SIZE_PX * 0.5
	var radius := radius_share * half
	var rim := radius * 0.35
	var drops: Array[Vector3] = []
	for i in satellites:
		var at := Vector2(half, half) + Vector2.from_angle(rng.randf() * TAU) * radius * rng.randf_range(1.1, 1.6)
		drops.append(Vector3(at.x, at.y, rng.randf_range(2.0, 5.0)))
	var stroke := Vector2.from_angle(rng.randf() * PI)
	var height := PackedFloat32Array()
	var thin := PackedFloat32Array()
	height.resize(SIZE_PX * SIZE_PX)
	thin.resize(SIZE_PX * SIZE_PX)
	for y in SIZE_PX:
		for x in SIZE_PX:
			var offset := Vector2(x + 0.5 - half, y + 0.5 - half)
			var edge := radius
			for i in phases.size():
				edge += radius * wobble / float(i + 1) * sin(offset.angle() * float(i + 2) + phases[i])
			var inside := edge - offset.length()
			for drop in drops:
				inside = maxf(inside, drop.z - Vector2(x + 0.5, y + 0.5).distance_to(Vector2(drop.x, drop.y)))
			var body := 0.0 if inside <= 0.0 else sqrt(1.0 - pow(1.0 - minf(inside / rim, 1.0), 2.0))
			var ridges := 0.5 + 0.5 * sin(offset.dot(stroke) * 0.55 + grain.get_noise_2d(x, y) * 4.0)
			height[y * SIZE_PX + x] = body * (0.82 + 0.18 * ridges)
			thin[y * SIZE_PX + x] = 1.0 - minf(maxf(inside, 0.0) / rim, 1.0)
	var albedo := Image.create_empty(SIZE_PX, SIZE_PX, false, Image.FORMAT_RGBA8)
	var normal := Image.create_empty(SIZE_PX, SIZE_PX, false, Image.FORMAT_RGB8)
	var orm := Image.create_empty(SIZE_PX, SIZE_PX, false, Image.FORMAT_RGB8)
	for y in SIZE_PX:
		for x in SIZE_PX:
			var h := height[y * SIZE_PX + x]
			var shade := 0.86 + 0.14 * grain.get_noise_2d(x * 3.0, y * 3.0)
			albedo.set_pixel(x, y, Color(shade, shade, shade, clampf(h * 5.0, 0.0, 1.0)))
			var dx := (_at(height, x + 1, y) - _at(height, x - 1, y)) * 0.5 * rim
			var dy := (_at(height, x, y + 1) - _at(height, x, y - 1)) * 0.5 * rim
			var n := Vector3(-dx, dy, 1.0).normalized()
			normal.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
			var crevice := clampf(1.0 - n.z, 0.0, 1.0)
			var rough := lerpf(0.2, 0.85, thin[y * SIZE_PX + x]) + 0.1 * grain.get_noise_2d(x * 2.0 + 50.0, y * 2.0)
			orm.set_pixel(x, y, Color(1.0 - crevice * 0.6, clampf(rough, 0.0, 1.0), 0.0))
	_save(albedo, "%s_albedo.png" % named)
	_save(normal, "%s_normal.png" % named)
	_save(orm, "%s_orm.png" % named)


func _at(height: PackedFloat32Array, x: int, y: int) -> float:
	return height[clampi(y, 0, SIZE_PX - 1) * SIZE_PX + clampi(x, 0, SIZE_PX - 1)]


func _save(image: Image, file: String) -> void:
	var err := image.save_png(DIR.path_join(file))
	if err != OK:
		push_error("make_paint_textures: could not save %s (%s)" % [file, error_string(err)])
