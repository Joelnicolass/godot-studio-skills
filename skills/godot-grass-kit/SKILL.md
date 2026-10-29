---
name: godot-grass-kit
description: >-
  Draws grass over a Godot 4 3D world with the GrassKit addon: blades on the GPU
  around the camera in cells that move with it, painted by hand with brushes in the
  3D view (where it grows, how tall, the ground's colour, where flowers grow), a
  ground read from the colliders (exact heights, normals, slope fade), any mesh as
  a blade with PBR textures, a shared wind, clearings, trampling that recovers, and
  looks that change in play. Use when the user wants grass, a meadow, flowers in
  grass, paths through grass, painting grass, vegetation that sways in the wind,
  grass on slopes, trampled grass, grass that costs too much, or /add-grass. Not
  props such as trees and rocks (PropKit) and not what grass means to the game.
---

# Godot — grass (GrassKit)

Addon `addons/grass_kit/` in the **game** project. Reference: `addons/grass_kit/README.md`; API by piece: [api.md](api.md).

If the addon is missing:

```bash
./install.sh --addon /path/to/godot-project grass_kit
```

Enable plugin **GrassKit**. Bounded request: `/add-grass`. Composition: [godot-composition-first](../godot-composition-first/SKILL.md).

## Rules

- **The person paints, the agent sets up.** Where grass grows, paths, short grass, the ground's colour and flower patches are painted by hand: select the GrassField3D and use the brushes on top of the 3D view (Grass, Height, Colour, Kind; Ctrl/Cmd erases, Shift smooths, `[` `]` size, `-` `=` strength). Never write those maps by code for a person's level; the agent adds the field, the look and the shaders, and tells the person how to paint. Code paints only what the game changes in play (`ground.paint()` with a `GrassBrush`: a burnt patch, a worn path).
- **One node, four resources.** A `GrassField3D` at the origin with `ground` (GrassGround), `look` (GrassLook), `quality` (GrassQuality) and `wind` (GrassWind). Added in the editor it sets itself up (`set_up()`: a ground fitted to the colliders, the meadow look, medium quality, a wind) and bakes when the scene is saved.
- **Looks are `.tres`.** Start from `addons/grass_kit/looks/` (meadow, autumn, lush, steppe); one per biome, season or palette. Kinds of blade (`GrassMesh`: the kit's blade or any mesh, PBR textures, alpha scissor) mixed by weight; a kind with a `map_name` grows where the Kind brush paints it, adding its blades. Swapping looks or values is uniforms only.
- **The wind is shared.** The game's trees, particles and ground read it with `#include "res://addons/grass_kit/field/grass_wind.gdshaderinc"`. Weather sets `wind.strength` and `wind.direction`; changes blend in.
- **The game's ground includes `grass_ground.gdshaderinc`.** `grasskit_ground_color(rgb, xz, grass_here)` takes the grass's colour under the blades (`look.under_grass`, `under_relief`) and meets the far grass; `grasskit_painted_grass(xz)` shows soil on a painted path. `color_texture` is the ground *with* that colour: GrassKit ▸ Bake ground colour (`await field.bake_ground_color()`, the ground on `ground.color_layers`) renders it; a game rendering its own view sets `field.ground_bake_view` (or calls `GrassGlobals.write_bake_view(look, ground)` before any field draws), never writing GrassKit's globals itself.
- **The ground is the game's colliders.** «Bake ground» reads them (exact heights and normals); a game with its own height data calls `ground.set_heights_image(image)` (red = metres; 4× quicker than `set_heights(rect, sampler)`). `texel_size` at most a quarter of the terrain's triangles; the inspector warns when a bake gets big. The area follows the colliders (GrassKit ▸ Fit area) or its handles.
- **A change in play is a call, not a rebuild.** Ground: `field.ground_changed(position, radius)`. Look, palette: assign or edit the `GrassLook`. Quality: assign another `GrassQuality`. Off: `enabled = false`.
- **Clearings and trampling are groups.** `clearings` ({group, radius, soft}), `GrassClear3D` nodes (their `changed` signal for the game's flora), `trample_group` (each body's own width with `grass_trample_radius`), `trample_recover` for grass that stands up again. The kit never names a game class.
- **No kit depends on another.** GrassKit has no network: grass is drawn by each peer from the same ground. Nothing is drawn headless or on a dedicated server.
- **The cost is the instanced blades.** Read `field.stats` (blades and draws, in view and by kind) and the quality's cost line (Low / Medium / High buttons in the inspector); lower `density` or `radius` before anything else. A kind adds a draw per cell where it grows; painted-out cells draw nothing. No `instance uniform` (WebGL).

## Tree

```
World
├── Terrain              # collision on the layer of ground.collision_mask
├── Grass                # GrassField3D (ground, look, quality, wind; its cells are internal)
├── Camp                 # in a group a GrassClearing names
└── Units/…              # in trample_group
```

Start from `addons/grass_kit/examples/minimal_3d/minimal_3d.tscn` (the minimum: a floor with a collider, a field, and `floor.gdshader` with `grass_ground.gdshaderinc` so the floor meets the far grass) or `grass_3d/grass_3d.tscn`: its path, short grass, flower patches and dry patch were painted with the brushes.

## What belongs where

| Kit | Game |
|---|---|
| Blades, cells, tiers, the shader, the wind's shape | What grass means (hiding, slowing), the weather that sets the wind |
| Reading the ground (rays or heights), the brushes and their maps | The terrain and when it changes; what the person paints |
| Looks, quality presets, `enabled` | The options menu and which look a biome uses |
| Clearings and trampling by group | Which nodes are in those groups |

## Done when

- The field shows no warning; `<scene>_grass_ground.res` is next to the scene; the grass shows in the editor around the 3D view.
- The person knows how to paint: select the field, pick a brush, paint, Ctrl erases, save the scene.
- F6: grass around the camera, none on painted paths, in the clearings or on slopes past `slope_fade`; blades bending around trampling units and standing up again behind them.
- `print(field.stats)` and the quality's cost give the cost; another look changes the colours with the same cells; the wind blends when the weather changes.
- `godot --headless --path grasskit_lab --script res://addons/grass_kit/tests/grass_test_runner.gd` gives `GRASSKIT TESTS PASS` (in the kit repo).

## Anti-patterns

- Writing a person's paths, flower patches or bare patches as code or generated textures: they paint them with the brushes, and can change them.
- A grass mesh per blade or per patch as nodes: thousands of draw calls instead of a few cells.
- Rebuilding the field to change colour or wind: change the look or the wind.
- `alpha_scissor` on plain blades: opaque costs less; keep it for petals and cards.
- A game shader declaring its own wind uniforms instead of including `grass_wind.gdshaderinc`: the grass and the trees sway apart.
- Baking a huge map at 0.5 m texels: raise `texel_size` (a quarter of the triangles is enough) or write the heights with `set_heights_image`.
- The terrain's layer missing from `ground.collision_mask`, or units in it: the bake reads the wrong height.
- Moving the GrassField3D away from the origin.
