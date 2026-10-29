# API de PropKit por pieza

Todo está en `addons/prop_kit/`. Los puntos del plano del suelo son `Vector2`: (x, z) en 3D, (x, y) en 2D.

## Scatter (`core/`, `scatter/`)

| Clase | Qué |
|---|---|
| `PropScatter3D` / `PropScatter2D` (@tool) | `rules`, `variants`, `ground`, `mask`, `keep_out`, `name_prefix`; «Scatter» / «Clear» (deshacibles en el editor). `scatter(scene_owner = null) -> int`, `clear()`, señal `scattered(count)` |
| `PropScatterRules` | `random_seed`, `cluster_size`, `cover`, `edge`, `density`, `lone_chance`, `spacing`, `scale_range`, `scale_jitter`, `keep_out_shrink`, `random_rotation`, `max_count`, `tries`, `sink`, `align_to_normal` |
| `PropGround` | Base: `begin(scatter) -> bool`, `bounds() -> Rect2`, `height_at(at)`, `normal_at(at)`, `weight_at(at)`, `editor_outline()` (lo que dibuja el editor). El suelo de un juego lo extiende con `@tool` |
| `PropFlatGround` | `area`, `outline`, `height` |
| `PropRayGround` (3D) | `area`, `collision_mask`, `max_slope_deg`, `top`, `bottom` |
| `PropMask` | `texture`, `area`, `density_channel`, `density_strength`, `density_invert`, `forbid_channel`, `forbid_above` |
| `PropKeepOut` | `group`, `radius`, `soft`; `PropKeepOut.discs(list, root, skip)` |
| `PropVariant` | `scene`, `weight`; `PropVariant.weights_of(list)` |
| `PropPlanner` | `plan(rules, ground, mask, discs, weights) -> Array[PropSpot]` (puro); `problems(rules, ground, variants)` |
| `PropSpot` | `at`, `scale`, `angle`, `variant`, `depth` |
| `PropScatterRun` | `run_all(scene) -> int` (`tools/scatter_scene.tscn`) |
| `tools/scatter_scene.tscn` | `godot --headless --path . res://addons/prop_kit/tools/scatter_scene.tscn -- --scene=res://… [--out=res://…]` |
| `tools/bake_scene.tscn` | `… res://addons/prop_kit/tools/bake_scene.tscn -- --scene=res://… [--check]`: hornea headless cada nodo de zonas (como corre el juego, autoloads incluidos); `--check` imprime un hash reproducible y sale con 1 si no coincide con el horneado guardado. «Bake» en el editor lo corre |

## Dibujo (`draw/`)

| Clase | Qué |
|---|---|
| `PropBatch3D` | `props` (padres), `chunk_size`, `build_on_ready`, `mesh_of: Callable(prop, part) -> Mesh`. `rebuild_all()`, `refresh(prop)`, `clear()`, `batch_count()`, `instance_count()`, `can_draw()` |

## Navmesh (`nav/`)

| Clase | Qué |
|---|---|
| `PropNavZones3D` / `PropNavZones2D` (@tool) | `navigation_mesh` / `navigation_polygon`, `source_root`, `zone_size`, `merge_gap`, `follow_props`; Saved: `saved`, `rebake_when_stale`, «Bake»; Advanced: `apply_mode` (AUTO / MANUAL), `area`, `zone_border`, `height_range` (3D: piso, techo; (0, 0) = según el parseo), `build_index`, `navigation_layers`, `use_edge_connections`, `obstruction_group`, `obstruction_sides`, `carve` |
| …métodos | `rebake(position, radius)` (Vector3 / Vector2: cambió el suelo o un edificio), `rebake_prop(prop)` (se movió), `rebake_all()`, `is_ready()`, `is_updating()`, `apply()`, `has_result()`, `region_of(zone)`, `grid()`, `to_saved()`, `save_bake(path)`; `stats`, `index`, `extra_fingerprint: Callable() -> int` (en cualquier momento) |
| …señales | `updated` (los caminos y `index` ven las últimas piezas), `bake_ready(zones)` (MANUAL: un cambio en el juego espera a `apply()`), `stale` |
| `PropObstructions` | `GROUP` (`prop_obstruction`), `nodes_under(root)`, `of_3d(node, sides)`, `of_2d(node, sides)`, `gather(nodes, is_3d, sides, within)`, `merged(list, gap, min_edge)`, `add_3d` / `add_2d(source, list, carve)`, `fingerprint(list)`, `area_of(node, is_3d)`, `touches(rect, within)` |
| `PropObstruction` | `outline`, `bottom`, `top`, `rect()` |
| `PropNavIndex` | `can_reach(a, b, max_distance = 0, min_area = 0)`, `closest_point(point, max_distance = INF, min_area = 0)` (`max_distance` en el plano del suelo; `min_area` saltea islas), `component_at(point, max_distance = 0, min_area = 0)`, `polygon_at`, `stitched(like)`, `stitched_2d(like)`; las llamadas `_2d`; `vertices`, `polygons`, `component_of`, `component_count`, `component_area`. `PropNavIndex.build(pieces, is_3d, weld)` |
| `PropNavBake` | `zone_size`, `area`, `border`, `pieces`, `fingerprint`; `content_hash()` |
| `PropNavStats` | `parse_ms`, `obstruct_ms`, `bake_ms`, `index_ms`, `zones_baked`, `zones_total`, `obstructions`, `polygons`, `components` |
| `PropZoneGrid` | `size`, `first`, `count`; `zone_count()`, `all()`, `area()`, `cell_of(zone)`, `zone_rect(zone)`, `zone_at(point)`, `zones_touching(rect)` |
| `PropZoneBaker` | El motor de los dos nodos de zonas (se usa a través de ellos) |
