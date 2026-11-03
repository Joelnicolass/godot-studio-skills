class_name SpillShapes
extends RefCounted

## The kit's own drop, splat and puddle: an albedo (white, darker where the liquid is thicker, its
## shape in the alpha) and a normal map that raises it like a liquid (a round bead for a drop, a
## gently rounded edge around a flat middle for a mark or a puddle, so the light catches the rim and
## the middle shines like a mirror). Drawn once, with a fixed seed, the first time a type needs them.

enum Shape {
	DROP,
	MARK,
	PUDDLE,
}

const SEED := 4141
## Pixels of a side.
const SIZES := {Shape.DROP: 32, Shape.MARK: 64, Shape.PUDDLE: 128}
## The blob's radius over half the side.
const RADII := {Shape.DROP: 0.8, Shape.MARK: 0.52, Shape.PUDDLE: 0.82}
## How much its edge wobbles.
const WOBBLES := {Shape.DROP: 0.0, Shape.MARK: 0.22, Shape.PUDDLE: 0.1}
## Small drops thrown around a splat.
const SATELLITES := {Shape.DROP: 0, Shape.MARK: 7, Shape.PUDDLE: 0}
## How wide the rounded edge is, over the radius (a drop is round all over).
const RIMS := {Shape.DROP: 1.0, Shape.MARK: 0.3, Shape.PUDDLE: 0.16}
## How high the liquid stands, over its rim's width: a drop is a half sphere; a mark or a puddle is
## low, so its edge leans at most some 37 degrees and never reflects what is under the horizon.
const RISES := {Shape.DROP: 1.0, Shape.MARK: 0.5, Shape.PUDDLE: 0.5}
## How dark the thickest part is.
const DEEPEST_SHADE := 0.72
const EDGE_TERMS := 4

static var _albedo: Dictionary[Shape, Texture2D] = {}
static var _normal: Dictionary[Shape, Texture2D] = {}


## The kit's albedo of [param shape].
static func albedo(shape: Shape) -> Texture2D:
	if not _albedo.has(shape):
		_draw(shape)
	return _albedo[shape]


## The kit's normal map of [param shape].
static func normal(shape: Shape) -> Texture2D:
	if not _normal.has(shape):
		_draw(shape)
	return _normal[shape]


## The height of the liquid (0 to 1) of [param shape], one value per pixel, row by row.
static func heights(shape: Shape) -> PackedFloat32Array:
	var size: int = SIZES[shape]
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + shape
	var phases := PackedFloat32Array()
	for i in EDGE_TERMS:
		phases.append(rng.randf() * TAU)
	var half := size * 0.5
	var radius: float = RADII[shape] * half
	var rim: float = RIMS[shape] * radius
	var wobble: float = WOBBLES[shape]
	var satellite_count: int = SATELLITES[shape]
	var satellites: Array[Vector3] = []
	for i in satellite_count:
		var turn := rng.randf() * TAU
		var at := Vector2(half, half) + Vector2.from_angle(turn) * radius * rng.randf_range(1.15, 1.7)
		satellites.append(Vector3(at.x, at.y, rng.randf_range(1.5, 3.2)))
	var out := PackedFloat32Array()
	out.resize(size * size)
	for y in size:
		for x in size:
			var offset := Vector2(x + 0.5 - half, y + 0.5 - half)
			var edge := radius * _edge(offset.angle(), phases, wobble)
			var bead := shape == Shape.DROP
			var height := _profile(edge - offset.length(), rim, bead)
			for drop in satellites:
				var inside := drop.z - Vector2(x + 0.5, y + 0.5).distance_to(Vector2(drop.x, drop.y))
				height = maxf(height, _profile(inside, drop.z, false))
			out[y * size + x] = height
	return out


# Height at [param inside] pixels in from the edge, rising over [param rim] pixels and flat past
# it: a [param bead]'s round side, or a gentle S. Negative inside = outside, 0.
static func _profile(inside: float, rim: float, bead: bool) -> float:
	if inside <= 0.0:
		return 0.0
	var t := minf(inside / rim, 1.0)
	return sqrt(1.0 - (1.0 - t) * (1.0 - t)) if bead else smoothstep(0.0, 1.0, t)


static func _edge(angle: float, phases: PackedFloat32Array, wobble: float) -> float:
	var out := 1.0
	for i in phases.size():
		out += wobble / float(i + 1) * sin(angle * float(i + 2) + phases[i])
	return out


static func _draw(shape: Shape) -> void:
	var size: int = SIZES[shape]
	var height := heights(shape)
	var albedo_image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var normal_image := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	# The bead's slope in pixels: a rim this many pixels wide rises 45 degrees at its foot.
	var radius: float = RADII[shape]
	var rim: float = RIMS[shape]
	var rise: float = RISES[shape]
	var steep := float(size) * radius * 0.5 * rim * rise
	for y in size:
		for x in size:
			var h := height[y * size + x]
			# Alpha from the height with a soft step, so a cut at 0.5 falls by the edge.
			var alpha := clampf(h * 12.0, 0.0, 1.0)
			var shade := lerpf(1.0, DEEPEST_SHADE, h)
			albedo_image.set_pixel(x, y, Color(shade, shade, shade, alpha))
			var dx: float = (_at(height, size, x + 1, y) - _at(height, size, x - 1, y)) * 0.5 * steep
			var dy: float = (_at(height, size, x, y + 1) - _at(height, size, x, y - 1)) * 0.5 * steep
			# OpenGL convention (Godot's): green points up the image, so a rise downwards is -y.
			var n := Vector3(-dx, dy, 1.0).normalized()
			normal_image.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	albedo_image.generate_mipmaps()
	normal_image.generate_mipmaps()
	_albedo[shape] = ImageTexture.create_from_image(albedo_image)
	_normal[shape] = ImageTexture.create_from_image(normal_image)


static func _at(height: PackedFloat32Array, size: int, x: int, y: int) -> float:
	return height[clampi(y, 0, size - 1) * size + clampi(x, 0, size - 1)]
