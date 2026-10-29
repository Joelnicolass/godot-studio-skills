---
name: godot-grass-kit
description: >-
  Draws grass over a Godot 4 3D world with the GrassKit addon: blades on the GPU
  around the camera in cells that move with it, a ground read from the colliders
  (exact heights, normals, slope fade), any mesh as a blade with PBR textures, a
  shared wind, clearings, trampling, and looks that change in play. Use when the
  user wants grass, a meadow, flowers in grass, vegetation that sways in the wind,
  grass on paths or slopes, trampled grass, grass that costs too much, or
  /add-grass. Not props such as trees and rocks (PropKit) and not
  what grass means to the game.
---

# Godot — grass (GrassKit)

Addon `addons/grass_kit/` in the **game** project. Reference: `addons/grass_kit/README.md`; API by piece: [api.md](api.md).

If the addon is missing:

```bash
./install.sh --addon /path/to/godot-project grass_kit
```

Enable plugin **GrassKit**. Bounded request: `/add-grass`. Composition: [godot-composition-first](../godot-composition-first/SKILL.md).

## Rules

- **One node, four resources.** A `GrassField3D` at the origin with `ground` (GrassGround), `look` (GrassLook), `quality` (GrassQuality) and `wind` (GrassWind). Nothing else to wire.
- **Looks are `.tres`.** One per biome, season or palette; kinds of blade (`GrassMesh`: the kit's blade or any mesh, PBR textures, alpha scissor) mixed by weight. Swapping looks or values is uniforms only.
- **The wind is shared.** The game's trees, particles and ground read it with `#include "res://addons/grass_kit/field/grass_wind.gdshaderinc"`; the ground meets the far grass with `grass_ground.gdshaderinc`. Weather sets `wind.strength` and `wind.direction`; changes blend in.
- **The ground is the game's colliders.** «Bake ground» reads them (exact heights and normals); a game with its own height data calls `ground.set_heights(rect, sampler)`. `texel_size` at most a quarter of the terrain's triangles; the inspector warns when a bake gets big.
- **A change in play is a call, not a rebuild.** Ground: `field.ground_changed(position, radius)` (or `set_heights` on that rect). Look, palette: assign or edit the `GrassLook`. Quality: assign another `GrassQuality`. Off: `enabled = false`.
- **Clearings and trampling are groups.** `clearings` ({group, radius, soft}), `GrassClear3D` nodes, `trample_group` (each body's own width with `grass_trample_radius`). The kit never names a game class.
- **No kit depends on another.** GrassKit has no network: grass is drawn by each peer from the same ground. Nothing is drawn headless or on a dedicated server.
- **The cost is the instanced blades.** Read `field.stats` (blades and draws, in view and by kind) and `quality.describe()`; lower `density` or `radius` (or a preset) before anything else. Each kind of blade adds a draw per cell. No `instance uniform` (WebGL).

## Tree

```
World
├── Terrain              # collision on the layer of ground.collision_mask
├── Grass                # GrassField3D (ground, look, quality; its cells are internal)
├── Camp                 # in a group a GrassClearing names
└── Units/…              # in trample_group
```

Start from `addons/grass_kit/examples/grass_3d/grass_3d.tscn`.

## What belongs where

| Kit | Game |
|---|---|
| Blades, cells, tiers, the shader, the wind's shape | What grass means (hiding, slowing), the weather that sets the wind |
| Reading the ground (rays or `set_heights`) | The terrain and when it changes |
| Looks, quality presets, `enabled` | The options menu and which look a biome uses |
| Clearings and trampling by group | Which nodes are in those groups |

## Done when

- «Bake ground» saves `<scene>_grass_ground.res` and the field shows no warning; the grass shows in the editor around the 3D view.
- F6: grass around the camera, none in the clearings or on slopes past `slope_fade`, blades bending around trampling units.
- `print(field.stats)` and `field.quality.describe()` give the cost; another look changes the colours with the same cells; the wind blends when the weather changes.
- `godot --headless --path grasskit_lab --script res://addons/grass_kit/tests/grass_test_runner.gd` gives `GRASSKIT TESTS PASS` (in the kit repo).

## Anti-patterns

- A grass mesh per blade or per patch as nodes: thousands of draw calls instead of a few cells.
- Rebuilding the field to change colour or wind: change the look or the wind.
- `alpha_scissor` on plain blades: opaque costs less; keep it for petals and cards.
- A game shader declaring its own wind uniforms instead of including `grass_wind.gdshaderinc`: the grass and the trees sway apart.
- Baking a huge map at 0.5 m texels: raise `texel_size` (a quarter of the triangles is enough) or write the heights with `set_heights`.
- The terrain's layer missing from `ground.collision_mask`, or units in it: the bake reads the wrong height.
- Moving the GrassField3D away from the origin.
