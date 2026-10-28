# API de PropKit por pieza

Todo está en `addons/prop_kit/`. Los puntos del plano del suelo son `Vector2`: (x, z) en 3D, (x, y) en 2D.

## Scatter (`core/`, `scatter/`)

| Clase | Qué |
|---|---|
| `PropScatter3D` / `PropScatter2D` (@tool) | `rules`, `variants`, `ground`, `mask`, `keep_out`, `name_prefix`; «Scatter» / «Clear». `scatter(scene_owner = null) -> int`, `clear()`, señal `scattered(count)` |
| `PropScatterRules` | `random_seed`, `cluster_size`, `cover`, `edge`, `density`, `lone_chance`, `spacing`, `scale_range`, `scale_jitter`, `keep_out_shrink`, `random_rotation`, `max_count`, `tries`, `sink`, `align_to_normal` |
| `PropGround` | Base: `begin(scatter) -> bool`, `bounds() -> Rect2`, `height_at(at)`, `normal_at(at)`, `weight_at(at)`. El suelo de un juego lo extiende con `@tool` |
| `PropFlatGround` | `area`, `outline`, `height` |
| `PropRayGround` (3D) | `area`, `collision_mask`, `max_slope_deg`, `top`, `bottom` |
| `PropMask` | `texture`, `area`, `density_channel`, `density_strength`, `density_invert`, `forbid_channel`, `forbid_above` |
| `PropKeepOut` | `group`, `radius`, `soft`; `PropKeepOut.discs(list, root, skip)` |
| `PropVariant` | `scene`, `weight`; `PropVariant.weights_of(list)` |
| `PropPlanner` | `plan(rules, ground, mask, discs, weights) -> Array[PropSpot]` (puro); `problems(rules, ground, variants)` |
| `PropSpot` | `at`, `scale`, `angle`, `variant`, `depth` |
| `PropScatterRun` | `run_all(scene) -> int` (menú Herramientas, `tools/scatter_scene.gd`) |
| `tools/bake_scene.gd` | `-- --scene=res://… [--check]`: hornea headless cada nodo de zonas; `--check` imprime un hash reproducible y sale con 1 si no coincide con el horneado guardado |

## Dibujo (`draw/`)

| Clase | Qué |
|---|---|
| `PropBatch3D` | `props` (padres), `chunk_size`, `build_on_ready`, `mesh_of: Callable(prop, part) -> Mesh`. `rebuild_all()`, `refresh(prop)`, `clear()`, `batch_count()`, `instance_count()`, `can_draw()` |

## Navmesh (`nav/`)

| Clase | Qué |
|---|---|
| `PropNavZones3D` / `PropNavZones2D` (@tool) | `navigation_mesh` / `navigation_polygon`, `source_root`, `zone_size`, `zone_border`, `area`, `apply_mode` (AUTO / MANUAL), `build_index`, `navigation_layers`, `use_edge_connections`, `obstruction_group`, `obstruction_sides`, `merge_gap`, `carve`, `saved`, `rebake_when_stale`; «Bake» |
| …métodos | `rebake(areas, reparse = true)`, `rebake_all(reparse = true)`, `apply()`, `is_done()`, `has_result()`, `is_synced()`, `region_of(zone)`, `grid()`, `to_saved()`, `save_bake(path)`, `bake_and_save()` (editor); `stats`, `index`, `extra_fingerprint: Callable() -> int` |
| …señales | `bake_ready(zones)`, `applied(zones)`, `synced`, `stale` |
| `PropObstructions` | `GROUP` (`prop_obstruction`), `nodes_under(root)`, `of_3d(node, sides)`, `of_2d(node, sides)`, `gather(nodes, is_3d, sides, within)`, `merged(list, gap)`, `add_3d` / `add_2d(source, list, carve)`, `fingerprint(list)`, `area_of(node, is_3d)`, `touches(rect, within)` |
| `PropObstruction` | `outline`, `bottom`, `top`, `rect()` |
| `PropNavIndex` | `polygon_at`, `component_at`, `same_component`, `closest_point` (y `_2d`), `stitched(like)`, `stitched_2d(like)`; `vertices`, `polygons`, `component_of`, `component_count`. `PropNavIndex.build(pieces, is_3d, weld)` |
| `PropNavBake` | `zone_size`, `area`, `border`, `pieces`, `fingerprint`; `content_hash()` |
| `PropNavStats` | `parse_ms`, `obstruct_ms`, `bake_ms`, `index_ms`, `zones_baked`, `zones_total`, `obstructions`, `polygons`, `components` |
| `PropZoneGrid` | `size`, `first`, `count`; `zone_count()`, `all()`, `area()`, `cell_of(zone)`, `zone_rect(zone)`, `zone_at(point)`, `zones_touching(rect)` |
| `PropZoneBaker` | El motor de los dos nodos de zonas (se usa a través de ellos) |
