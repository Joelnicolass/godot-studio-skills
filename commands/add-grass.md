---
description: "Grass (GrassKit addon): blades on the GPU around the camera over the ground's colliders, painted by hand with brushes in the 3D view, with clearings, trampling and a look that changes in play."
---

Add **grass** to the **game's Godot project** with the GrassKit addon: a `GrassField3D` over the terrain, its ground read from the colliders, a look and a quality. The person then paints it by hand (where it grows, paths, flower patches) with the brushes in the 3D view; the agent sets up and explains, it does not paint.

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
4. Where there is no grass: around which nodes (by group) and on steep slopes. Paths, bare patches and flower patches the person paints with the brushes afterwards.
5. What tramples it (units, the player), and the target hardware (to pick the quality).

## 2. Plan

Show the file tree before touching the game (`[+]` new, `[~]` changed, `[-]` removed), for example:

```
[~] scenes/maps/meadow/map.tscn          # GrassField3D (it sets itself up: ground, look, quality, wind)
[+] scenes/maps/meadow/map_grass_ground.res   # «Bake ground» and the brushes write it (heights, painted maps)
[+] scenes/look/grass_summer.tres        # GrassLook from addons/grass_kit/looks/ (one per biome or season)
[+] scenes/look/flower.tres              # GrassMesh: a mesh, its textures, its weight, map_name "flower"
[+] scenes/look/wind.tres                # GrassWind
[~] scenes/maps/meadow/ground.gdshader   # includes grass_ground.gdshaderinc (grass colour under the blades, soil on painted paths)
[~] scenes/units/unit.tscn               # group for trample_group
[~] project.godot                        # GrassKit plugin
```

Start from `addons/grass_kit/examples/minimal_3d` (the minimum, with the floor shader) or `grass_3d` (painting, clearings, trampling, looks).

## 3. Implement

Follow [godot-grass-kit](../skills/godot-grass-kit/SKILL.md) and `addons/grass_kit/README.md`.

- Add the `GrassField3D` in the editor (it sets itself up, fits the area to the colliders and bakes once the scene is saved), or set `ground.area` and `collision_mask` and press «Bake ground». A game with its own heights: `ground.set_heights_image(image)`.
- Tell the person how to paint: select the field; on top of the 3D view, the brushes Grass (where it grows), Height, Colour and Kind (flowers, by the kind's `map_name`); Ctrl/Cmd erases, Shift smooths, `[` `]` size, `-` `=` strength; GrassKit ▸ Fill with Erase on, then paint where it grows; save the scene.
- In play: `ground_changed(position, radius)` when the terrain changes; another `GrassLook` for another palette; `wind.strength` / `wind.direction` from the weather; `enabled` and `GrassQuality.preset()` from the options; `ground.paint()` only for what the game changes in play.
- Clearings by group, `GrassClear3D` by hand, `trample_group` (and `trample_recover`) for units.

## 4. Done when

- The ground is saved next to the scene and the field shows no warning; the grass shows in the editor.
- The person has painted (or knows how to paint) the paths and patches by hand.
- F6: grass around the camera, none on painted paths, in the clearings or on slopes past `slope_fade`; units bend it and it stands up again.
- `field.stats` and `quality.describe()` are in the budget for the target hardware.
- No unit, combat or network code inside `addons/grass_kit`.
