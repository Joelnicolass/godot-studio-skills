# API de GrassKit por pieza

Todo está en `addons/grass_kit/`. Los puntos del plano del suelo son `Vector2` (x, z) en metros del mundo.

| Clase | Qué |
|---|---|
| `GrassField3D` (@tool) | `ground`, `look`, `quality`, `wind`, `enabled`; «Bake ground»; Clearings: `clearings`; Trampling: `trample_group`, `trample_radius`; Camera: `camera`, `center`; Editor: `editor_preview`, `editor_radius`. `bake_ground() -> int`, `ground_changed(at: Vector3, radius)`, `refresh_clearings()`, `can_draw()`; `stats` (GrassStats); estático `draw_anywhere` (tests); constantes `SHADER`, `CUT_SHADER` |
| `GrassGround` | `area`, `texel_size`, `collision_mask`, `slope_fade` (grados), `flat_height`, `density_texture`, `size_texture`, `color_texture`; horneado `data` (RGBA float: altura, normal x, normal z, suelo). `bake(space, rect = todo) -> int`, `set_heights(rect, sampler)`, `height_at(at)`, `normal_at(at)`, `has_ground(at)`, `slope_at(at)`, `slope_keep(at)`, `height_range_in(rect)`, `ground_texture()`, `bake_cost() -> Vector2` (rayos, MB), `texture_size()`; señal `area_changed(rect)` |
| `GrassLook` | Forma: `height_range`, `width`, `tip_width`, `lean`, `align_to_normal`, `clump_size`. Color: `base_color`, `tip_color`, `color_variation`, `ground_tint`, `ground_color`, `fade_to_ground`, `roughness`. Luz: `translucency`, `root_shade`, `roundness`, `view_thicken`. Viento: `wind_response`, `flutter`, `gust_lighten`. Distancia: `far_grass`. Mallas: `meshes: Array[GrassMesh]`. `kinds()`, `build_key()`, `average_color()`, `apply_to(material)` |
| `GrassMesh` | `mesh` (null = la hoja del kit), `weight`, `size`, `mask_texture`; Material: `albedo_texture`, `normal_texture`, `orm_texture`, `alpha_scissor`, `tint`, `palette`, `bend_from_color`. `build_key()` |
| `GrassWind` | `direction`, `strength`, `speed`, `scale`, `noise`, `blend_time`, `time_override`; `current_direction`, `current_strength`, `offset`, `time`. `tick(delta)` (una vez por frame), `write()`, estático `write_calm()` |
| `GrassQuality` | `density`, `radius`, `near_radius`, `far_density`, `cell_size`, `tiers`, `segments`, `min_blade_pixels`, `near_fade`, `cast_shadows`. estático `preset(Level.LOW / MEDIUM / HIGH)`; `density_at(distance)`, `blades_per_cell()`, `tier_starts()`, `tier_at(distance)`, `blades_in_tier(tier)`, `segments_in_tier(tier)`, `morph_ends()`, `ring_margin()`, `blades_in_ring()`, `describe()` |
| `GrassClearing` | `group`, `radius`, `soft` |
| `GrassClear3D` | `radius`, `soft` (gizmo en el editor) |
| `GrassStats` | `cells`, `blades`, `cells_in_view`, `blades_in_view`, `draws`, `blades_by_kind`; se imprime en una línea |
| `GrassGlobals` | Los globales de shader (`ALL`); estáticos `declare()`, `add_to_project()` |
| `GrassCells` | estáticos `around(center, radius, size) -> Dictionary[Vector2i, float]`, `rect_of(cell, size)` |
| `GrassBlades` | estáticos `points(count, size)`, `kinds_of(count, weights)`, `instance_buffer(points, count, kinds, kind, segments)`, `blade_mesh(segments)`, `tier_meshes(quality, kinds)` |
| `field/grass.gdshader`, `field/grass_cut.gdshader` | Las hojas, opacas y con alpha scissor (el cuerpo está en `grass_body.gdshaderinc`) |
| `field/grass_wind.gdshaderinc` | Para cualquier shader: `grasskit_wind_wave(xz)`, `grasskit_wind_gust(xz)`, `grasskit_wind_push(xz)` |
| `field/grass_ground.gdshaderinc` | Para el suelo del juego: `grasskit_ground_color(rgb, xz, grass_here)`, `grasskit_ground_bands(xz, amount)` |
