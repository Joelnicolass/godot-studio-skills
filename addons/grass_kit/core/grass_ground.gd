@tool
class_name GrassGround
extends Resource

## Where grass grows and how high the ground is under it, over `area` (x, z in world metres). The
## height comes from the game's colliders: `bake()` casts a ray down every `texel_size` metres
## (the field's «Bake ground» button does it in the editor) and keeps, in one texture, the exact
## height where it hits, the ground's normal (blades stand along it) and where there is ground. A game with
## its own height data writes it instead with `set_heights(rect, sampler)`. Grass thins and
## shortens on steep ground (`slope_fade`). When the ground changes in play (a crater), bake or write
## only that rect: `area_changed` tells the field which part to redo. Without a bake the ground
## is flat at `flat_height`. Optional: a painted `density_texture` (white = grass, black = none)
## and the ground's own `color_texture`, both stretched over `area`.

## Part of the ground changed (heights or where grass grows): `rect` on the ground plane.
signal area_changed(rect: Rect2)

## The ground the grass covers (x, z), in world metres.
@export var area := Rect2(-50.0, -50.0, 100.0, 100.0)
## Metres between two baked heights. Smaller = closer to the ground's shape, bigger maps.
@export_range(0.1, 8.0, 0.05, "or_greater", "suffix:m") var texel_size := 0.5
## The physics layers `bake()` hits (the terrain's). Keep props and units out of it.
@export_flags_3d_physics var collision_mask := 1
## Grass thins and shortens from the first slope (x, degrees) and is gone past the second (y).
@export var slope_fade := Vector2(35.0, 55.0):
	set(value):
		slope_fade = value
		emit_changed()
## The ground's height where nothing is baked.
@export var flat_height := 0.0
## Painted (red): white = grass, black = none, grey thins it. Null = grass everywhere the ground
## allows.
@export var density_texture: Texture2D:
	set(value):
		density_texture = value
		emit_changed()
## Painted (red): how tall the blades grow there, 0.5 = as the look says, black = flat, white =
## twice (short grass on paths). Null = as the look says everywhere.
@export var size_texture: Texture2D:
	set(value):
		size_texture = value
		emit_changed()
## The ground's colour over `area`, mixed into the blades' base and into the far grass. Any texture
## the game makes: its albedo map, or its ground shader rendered once from above. Another one in
## play (another biome) only changes a uniform.
@export var color_texture: Texture2D:
	set(value):
		color_texture = value
		emit_changed()

## The baked ground, one texel per `texel_size`: height (red), the normal's x and z (green, blue),
## and 1 where a ray found ground (alpha). One texture, so a blade reads it all at once. Null = flat.
@export_storage var data: Image

var _texture: ImageTexture
var _upload_queued := false


## Texels across `area`.
func texture_size() -> Vector2i:
	return Vector2i(
		maxi(ceili(area.size.x / texel_size), 1), maxi(ceili(area.size.y / texel_size), 1)
	)


## Casts a ray down at every texel of `rect` (empty = all of `area`) in `space` against
## `collision_mask`, from `top` to `bottom`. Returns how many texels found ground.
func bake(
	space: PhysicsDirectSpaceState3D, rect := Rect2(), top := 1000.0, bottom := -1000.0
) -> int:
	_ensure_data()
	var span := _texels_in(rect if rect.has_area() else area)
	var query := PhysicsRayQueryParameters3D.new()
	query.collision_mask = collision_mask
	var found := 0
	for ty in range(span.position.y, span.end.y):
		for tx in range(span.position.x, span.end.x):
			var at := _texel_center(tx, ty)
			query.from = Vector3(at.x, top, at.y)
			query.to = Vector3(at.x, bottom, at.y)
			var hit := space.intersect_ray(query)
			if hit.is_empty():
				data.set_pixel(tx, ty, Color(flat_height, 0.0, 0.0, 0.0))
				continue
			found += 1
			var normal: Vector3 = hit["normal"]
			var y := (hit["position"] as Vector3).y
			data.set_pixel(tx, ty, Color(y, normal.x, normal.z, 1.0))
	_changed(_rect_of(span))
	return found


## Writes the heights of `rect` from the game's own data: `sampler` is `func(x, z) -> float` in
## world metres (NAN = no ground there). The normals come from the heights themselves.
func set_heights(rect: Rect2, sampler: Callable) -> void:
	_ensure_data()
	var span := _texels_in(rect)
	for ty in range(span.position.y, span.end.y):
		for tx in range(span.position.x, span.end.x):
			var at := _texel_center(tx, ty)
			var h: float = sampler.call(at.x, at.y)
			var found := 0.0 if is_nan(h) else 1.0
			data.set_pixel(tx, ty, Color(flat_height if is_nan(h) else h, 0.0, 0.0, found))
	# A normal needs its neighbours, so one texel more around.
	var grown := Rect2i(span.position - Vector2i.ONE, span.size + Vector2i(2, 2))
	grown = grown.intersection(Rect2i(Vector2i.ZERO, texture_size()))
	for ty in range(grown.position.y, grown.end.y):
		for tx in range(grown.position.x, grown.end.x):
			var texel := data.get_pixel(tx, ty)
			var normal := _normal_from_heights(tx, ty)
			data.set_pixel(tx, ty, Color(texel.r, normal.x, normal.z, texel.a))
	_changed(_rect_of(grown))


## The height at `at` (x, z), between the baked texels.
func height_at(at: Vector2) -> float:
	if data == null:
		return flat_height
	return _sample(at).r


## The ground's normal at `at`, between the baked texels (up where nothing is baked).
func normal_at(at: Vector2) -> Vector3:
	if data == null:
		return Vector3.UP
	var texel := _sample(at)
	var xz := Vector2(texel.g, texel.b)
	return Vector3(xz.x, sqrt(maxf(1.0 - xz.length_squared(), 0.0)), xz.y)


## True where the bake found ground at `at` (or it is flat and inside `area`).
func has_ground(at: Vector2) -> bool:
	if not area.has_point(at):
		return false
	return data == null or _sample(at).a > 0.5


## The slope at `at` in degrees.
func slope_at(at: Vector2) -> float:
	return rad_to_deg(acos(clampf(normal_at(at).y, -1.0, 1.0)))


## How much grass the slope at `at` leaves (1 below `slope_fade.x`, 0 past `slope_fade.y`): the
## part the shader keeps there, and how tall.
func slope_keep(at: Vector2) -> float:
	return 1.0 - smoothstep(slope_fade.x, slope_fade.y, slope_at(at))


## The lowest (x) and highest (y) ground in `rect`: what a cell's bounds need.
func height_range_in(rect: Rect2) -> Vector2:
	if data == null:
		return Vector2(flat_height, flat_height)
	var span := _texels_in(rect.grow(texel_size))
	if span.size.x <= 0 or span.size.y <= 0:
		return Vector2(flat_height, flat_height)
	var low := INF
	var high := -INF
	for ty in range(span.position.y, span.end.y):
		for tx in range(span.position.x, span.end.x):
			var h := data.get_pixel(tx, ty).r
			low = minf(low, h)
			high = maxf(high, h)
	return Vector2(low, high)


## The ground as a texture for the shader (updated when the ground changes).
func ground_texture() -> Texture2D:
	if data == null:
		var flat := Image.create(1, 1, false, Image.FORMAT_RGBAF)
		flat.set_pixel(0, 0, Color(flat_height, 0.0, 0.0, 1.0))
		return ImageTexture.create_from_image(flat)
	if _texture == null:
		_texture = ImageTexture.create_from_image(data)
	return _texture


## What a bake of all of `area` costs: [rays, megabytes kept].
func bake_cost() -> Vector2:
	var size := texture_size()
	var texels := float(size.x) * size.y
	# Four floats a texel: height, normal x and z, ground.
	return Vector2(texels, texels * 16.0 / 1048576.0)


## The ground changed in `rect`: the field hears it now; the texture goes to the GPU once at the
## end of the frame, however many changes it had (a spiral of craters).
func _changed(rect: Rect2) -> void:
	if not _upload_queued:
		_upload_queued = true
		_upload.call_deferred()
	area_changed.emit(rect)


func _upload() -> void:
	_upload_queued = false
	if _texture != null:
		_texture.update(data)


func _ensure_data() -> void:
	var size := texture_size()
	if data == null or data.get_size() != size:
		data = Image.create(size.x, size.y, false, Image.FORMAT_RGBAF)
		data.fill(Color(flat_height, 0.0, 0.0, 1.0))
		_texture = null


## The texels whose centres fall in `rect`.
func _texels_in(rect: Rect2) -> Rect2i:
	var size := texture_size()
	var cell := area.size / Vector2(size)
	var low := ((rect.position - area.position) / cell - Vector2(0.5, 0.5)).ceil()
	var high := ((rect.end - area.position) / cell - Vector2(0.5, 0.5)).floor() + Vector2.ONE
	var span := Rect2i(Vector2i(low), Vector2i(high - low))
	return span.intersection(Rect2i(Vector2i.ZERO, size))


func _rect_of(span: Rect2i) -> Rect2:
	var cell := area.size / Vector2(texture_size())
	return Rect2(area.position + Vector2(span.position) * cell, Vector2(span.size) * cell)


func _texel_center(tx: int, ty: int) -> Vector2:
	var cell := area.size / Vector2(texture_size())
	return area.position + (Vector2(tx, ty) + Vector2(0.5, 0.5)) * cell


func _texel(tx: int, ty: int) -> Color:
	var size := texture_size()
	return data.get_pixel(clampi(tx, 0, size.x - 1), clampi(ty, 0, size.y - 1))


## The baked texel at `at`, between the texels (as the shader's linear filter reads it).
func _sample(at: Vector2) -> Color:
	var size := texture_size()
	var texel := (at - area.position) / area.size * Vector2(size) - Vector2(0.5, 0.5)
	var low := Vector2i(floori(texel.x), floori(texel.y))
	var t := texel - Vector2(low)
	var top := _texel(low.x, low.y).lerp(_texel(low.x + 1, low.y), t.x)
	var bottom := _texel(low.x, low.y + 1).lerp(_texel(low.x + 1, low.y + 1), t.x)
	return top.lerp(bottom, t.y)


## The normal at a texel, from its neighbours' heights.
func _normal_from_heights(tx: int, ty: int) -> Vector3:
	var cell := area.size / Vector2(texture_size())
	var dx := (_texel(tx + 1, ty).r - _texel(tx - 1, ty).r) / (2.0 * cell.x)
	var dz := (_texel(tx, ty + 1).r - _texel(tx, ty - 1).r) / (2.0 * cell.y)
	return Vector3(-dx, 1.0, -dz).normalized()
