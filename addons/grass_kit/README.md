# GrassKit

Grass for 3D worlds, drawn on the GPU around the camera:
- **Painted by hand:** brushes in the 3D view paint where grass grows, how tall, the ground's colour under it and where each kind of blade grows (flowers). Every stroke undoes.
- **Cells:** the blades stand in square cells that move with the camera.
- **Distance:** near cells hold more blades, far ones fewer and wider, and nothing pops.
- **The ground:** read from the game's colliders: exact heights, the slope, and the normal the blades grow along.
- **The wind:** a shared wind moves them, and the game's ground, trees or particles can read the same wind.
- **The blades:** the kit's own blade, or any mesh with PBR textures, mixed by weight.

There is no network, no game rule and no autoload, and GrassKit depends on no other kit.

```bash
./install.sh --addon /path/to/godot-project grass_kit
```

Enable the **GrassKit** plugin. It brings the tools in the 3D view, and adds GrassKit's global shader uniforms to Project Settings (only the ones missing, also after an update). The nodes work without it.

**Example:** `examples/grass_3d/grass_3d.tscn`. Hills of grass with:
- a dirt path painted with the brushes, short grass along it, flower patches and a dry patch;
- a walker trampling a path that stands up again behind it;
- camps cleared by group, and a hand-placed clearing;
- a mound too steep for grass;
- a ground that meets the grass, near and far.

Keys:
- **1 2 3:** quality.
- **L:** the next look (summer, autumn, flowers).
- **T:** a storm rising or calming.
- **G:** grass off and on.
- **C:** a crater under the mouse.

## Start

1. **Add a GrassField3D** to the world, at the origin. It sets itself up:
   - a ground fitted to the scene's colliders;
   - the meadow look;
   - medium quality;
   - a wind.

   When the scene has been saved, it also bakes the ground. Otherwise use **GrassKit ▸ Bake ground** once it is saved. The grass shows around the 3D view's camera.
2. **Select it.** The 3D view gets the **GrassKit** menu and four brushes on top, and the brush's settings underneath.
3. **Paint.** Pick a brush and paint on the ground; Ctrl (Cmd on a Mac) erases. The grass follows the brush, so you see what you paint wherever it is.
4. **Save the scene.** The painted maps are kept inside the ground's file, `<scene>_grass_ground.res`.

To change the look, pick another `.tres` from `addons/grass_kit/looks/` (meadow, autumn, lush, steppe) or duplicate one and edit it. To change the cost, press **Low**, **Medium** or **High** in the quality's inspector and read the cost line under the buttons.

## Paint by hand

| Brush | Paints | Ctrl (Cmd) |
|---|---|---|
| **Grass** | Where grass grows (a path, a bare patch) | No grass |
| **Height** | How tall it grows: the bar's **Height** against the look's (0.5 = half as tall) | Back to the look's height |
| **Colour** | The ground's colour under the grass, in the bar's colour picker | Back to the look's ground colour |
| **Kind** | Where the kind picked in the bar grows (flowers among the blades) | Not here |

**Shift** smooths any map under the brush.

The bar under the 3D view:
- **Size**, **Strength** (how far one dab goes), **Falloff** (how much of the radius fades out).
- **Noise**: a ragged edge, fixed in the world, so going over a place grows one natural patch.
- **Erase**: erase without holding Ctrl.
- **Map**: shows the brush's map over the ground. Green has grass and red has none; blue is shorter, orange taller; the colour itself; magenta where the kind grows.
- The map's size and the blades in view.

A tablet pen's pressure scales the strength.

| Key over the 3D view | Does |
|---|---|
| Left button | Paint |
| Ctrl / Cmd + left button | Erase |
| Shift + left button | Smooth |
| `[` `]` | Brush smaller, bigger |
| `-` `=` | Strength down, up |
| Esc | Put the brush down (the view selects again) |

These are the keys Terrain3D uses, so they will be familiar.

**The GrassKit menu:**
- **Bake ground**.
- **Fit area to the colliders**: the area follows the scene's colliders. What is painted stays where it is, and the new parts are baked.
- **Set up what is missing**.
- For the brush's map:
  - **Fill** with the brush's value: no grass everywhere when Erase is on, then paint where it grows;
  - **Clear**: back to never painted;
  - **Import from a PNG…**;
  - **Export to a PNG…**, to edit it in Krita or Photoshop and import it back.
- **Bake ground colour**: renders the game's ground from above as `color_texture` (below).
- **Show the painted map**, and **Shortcuts**.

**Handles in the 3D view:**
- The ground's area has a handle on each side. Dragging one moves that side, keeps what is painted where it is, and bakes the new part.
- A `GrassClear3D` has handles for its `radius` and its `soft` edge.

Every stroke, fill, import, bake, area change and handle drag is one step of the editor's history (Ctrl+Z, Ctrl+Shift+Z). Project ▸ Tools ▸ **GrassKit: Bake the open scene** bakes every field of the scene.

**Where the maps live.** A map is a `GrassMap`: a texture that keeps its painted image and saves it inside the ground's file. A texture made elsewhere also works: set `density_texture`, `size_texture`, `color_texture` or a `kind_maps` entry in the inspector. The first stroke over it paints a copy kept in the ground, and the file stays as it was. A new map has `paint_texel_size` metres a texel (0.25 by default, never more than 2048 a side).

## In the game

| You want to | Write |
|---|---|
| Swap the biome, season or a god's palette | `field.look = autumn` (a `.tres`), or `field.look.tip_color = …`: uniforms only |
| Raise a storm | `field.wind.strength = 1.3`, `field.wind.direction = …`: it blends in over `blend_time` |
| Let the player pick a quality | `field.quality = GrassQuality.preset(GrassQuality.Level.LOW)` |
| Turn grass off from the options | `field.enabled = false`: every cell is freed |
| A crater or a mound changed the ground | `field.ground_changed(position, radius)`: reads the colliders again there |
| Write the ground from the game's own data | `field.ground.set_heights_image(heights)` (red = metres), or `set_heights(rect, func(x, z): return terrain.height_at(x, z))` |
| Burn or wear the grass in play | `field.ground.paint(GrassGround.DENSITY, Vector2(x, z), brush)` with a `GrassBrush` (`mode = GrassBrush.Mode.ERASE`) |
| Clear grass around buildings or spawns | `clearings`: a `GrassClearing` {group, radius, soft}; or a `GrassClear3D` node (its `changed` signal tells the game) |
| Let units push the grass aside | `trample_group`, `trample_radius` (or `grass_trample_radius` on the unit), `trample_recover` (s) for it to stand up again |
| Centre the grass on what an RTS camera follows | `field.center = unit` |
| Aim at the grass with the mouse | `field.ground.ray_hit(camera.project_ray_origin(at), camera.project_ray_normal(at))` |
| Move trees, particles or the ground with the same wind | `#include "res://addons/grass_kit/field/grass_wind.gdshaderinc"` |
| Make the ground meet the grass, and show soil on a painted path | `#include "res://addons/grass_kit/field/grass_ground.gdshaderinc"` |
| See what it costs | `print(field.stats)`, `field.quality.describe()` |

## The ground (`GrassGround`)

Where grass grows and how high the ground is, over `area`.

- **Heights.**
  - `bake()` (Bake ground, or `field.bake_ground()` from code) casts a ray down at every texel against `collision_mask`. It keeps the exact height, the ground's normal and whether there was ground, all in one float texture (`data`), so a blade reads it once.
  - A game with its own height data writes it with `set_heights_image(image, rect)`: the image's red is the height in metres, NAN where there is no ground. Heights in a PackedFloat32Array make an image with `Image.create_from_data(w, h, false, Image.FORMAT_RF, heights.to_byte_array())`. On 1 million texels it takes about 0.3 s, against 1.4 s for `set_heights(rect, sampler)`, which calls `func(x, z) -> float` per texel.
- **Resolution.** Keep `texel_size` at most a quarter of the terrain's triangles, and a root sits within 5 cm of the exact ground, even on rough, steep slopes (`test_roots_sit_on_the_ground` measures it at 30° and 60°). On a plane the reading is exact at any slope; the error only comes from the creases between triangles.
- **Size.** `bake_cost()` says how many rays a full bake casts and how many megabytes it keeps (16 bytes a texel), and the inspector warns above 64 MB. A 2560 m map at 0.5 m is 26 million rays and 400 MB; at 2.5 m it is 16 MB.
- **Slopes.** `slope_fade` (degrees): from the first, blades thin and shorten; past the second, none. Blades grow along the ground's normal at their base (`look.align_to_normal`) and turn up towards the tip. Their width lies on the slope, so no base sinks into a hillside.
- **Painted maps**, stretched over `area` (the brushes paint them; `paint()`, `fill_map()`, `clear_map()`, `import_map()`, `export_map()` from code):
  - `density_texture` (red): white = grass, black = none.
  - `size_texture` (red): 0.5 = as the look says, black = flat, white = twice as tall.
  - `color_texture`: the ground's colour, which goes into the blades' base. Its alpha is how much it covers the look's `ground_color`. It should be the ground **as it shows with GrassKit's colour under the grass** (below), so the roots match what shows between them:
    - **GrassKit ▸ Bake ground colour**, or `await field.bake_ground_color()`, renders it from above. It sees the render layers in `color_layers` (keep props, units and trees off them), without light or fog, and with the field's own blades hidden.
    - A game that renders its own view sets `field.ground_bake_view = true` around that render. Before any field draws, it calls `GrassGlobals.write_bake_view(look, ground)`. Either way the game's ground shader shows the colour under the grass, and the game never writes GrassKit's globals itself.
    - Any other texture works too, such as the game's albedo map.
  - `kind_maps`: where each kind with a `map_name` grows (red).
- **Moving the area.** `resize_area(rect)` moves its edges keeping the heights and the maps where they are in the world. It is what Fit area and the handles use.
- **Changes in play.** Baking or writing heights emits `area_changed(rect)` at once. The field gives new bounds only to the cells there. Painting emits `map_painted(map)`. Either way, the textures go to the GPU once at the end of the frame, however many changes they had.

## The look (`GrassLook`)

A `.tres` to duplicate and edit in the inspector; a game keeps several (a meadow, a desert, snow, flowers) and swaps them in play. `looks/` has four to start from: meadow, autumn, lush and steppe.

- **Shape:** `height_range` (0.25 to 0.8 m by default, right for an RTS), `width`, `tip_width`, `lean`, `align_to_normal`, `clump_size`. Blades in a clump are taller near its heart, lean out of it and share its shade.
- **Colour:**
  - `base_color` and `tip_color`, with `color_variation`;
  - `ground_tint` (how much of the ground's colour shows at the base) and `ground_color` (where the ground has no colour map);
  - `fade_to_ground` and `far_grass` (where the far grass and the game's ground meet, below);
  - `roughness`.
- **Light:** `translucency` (light through the blades from behind, more at the thin tip), `root_shade`, `roundness` (a blade's normal turns out at its edges), `view_thicken` (blades seen edge-on widen, so a field never looks thin from the side).
- **Wind:** `wind_response`, `flutter` (each blade's own shiver across the wind), `gust_lighten` (gusts lighten the tips and their shine, so waves read from far away).
- **Ground under the grass:**
  - `under_grass` (0.6): how much the game's ground takes the grass's colour under the drawn blades, so what shows between them reads as more grass, not bare mottled ground;
  - `under_relief` (0.35): how much of the ground's own light and dark it keeps there.
- **Meshes:** the kinds of blade (below).

Every value is a shader uniform: another look, or a changed value, rebuilds nothing. Only other meshes, or other weights, build the field's meshes again.

## Kinds of blade (`GrassMesh`)

`look.meshes` mixes kinds of blade by `weight`: say 90 % the kit's blade, 8 % a tuft, 2 % a flower. Empty means the kit's blade alone.

- **The mesh.** `mesh` is any mesh, such as a `.glb` from Blender: y up, the root at y 0. It is scaled to the look's blade height (times `size`) and turned at random. Its base grows along the ground's normal and its tip stays upright. The wind and trampling bend it more the higher a vertex is, or by its vertex colour's red with `bend_from_color`. Empty = the kit's blade, a cubic Bézier curve.
- **Material.**
  - `albedo_texture`, `normal_texture`, `orm_texture` (occlusion, roughness, metallic);
  - `tint`;
  - `alpha_scissor` for cut-out petals or cards. It uses the cut shader, and the blade's shadow is cut too. Keep it 0 for plain blades: opaque costs less.
- **The palette.** `palette` is how much the look's colours tint the kind: 1 for blades, 0 for a flower with its own colours.
- **Where.**
  - `map_name` is the name of the ground's painted map for this kind. The **Kind** brush paints it, and names the kind on its first stroke. Looks that share a name grow their kinds in the same places, such as flowers in summer and in autumn. A name with no map painted yet grows everywhere.
  - `mask_texture` is a texture of its own (red over the ground's area), used when the ground has no map by that name.
- **How they share the blades.**
  - Kinds that grow everywhere split one shared sequence by a fixed roll on their weights, so each is a prefix of its own share and the density still changes smoothly with distance.
  - A kind that grows by a map has points of its own and adds its share where it grows: painting flowers leaves the rest of the meadow as dense.
  - A cell draws such a kind only where its map is painted.
- **To copy:** `examples/grass_3d/flower.tres` is a flower made this way: `flower_mesh.tres`, `flower_petals.png`, alpha scissor 0.5, palette 0, `map_name` "flower". The example's flowers look grows it in the painted patches.

## The wind (`GrassWind`)

The world's wind, shared: the field ticks it, and any shader can read it.

- **Settings:** `direction`, `strength` (0 calm, 1 a storm), `speed` (how fast the bands travel), `scale` (a band's size) and `noise` (a seamless texture; empty = the kit's).
- **No jumps.** The pattern's position is carried frame by frame, so a new direction or speed never makes the field jump. A new direction or strength is reached over `blend_time`.
- **Frozen.** `time_override` (0 or more) freezes it, for tests and screenshots.
- **Pause.** It moves with the field's processing, so it holds while the tree is paused (default process mode). Set the field to process always to keep it blowing.
- **Shared.** Several fields can share one wind; it moves once a frame.
- **In the blades.** A steady breeze plus gusts where the noise's bands crest. Each blade also shivers across the wind at its own phase, and gusts lighten the tips they pass.
- **For other shaders.** `field/grass_wind.gdshaderinc` gives `grasskit_wind_wave(xz)` (0..1), `grasskit_wind_gust(xz)` and `grasskit_wind_push(xz)`.

## The game's ground (`grass_ground.gdshaderinc`)

Include it in the game's ground shader so the ground and the grass meet without a seam:

```glsl
#include "res://addons/grass_kit/field/grass_ground.gdshaderinc"
...
float grass = grasskit_painted_grass(xz);          // the painted density map: 0 on a path
vec3 ground = mix(soil, ground_color, smoothstep(0.1, 0.7, grass));
ALBEDO = grasskit_ground_color(ground, xz, grass) * (1.0 + grasskit_ground_bands(xz, 0.12));
```

- `grasskit_ground_color(rgb, xz, grass_here)`:
  - under the drawn blades, the ground takes the grass's colour by the look's `under_grass` and keeps `under_relief` of its own light and dark;
  - from where the blades fade, it goes to the colour the far grass fades to, so the edge of the drawn grass never shows.
- `grasskit_painted_grass(xz)`: where the ground's density map grows grass (1 where nothing is painted, 0 outside the area). A path painted with the Grass brush can show the game's own soil.
- `grasskit_ground_bands(xz, amount)`: pale bands where the gusts cross the ground.

The example's hills use all three.

The values are global shader uniforms:
- `grasskit_wind`, `grasskit_wind_offset`, `grasskit_wind_time`, `grasskit_wind_noise`;
- `grasskit_field`, `grasskit_grass`, `grasskit_under`;
- `grasskit_density`, `grasskit_area`.

The plugin adds the missing ones to Project Settings each time the editor starts and touches no other. Disabling it leaves them, in case a game shader reads them. Without the plugin, a field declares them before its own shaders compile. One field per world writes them.

**Every renderer, one colour.** GrassKit's shared colours are linear. Forward+ and Mobile shade in linear, while Compatibility takes `source_color` colours and ALBEDO as they are. `grasskit_ground_color()` and the blades convert by `CURRENT_RENDERER` (`field/grass_color.gdshaderinc`), so the ground under the grass and the far grass are the same colour in all three.

## The quality (`GrassQuality`)

| Setting | What it does |
|---|---|
| `density` | Blades per m² near the centre |
| `radius`, `near_radius`, `far_density` | Full density up to `near_radius`, thinning to `far_density` at `radius`, none past it |
| `cell_size`, `tiers` | Cells of the ring, and how many sets of fewer blades by distance |
| `segments` | The nearest blades' segments (1, 2, 4 or 8), halved at each step out down to one triangle |
| `min_blade_pixels` | Far blades widen rather than shrink under this many pixels (no shimmer) |
| `near_fade` | Blades this close to the lens shrink to the ground, so none fills the screen |
| `cast_shadows` | Blades cast shadows |

In the inspector, the **Low**, **Medium** and **High** buttons set a preset (one undoable step), and the **cost** line under them says what a ring instances while you tune. From code: `preset(LOW | MEDIUM | HIGH)`, `apply_preset()`, `blades_in_ring()`, `describe()`.

`field.stats` (GrassStats) counts what is drawn now:
- cells and blades, in total and in view;
- the blades in view of each kind;
- the draw calls (one per kind per cell in view: a kind added to a look adds a draw per cell where it grows).

The blades are instanced, so their vertex shader runs whether or not the shader then thins them; the ones in view are what the GPU pays for.

## Smooth changes

No change with distance or in play is a step:

- **Density:** a blade goes when its rank passes the density. It is the same blade in every tier, so fewer blades never pop, and the ones left widen.
- **Segments:** before a cell switches to a mesh with half as many, each row the coarser mesh lacks has blended into its neighbours.
- **The edge:** blades shorten to nothing at the radius.
- **Colour at distance:** blades fade to a colour between the ground's and the grass's (`GrassLook.average_color()`). The game's ground fades to the same one, and takes the grass's colour under the drawn blades, so the grass and the ground meet seamlessly near and far.
- **The wind:** carried and blended, never restarted.
- **Painting:** a brush's falloff and noise make soft, ragged edges; trampled grass stands up again over `trample_recover`.

## Clearings and trampling

- **By group:** `clearings`, a list of `GrassClearing` {group, radius, soft}. No grass within `radius` of each node of the group, thinning back to full over `soft`. The nodes are read again every half second, so a building placed in play clears its ground.
- **By hand:** a `GrassClear3D` node with `radius` and `soft`, dragged by its handles in the 3D view. Its `changed` signal tells anything else that follows it (the game's own flora).
- **Both** count together, up to 48 clearings.
- **Trampling:** the nodes of `trample_group` near the field bend the grass away from them. Each is `trample_radius` wide, or its own `grass_trample_radius` (property or meta). With `trample_recover` (s), each leaves a trail that fades, so the grass stands up slowly behind it. A body standing still keeps its spot pressed. Bodies come first, then the freshest trail points, up to 48 stamps.

## Performance

Grass costs per instanced blade: in a vertex shader every vertex of a blade does the blade's work again. Pixels matter little; rendering at a quarter of the pixels saved under 10 % here.

What keeps it down:

- **Meshes:** one MultiMesh per tier and kind, shared by every cell, and one material per kind.
- **Cells:** crossing a cell only moves nodes, and each cell's bounds fit its ground, so the renderer culls the cells out of view.
- **Painted out costs nothing:** a cell where the density map is empty draws nothing, and a kind that grows by a map draws only in the cells where it is painted. In the example, flower patches cost 31 draws instead of 46.
- **Cheapest first:** the shader decides whether a blade is drawn with distance and rank, then one read of the ground. Only the blades left do the clumps, the wind and the trampling. A blade not drawn collapses to a point.
- **No discard:** blades are opaque and two-sided, and only kinds with `alpha_scissor` discard.

**Measured** on an M4 Mac at 1280×720, Compatibility renderer, vsync off, in the example. MEDIUM quality instances about 200 000 blades, 175 000 in view:

| What | Cost |
|---|---|
| The grass | about 5.4 ms a frame |
| The sun's shadows on it | about 1.1 ms of that |
| The clumps | 0.4 ms |
| Four segments against one | 1.4 ms |

**What to tune:**
- the cost scales with `density` and `radius`, so a preset is the first knob;
- `cast_shadows` stays off;
- a kind of blade adds a draw per cell where it grows.

With a depth prepass (Forward+) every blade's vertex shader runs twice; a game with much grass can measure with `rendering/driver/depth_prepass/enable` off.

**WebGL and the web.** Nothing uses `instance uniform`, which WebGL limits: the blades read MultiMesh custom data and material uniforms (a test checks it).

**Nothing is drawn headless or on a dedicated server.** `can_draw()` says so, and tests set `GrassField3D.draw_anywhere`.

## Where the ideas come from

Ghost of Tsushima's grass talk (Eric Wohllaib, GDC 2021) and write-ups of it shaped most of the rendering:
- Bézier blades with tilt and bend;
- Voronoi clumps that set height, shade and lean;
- one wind of scrolled noise, shared by everything, plus a per-blade bob;
- blades that drop and widen with distance, and LOD vertices blended before a switch;
- view-space thickening and rounded normals that tend to a common one far away;
- distant ground that takes the grass's colour.

Pigment from the ground's colour follows The Witcher 3. Breath of the Wild has no public technical source; its look (flat colours base to tip, clumps, wind waves that read from afar) is the reference for the defaults.

The editor tools follow what people already know from other tools:
- Terrain3D's keys and its bar of settings under the view;
- density maps painted per kind, as Unity's detail painting and HTerrain's detail layers do, with Unity's Shift and Ctrl;
- Spatial Gardener's paint and erase brushes;
- a brush that paints toward a target value, like Unreal's foliage paint density.

## Tests

```bash
godot --headless --path grasskit_lab --script res://addons/grass_kit/tests/grass_test_runner.gd
```

The result is `GRASSKIT TESTS PASS (n)`. The tests cover:

- **the quality**: the density curve, tiers that are prefixes, presets (and their buttons), the ring's count;
- **the cells and blades**:
  - the ring covers its circle;
  - the shared pattern spreads evenly at any prefix, and every tier is a prefix of it;
  - kinds share the blades by weight, and a kind that grows by a map adds its own;
  - segments halve and blend where a cell can switch;
- **the ground**:
  - flat;
  - written from the game's data (a sampler, or an image, and how much quicker the image is);
  - baked from colliders, then baked again in one part;
  - roots within 5 cm of the exact ground at 30° and 60°;
  - changes in one frame uploaded once;
  - the bake's cost;
  - a ray that meets it;
- **painting**:
  - a dab and its falloff;
  - erase, smooth, and noise that is the same every time;
  - colour laid over and uncovered;
  - a map made on the first dab;
  - a texture made elsewhere copied, never changed;
  - maps saved inside the ground;
  - a stroke put back;
  - fill, clear, import and export;
  - the area resized keeping what is painted;
- **the field**:
  - cells that follow the camera without new meshes, and bounds that fit the ground;
  - the counts and draws by kind, enabled off;
  - a new look with no rebuild, kinds of blade with their shaders;
  - a changed part of the ground;
  - clearings, trampling, each body's own width, trampled grass standing up again;
  - where the ring centres, a painted size;
  - a kind's painted map reaching its blades, and painted-out cells drawing nothing;
  - the ground under the grass;
  - set up, fit to the colliders;
  - the wind (shared, smooth, frozen, held by the pause);
  - nothing headless;
- **the ready-made looks**, a clearing's `changed`;
- **no instance uniform** in the shaders;
- **the example, end to end.**

The editor tools have their own check in a real editor, used the way a person uses them:
- **the grass and the ground:**
  - the grass around the 3D view's camera;
  - the flat-ground warning;
  - Bake ground, its file and its undo;
- **painting:**
  - selecting the field shows the toolbar; the sliders set the brush;
  - the brush aims where the mouse is, the grass follows it, and a click paints instead of selecting;
  - Ctrl + drag erases;
  - the stroke undoes and redoes, as does the map a first stroke makes;
  - `]` sizes the brush;
  - saving the scene keeps the map;
- **the menu:**
  - the Kind brush names a kind and paints where it grows;
  - Fill and Clear, and their undo;
- **the handles:**
  - the area's side dragged in and out, the painted path staying where it was, the new part baked, undone;
  - a clearing's radius;
- **set-up:** a new field sets itself up, fits the hills and bakes; the quality's Low button undoes.

```bash
GRASSKIT_EDITOR_CHECK=1 godot --headless --editor --path grasskit_lab
```

It prints `EDITOR CHECK PASS`. The shaders themselves (the blade, the cut one, the example's ground) and the brushes' circle and map overlay are checked in a window, in Forward+ and Compatibility, by running the example and the editor.

The ground-colour bake renders, so it has its own check in a window:

```bash
godot --path grasskit_lab --script res://checks/bake_color_check.gd
godot --rendering-method gl_compatibility --path grasskit_lab --script res://checks/bake_color_check.gd
```

It checks the image's size, soil on the painted path, the colour under the grass on the meadow, no blades in it, and the map kept in the ground. It prints `BAKE COLOR CHECK PASS`.

## Not in the kit

These are the game's:

- what grass means to the game (hiding units, slowing them);
- its terrain, and when it changes;
- its weather, which sets the wind;
- the options menu that sets the quality.
