# GrassKit

Grass for 3D worlds, drawn on the GPU around the camera:
- **Cells:** the blades stand in square cells that move with the camera.
- **Distance:** near cells hold more blades, far ones fewer and wider, and nothing pops.
- **The ground:** read from the game's colliders: exact heights, the slope, and the normal the blades grow along.
- **The wind:** a shared wind moves them, and the game's ground, trees or particles can read the same wind.
- **The blades:** the kit's own blade, or any mesh with PBR textures, mixed by weight.

There is no network, no game rule and no autoload, and GrassKit depends on no other kit.

```bash
./install.sh --addon /path/to/godot-project grass_kit
```

Enable the **GrassKit** plugin. It adds GrassKit's global shader uniforms to Project Settings (only the ones missing), and gizmos for a clearing's circles and the ground's area. The nodes work without it.

**Example:** `examples/grass_3d/grass_3d.tscn`. Hills of grass with:
- a walker trampling a path;
- camps cleared by group, and a hand-placed clearing;
- a mound too steep for grass;
- a ground that meets the far grass.

Keys:
- **1 2 3:** quality.
- **L:** the next look (summer, autumn, flowers).
- **T:** a storm rising or calming.
- **G:** grass off and on.
- **C:** a crater under the mouse.

## Start

1. Add a **GrassField3D** to the world, at the origin.
2. Set **ground**: a `GrassGround` with `area` (x, z in metres) over the terrain and the terrain's `collision_mask`.
3. Press **Bake ground** in the inspector. It reads the terrain under every `texel_size` metres from its colliders and saves it next to the scene.
4. Set **look**, **quality** and **wind**: a `GrassLook`, a `GrassQuality` (or `GrassQuality.preset(GrassQuality.Level.MEDIUM)` from code) and a `GrassWind`.

The grass shows in the editor around the 3D view's camera, with a smaller radius (`editor_radius`).

## In the game

| You want to | Write |
|---|---|
| Swap the biome, season or a god's palette | `field.look = autumn` (a `.tres`), or `field.look.tip_color = …`: uniforms only |
| Raise a storm | `field.wind.strength = 1.3`, `field.wind.direction = …`: it blends in over `blend_time` |
| Let the player pick a quality | `field.quality = GrassQuality.preset(GrassQuality.Level.LOW)` |
| Turn grass off from the options | `field.enabled = false`: every cell is freed |
| A crater or a mound changed the ground | `field.ground_changed(position, radius)`: reads the colliders again there |
| Write the ground from the game's own data | `field.ground.set_heights(rect, func(x, z): return terrain.height_at(x, z))` |
| Clear grass around buildings or spawns | `clearings`: a `GrassClearing` {group, radius, soft}; or a `GrassClear3D` node |
| Let units push the grass aside | `trample_group`, `trample_radius` (or `grass_trample_radius` on the unit) |
| Centre the grass on what an RTS camera follows | `field.center = unit` |
| Move trees, particles or the ground with the same wind | `#include "res://addons/grass_kit/field/grass_wind.gdshaderinc"` |
| Make the ground meet the far grass | `#include "res://addons/grass_kit/field/grass_ground.gdshaderinc"` |
| See what it costs | `print(field.stats)`, `field.quality.describe()` |

## The ground (`GrassGround`)

Where grass grows and how high the ground is, over `area`.

- **Heights.** `bake()` (the Bake ground button, or `field.bake_ground()` from code) casts a ray down at every texel against `collision_mask`. It keeps the exact height, the ground's normal and whether there was ground, all in one float texture (`data`), so a blade reads it once. A game with its own height data writes it with `set_heights(rect, sampler)`; `sampler` is `func(x, z) -> float`, NAN where there is no ground.
- **Resolution.** Keep `texel_size` at most a quarter of the terrain's triangles, and a root sits within 5 cm of the exact ground, even on rough, steep slopes (`test_roots_sit_on_the_ground` measures it at 30° and 60°). On a plane the reading is exact at any slope; the error only comes from the creases between triangles.
- **Size.** `bake_cost()` says how many rays a full bake casts and how many megabytes it keeps (16 bytes a texel), and the inspector warns above 64 MB. A 2560 m map at 0.5 m is 26 million rays and 400 MB; at 2.5 m it is 16 MB.
- **Slopes.** `slope_fade` (degrees): from the first, blades thin and shorten; past the second, none. Blades grow along the ground's normal at their base (`look.align_to_normal`) and turn up towards the tip. Their width lies on the slope, so no base sinks into a hillside.
- **Painted maps**, stretched over `area`:
  - `density_texture` (red): white = grass, black = none.
  - `size_texture` (red): 0.5 = as the look says, black = flat, white = twice as tall. Use it for short grass on paths.
  - `color_texture`: the ground's own colour, which goes into the blades' base. Make it however the game can: its albedo map, or its ground shader rendered once from above. Swapping it in play (another biome) changes a uniform.
- **Changes in play.** `bake(space, rect)` and `set_heights(rect, …)` emit `area_changed(rect)` at once. The field gives new bounds only to the cells there. The texture goes to the GPU once at the end of the frame, however many changes it had.

## The look (`GrassLook`)

A `.tres` to duplicate and edit in the inspector; a game keeps several (a meadow, a desert, snow, flowers) and swaps them in play.

- **Shape:** `height_range` (0.25 to 0.8 m by default, right for an RTS), `width`, `tip_width`, `lean`, `align_to_normal`, `clump_size`. Blades in a clump are taller near its heart, lean out of it and share its shade.
- **Colour:**
  - `base_color` and `tip_color`, with `color_variation`;
  - `ground_tint` (how much of the ground's colour shows at the base) and `ground_color` (when the ground has no colour texture);
  - `fade_to_ground` and `far_grass` (where the far grass and the game's ground meet, below);
  - `roughness`.
- **Light:** `translucency` (light through the blades from behind, more at the thin tip), `root_shade`, `roundness` (a blade's normal turns out at its edges), `view_thicken` (blades seen edge-on widen, so a field never looks thin from the side).
- **Wind:** `wind_response`, `flutter` (each blade's own shiver across the wind), `gust_lighten` (gusts lighten the tips and their shine, so waves read from far away).
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
- **Where.** `mask_texture` (red over the ground's area) says where the kind grows: flowers only in a meadow.
- **How they share the blades.** Each blade of the shared sequence belongs to one kind by a fixed roll on the weights. So each kind is a prefix of its own share, and the density still changes smoothly with distance.
- **To copy:** `examples/grass_3d/flower.tres` is a flower made this way (`flower_mesh.tres`, `flower_petals.png`, alpha scissor 0.5, palette 0), and the example's flowers look puts it at 3 % among the blades.

## The wind (`GrassWind`)

The world's wind, shared: the field ticks it, and any shader can read it.

- **Settings:** `direction`, `strength` (0 calm, 1 a storm), `speed` (how fast the bands travel), `scale` (a band's size) and `noise` (a seamless texture; empty = the kit's).
- **No jumps.** The pattern's position is carried frame by frame, so a new direction or speed never makes the field jump. A new direction or strength is reached over `blend_time`.
- **Frozen.** `time_override` (0 or more) freezes it, for tests and screenshots.
- **Pause.** It moves with the field's processing, so it holds while the tree is paused (default process mode). Set the field to process always to keep it blowing.
- **Shared.** Several fields can share one wind; it moves once a frame.
- **In the blades.** A steady breeze plus gusts where the noise's bands crest. Each blade also shivers across the wind at its own phase, and gusts lighten the tips they pass.
- **For other shaders.** `field/grass_wind.gdshaderinc` gives `grasskit_wind_wave(xz)` (0..1), `grasskit_wind_gust(xz)` and `grasskit_wind_push(xz)`.
- **For the ground.** `field/grass_ground.gdshaderinc` gives `grasskit_ground_color(rgb, xz, grass_here)`, which takes the ground to the colour the far grass fades to so the edge of the drawn grass never shows, and `grasskit_ground_bands(xz, amount)`, pale bands where the gusts cross the ground. The example's hills use both.

The values are global shader uniforms (`grasskit_wind`, `grasskit_wind_offset`, `grasskit_wind_time`, `grasskit_wind_noise`, `grasskit_field`, `grasskit_grass`). The plugin adds the missing ones to Project Settings and touches no other; disabling it leaves them, in case a game shader reads them. Without the plugin, a field declares them before its own shaders compile.

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

`preset(LOW | MEDIUM | HIGH)` gives three ready ones. `blades_in_ring()` says what a whole ring instances, and `describe()` puts it in one line for a log.

`field.stats` (GrassStats) counts what is drawn now:
- cells and blades, in total and in view;
- the blades in view of each kind;
- the draw calls (one per kind per cell in view: a kind added to a look adds a draw per cell).

The blades are instanced, so their vertex shader runs whether or not the shader then thins them; the ones in view are what the GPU pays for.

## Smooth changes

No change with distance or in play is a step:

- **Density:** a blade goes when its rank passes the density. It is the same blade in every tier, so fewer blades never pop, and the ones left widen.
- **Segments:** before a cell switches to a mesh with half as many, each row the coarser mesh lacks has blended into its neighbours.
- **The edge:** blades shorten to nothing at the radius.
- **Colour at distance:** blades fade to a colour between the ground's and the grass's (`GrassLook.average_color()`). The game's ground fades to the same one with `grass_ground.gdshaderinc`, so the drawn grass and the ground beyond meet seamlessly.
- **The wind:** carried and blended, never restarted.

## Clearings and trampling

- **By group:** `clearings`, a list of `GrassClearing` {group, radius, soft}. No grass within `radius` of each node of the group, thinning back to full over `soft`. The nodes are read again every half second, so a building placed in play clears its ground.
- **By hand:** a `GrassClear3D` node with `radius` and `soft`. The editor draws its two circles.
- **Both** count together, up to 48 clearings.
- **Trampling:** the nodes of `trample_group` near the field bend the grass away from them. Each is `trample_radius` wide, or its own `grass_trample_radius` (property or meta). Up to 48 at a time.

## In the editor

- **Bake ground** reads the colliders and saves the ground next to the scene. The inspector warns while the ground is flat, and when a bake would be too big.
- The grass follows the 3D view's camera within `editor_radius`. Its cells are internal and never saved. `editor_preview` off hides it.
- Gizmos: a GrassClear3D's circles, the ground's area.

## Performance

Grass costs per instanced blade: in a vertex shader every vertex of a blade does the blade's work again. Pixels matter little; rendering at a quarter of the pixels saved under 10 % here.

What keeps it down:

- **Meshes:** one MultiMesh per tier and kind, shared by every cell, and one material per kind.
- **Cells:** crossing a cell only moves nodes, and each cell's bounds fit its ground, so the renderer culls the cells out of view.
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
- a kind of blade adds a draw per cell.

With a depth prepass (Forward+) every blade's vertex shader runs twice; a game with much grass can measure with `rendering/driver/depth_prepass/enable` off.

**WebGL and the web.** Nothing uses `instance uniform`, which WebGL limits: the blades read MultiMesh custom data and material uniforms (a test checks it).

**Nothing is drawn headless or on a dedicated server.** `can_draw()` says so, and tests set `GrassField3D.draw_anywhere`.

## Where the ideas come from

Ghost of Tsushima's grass talk (Eric Wohllaib, GDC 2021) and write-ups of it shaped most of this:
- Bézier blades with tilt and bend;
- Voronoi clumps that set height, shade and lean;
- one wind of scrolled noise, shared by everything, plus a per-blade bob;
- blades that drop and widen with distance, and LOD vertices blended before a switch;
- view-space thickening and rounded normals that tend to a common one far away;
- distant ground that takes the grass's colour.

Pigment from the ground's colour follows The Witcher 3. Breath of the Wild has no public technical source; its look (flat colours base to tip, clumps, wind waves that read from afar) is the reference for the defaults.

## Tests

```bash
godot --headless --path grasskit_lab --script res://addons/grass_kit/tests/grass_test_runner.gd
```

The result is `GRASSKIT TESTS PASS (n)`. The tests cover:

- **the quality**: the density curve, tiers that are prefixes, presets, the ring's count;
- **the cells and blades**:
  - the ring covers its circle;
  - the shared pattern spreads evenly at any prefix, and every tier is a prefix of it;
  - kinds share the blades by weight;
  - segments halve and blend where a cell can switch;
- **the ground**:
  - flat;
  - written from the game's data, with normals and slopes;
  - baked from colliders, then baked again in one part;
  - roots within 5 cm of the exact ground at 30° and 60°;
  - changes in one frame uploaded once;
  - the bake's cost;
- **the field**:
  - cells that follow the camera without new meshes, and bounds that fit the ground;
  - the counts and draws by kind, enabled off;
  - a new look with no rebuild, kinds of blade with their shaders;
  - a changed part of the ground;
  - clearings, trampling, each body's own width;
  - where the ring centres, a painted size;
  - the wind (shared, smooth, frozen, held by the pause);
  - nothing headless;
- **no instance uniform** in the shaders;
- **the example, end to end.**

The editor tools have their own check in a real editor. It covers the grass around the 3D view's camera, the flat-ground warning, Bake ground and the file it saves, and the clearing's gizmo:

```bash
GRASSKIT_EDITOR_CHECK=1 godot --headless --editor --path grasskit_lab
```

It prints `EDITOR CHECK PASS`. The shaders themselves (the blade, the cut one, the example's ground) are checked in a window, in Forward+ and Compatibility, by running the example, including a flower's cut shadow.

## Not in the kit

These are the game's:

- what grass means to the game (hiding units, slowing them);
- its terrain, and when it changes;
- its weather, which sets the wind;
- the options menu that sets the quality.
