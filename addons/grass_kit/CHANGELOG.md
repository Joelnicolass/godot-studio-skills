# GrassKit changelog

## 0.2.2

- **A ground painted in the game is freed.** `GrassGround` kept every painted or baked ground in a static list, so the editor would save it with the scene, in an exported game too. A ground painted in the game (burning grass with `ground.paint`) was never freed, and on quit that list crashed the process (exit 134 in the tests). Now only the editor keeps it, with weak references (`GrassGround.edited_grounds()`, `GrassGround.mark_saved()`).
- **Minimal example** `examples/minimal_3d/`: a floor with a collider, a field, the ground baked at start, and `floor.gdshader` with `grass_ground.gdshaderinc` so the floor meets the far grass. Space changes the look.
- **Tests:** 54. The runner fails a test that stops on a script error or made no check at all (it used to count it as a pass), and the process exits with 0.

Nothing to update in your project.

## 0.2.1

- **Bake the ground's colour** (asked by Sacrifice): `await field.bake_ground_color()`, or GrassKit ▸ **Bake ground colour** (undoable).
  - It renders the game's ground from above as `ground.color_texture`, the colour the blades' roots take: only the render layers in the new `ground.color_layers`, without light or fog, as the ground shows under the drawn grass. The field's own blades are hidden meanwhile.
  - `field.ground_bake_view` holds that view of GrassKit's shader globals for a game that renders its own.
  - `GrassGlobals.write_bake_view(look, ground)` writes it before any field draws, so a game never writes GrassKit's globals itself.
- **The same colours in Compatibility.** Compatibility takes `source_color` colours as they are, while GrassKit's shared colours are linear. In Compatibility, the ground under the grass and the far blades' meeting colour came out darker than in Forward+. `field/grass_color.gdshaderinc` converts them by `CURRENT_RENDERER`, so `grasskit_ground_color()` and the blades now give one colour in every renderer.
- **Example:** the walker and the camps are on render layer 2, so the colour bake sees the hills only.
- **Tests:** 52; the editor check (42) bakes from the menu; `checks/bake_color_check.gd` renders the bake in a window (soil on the path, grass colour on the meadow, in Forward+ and Compatibility).

## 0.2.0

Tools for doing it by hand, and the fixes Sacrifice's migration asked for.

- **Brushes in the 3D view.** Select a GrassField3D and the 3D view gets the **GrassKit** menu and four brushes on top, with their settings underneath:
  - **Grass**: where grass grows;
  - **Height**: how tall;
  - **Colour**: the ground's colour under the grass;
  - **Kind**: where a kind of blade grows.

  They paint the ground's own maps, the textures the field draws from.
  - Size, strength, falloff and noise (a ragged edge, fixed in the world); a pen's pressure.
  - Terrain3D's keys: Ctrl (Cmd) erases, Shift smooths, `[` `]` size, `-` `=` strength, Esc puts the brush down.
  - The grass follows the brush, the brush's circle lies on the ground, and the map can show over it.
  - Every stroke is one step of the editor's history. The maps are saved inside the ground with the scene.
- **The menu.** Bake ground, fit the area to the colliders, set up what is missing; fill, clear, import or export the brush's map as a PNG.
- **Handles.** The ground's area has a handle per side: what is painted stays where it is, and the new part is baked. A GrassClear3D has handles for its `radius` and `soft` edge. Every drag undoes.
- **Undo** for Bake ground, area changes, fills, imports, a kind's new name and the quality's presets.
- **Set-up.** A GrassField3D added in the editor sets itself up: a ground fitted to the scene's colliders, the meadow look, medium quality, a wind. When the scene has been saved, it also bakes. Use `set_up()` and `colliders_area()` from code.
- **GrassQuality.** **Low**, **Medium** and **High** buttons, and a live **cost** line in the inspector; `apply_preset()`.
- **Looks.** `looks/`: meadow, autumn, lush, steppe.
- **Painted maps.**
  - `GrassMap`: a texture that keeps its painted image and saves it, also headless.
  - From code: `GrassBrush`, and `GrassGround.paint()`, `fill_map()`, `clear_map()`, `import_map()`, `export_map()`, `map_region()` / `put_map()`.
  - `kind_maps` by a kind's new `GrassMesh.map_name`, so looks that share a name grow their kinds in the same places.
  - `paint_texel_size`.
  - `color_texture`'s alpha covers the look's ground colour.
- **Kinds that grow by a map add their blades** instead of taking a share of the others, so painting flowers thins nothing.
- **Cells skip what is painted out.** Nothing is drawn where the density map is empty, and a kind that grows by a map only where it is painted (the example's flowers: 31 draws instead of 46).
- **The ground under the grass** (from Sacrifice).
  - `grasskit_ground_color()` takes the game's ground to the grass's colour under the drawn blades, keeping some of its relief: `GrassLook.under_grass` and `under_relief`, in the new global `grasskit_under`. Up close the field no longer reads as shaded and patchy.
  - `grasskit_painted_grass(xz)` (globals `grasskit_density`, `grasskit_area`) lets the game's ground show its soil on a painted path.
- **`trample_recover`** (from Sacrifice): trampled grass stands up again over that many seconds, from a trail that fades. A body standing still keeps its spot pressed.
- **`GrassClear3D.changed`** (from Sacrifice): emitted when `radius` or `soft` changes.
- **`GrassGround.set_heights_image(image, rect)`** (from Sacrifice): heights from an image or a PackedFloat32Array. On 1 million texels it takes 0.3 s, against 1.4 s for `set_heights()`.
- **Also on `GrassGround`:**
  - `ray_hit()`: where a ray meets the ground (the brushes aim with it);
  - `resize_area()`, `layout()` / `set_layout()`;
  - `map_empty_in()`;
  - the `map_painted` signal.
- **The plugin** adds missing shader globals each time the editor starts, so an update brings its new ones.
- **Example:** a painted dirt path with short grass along it, flower patches, a dry patch, and trampled grass that stands up again; its ground shows soil on the path.
- **Tests:** 51, and an editor check of 41 that paints, undoes, saves, drags handles and sets a new field up.

## 0.1.0

- **GrassField3D**: grass around the camera on the GPU, in square cells that move with it.
  - Per kind of blade, one shared MultiMesh per tier, each tier a prefix of the same evenly spread blades, so nothing pops.
  - Each cell's bounds fit its ground, so the renderer culls it.
  - Centred on where the camera looks (never farther ahead than it is high), or on a `center` node.
  - `enabled` frees every cell. Nothing is drawn headless or on a dedicated server.
  - In the editor it follows the 3D view's camera within `editor_radius`.
  - `stats`: cells, blades, draws, in total, in view and by kind.
- **GrassGround**: the ground over `area`, in one float texture (height, normal, ground).
  - Baked from the colliders (exact heights) or written from the game's data (`set_heights`).
  - `slope_fade` thins and shortens grass on steep ground.
  - Painted `density_texture` and `size_texture`, and the ground's `color_texture`.
  - `area_changed` for a part changed in play, with the texture uploaded once a frame.
  - `bake_cost()`, and an inspector warning for a big bake.
- **GrassLook**: a `.tres` for each look (a biome, a season, a palette), all uniforms, so swapping looks rebuilds nothing.
  - Shape: heights 0.25 to 0.8 m, width, lean, `align_to_normal`, clumps.
  - Colour: base, tip, variation, the ground's tint, and a colour the far grass and the ground share.
  - Light: translucency, root shade, roundness, view thickening.
  - Wind: response, flutter, gust light.
- **GrassMesh**: kinds of blade mixed by weight (the kit's blade, or any mesh), each a prefix of its share.
  - Size, a mask of where it grows.
  - Albedo, normal and ORM textures, alpha scissor with cut shadows, tint, how much the palette applies, and bending from the vertex colour.
- **GrassWind**: the world's wind, shared through global shader uniforms.
  - Bands of seamless noise travel at its speed, and gusts crest them.
  - Changes blend in over `blend_time` and the pattern never jumps.
  - `time_override` freezes it; it holds with the pause.
  - `grass_wind.gdshaderinc` for any shader; `grass_ground.gdshaderinc` lets the game's ground meet the far grass's colour and carry the gusts' bands.
- **GrassQuality**: density, radius, near and far density, cells, tiers (8), segments (halved at each step out, blended before a switch), `min_blade_pixels`, `near_fade`, shadows; `preset()`, `blades_in_ring()`, `describe()`.
- **Clearings** by group (`GrassClearing`) and by hand (`GrassClear3D`, with its gizmo); **trampling** by group, each body its own width.
- **The blade shader**:
  - Early exits, cheapest first, with one read of the ground.
  - A cubic Bézier blade along the ground's normal, the wind's push and flutter, trampling.
  - LOD rows blended into the coarser shape, view-space thickening, rounded normals tending to the ground's.
  - Width never under `min_blade_pixels`; shorter near the lens and at the ring's edge.
  - No `instance uniform`. Forward+ and Compatibility.
- **Plugin**: gizmos, and GrassKit's shader globals added to Project Settings (only the missing ones).
- **Example** `grass_3d`: three looks (one with flowers), a storm, a crater, trampling, clearings, a ground shader that meets the grass. **Tests**: `grasskit_lab` (31), and an editor check (`GRASSKIT_EDITOR_CHECK=1`).
