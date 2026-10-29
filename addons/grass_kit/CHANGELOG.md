# GrassKit changelog

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
