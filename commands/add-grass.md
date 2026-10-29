---
description: "Grass (GrassKit addon): blades on the GPU around the camera over the ground's colliders, with clearings, trampling and a look that changes in play."
---

Add **grass** to the **game's Godot project** with the GrassKit addon: a `GrassField3D` over the terrain, its ground read from the colliders, a look and a quality.

This is **not** props (trees, rocks: PropKit) and **not** what grass does in the game (hiding units, slowing them): that stays in the game. **Not** 2D. **Does not** invent the terrain.

Load: `godot-grass-kit`, `godot-composition-first`.

If `addons/grass_kit/` is missing:

```bash
./install.sh --addon /ABS/GODOT_ROOT grass_kit
```

Enable **GrassKit**. If `godot-studio-workflow` is loaded: orchestrator → tree (this chat if 1–3 files; else `studio-tech-lead`) → OK → `studio-developer`. No extra subagent.

## 1. Scope

If missing, ask in one batch:

1. Which scene, and what the terrain is (colliders on which layer, or the game's own height data).
2. The camera: RTS from above, third person, first person? Does it follow a unit?
3. The look: colours, height, one look or several (biomes, seasons, a palette that changes in play); any meshes (tufts, flowers) and their textures; the wind and what changes it (weather).
4. Where there is no grass: around which nodes (by group), paths, steep slopes.
5. What tramples it (units, the player), and the target hardware (to pick the quality).

## 2. Plan

Show the file tree before touching the game (`[+]` new, `[~]` changed, `[-]` removed), for example:

```
[~] scenes/maps/meadow/map.tscn          # GrassField3D (ground, look, quality)
[+] scenes/maps/meadow/map_grass_ground.res   # «Bake ground» writes it
[+] scenes/look/grass_summer.tres        # GrassLook (and one per biome or season)
[+] scenes/look/flower.tres              # GrassMesh: a mesh, its textures, its weight
[+] scenes/look/wind.tres                # GrassWind
[~] scenes/maps/meadow/ground.gdshader   # includes grass_ground.gdshaderinc (meets the far grass)
[~] scenes/units/unit.tscn               # group for trample_group
[~] project.godot                        # GrassKit plugin
```

Start from `addons/grass_kit/examples/grass_3d`.

## 3. Implement

Follow [godot-grass-kit](../skills/godot-grass-kit/SKILL.md) and `addons/grass_kit/README.md`.

- Set `ground.area` and `collision_mask`, press «Bake ground».
- In play: `ground_changed(position, radius)` when the terrain changes; another `GrassLook` for another palette; `wind.strength` / `wind.direction` from the weather; `enabled` and `GrassQuality.preset()` from the options.
- Clearings by group, `GrassClear3D` by hand, `trample_group` for units.

## 4. Done when

- «Bake ground» saved the ground and the field shows no warning; the grass shows in the editor.
- F6: grass around the camera, none in the clearings or on slopes past `slope_fade`; units bend it.
- `field.stats` and `quality.describe()` are in the budget for the target hardware.
- No unit, combat or network code inside `addons/grass_kit`.
