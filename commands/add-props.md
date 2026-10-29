---
description: "Scatter props (PropKit addon): trees, rocks or bushes over the ground, drawn in batches, cutting a navmesh baked in zones."
---

Scatter **props** in the **game's Godot project** with the PropKit addon:

- a `PropScatter3D` / `PropScatter2D` that plants them;
- a `PropBatch3D` that draws them cheaply (3D);
- a `PropNavZones3D` / `PropNavZones2D` whose navmesh they cut, re-baked only where something changed.

This is **not** grass (GrassKit, a separate kit) and **not** what a prop does in the game (health, loot, chopping): those stay in the game. **Not** multiplayer: a change in play travels as game data over the game's transport, and every peer makes it (the navmesh follows its props). **Does not** invent the props' art.

Load: `godot-prop-kit`, `godot-composition-first`.

If `addons/prop_kit/` is missing:

```bash
./install.sh --addon /ABS/GODOT_ROOT prop_kit
```

Enable **PropKit**. If `godot-studio-workflow` is loaded: orchestrator → tree (this chat if 1–3 files; else `studio-tech-lead`) → OK → `studio-developer`. No extra subagent.

## 1. Scope

If missing, ask in one batch:

1. 2D or 3D, which scene, and what the ground is (colliders, the game's terrain, a flat area).
2. Which props (their scenes) and how they spread (woods and clearings, an even cover, a painted map).
3. What they stay away from (spawn points, buildings, roads), by group.
4. Do they block movement? Then: the navmesh settings (agent radius, cell size), and does it change in play (props removed, built)?
5. Networked? Then the change travels over the game's transport and every peer re-bakes (`apply_mode` MANUAL for a lockstep game).

## 2. Plan

Show the file tree before touching the game (`[+]` new, `[~]` changed, `[-]` removed), for example:

```
[+] scenes/props/tree.tscn             # StaticBody3D, group prop_obstruction, its own collision layer
[~] scenes/maps/forest/map.tscn        # PropScatter3D (+ PropBatch3D, PropNavZones3D)
[+] scenes/maps/forest/map_nav.res     # «Bake» writes it
[+] scenes/maps/terrain_ground.gd      # only if the ground is the game's own: extends PropGround, @tool
[~] project.godot                      # PropKit plugin; a collision layer for the props
```

Start from `addons/prop_kit/examples/forest_3d` or `grove_2d`.

## 3. Implement

Follow [godot-prop-kit](../skills/godot-prop-kit/SKILL.md) and `addons/prop_kit/README.md`.

- Press «Scatter», then «Bake» (the inspector warns when the bake no longer matches the props).
- In play, freeing or adding a prop is all: the navmesh re-bakes its zones (`follow_props`). A prop that moved: `rebake_prop(prop)`. The ground or a building changed: `rebake(position, radius)`.
- Wait for paths with `if not nav.is_ready(): await nav.updated`.
- The game's ground, if any, is a `@tool` script that `extends PropGround`.

## 4. Done when

- «Scatter» gives the same props twice and none within a keep-out.
- F6 loads the saved bake without baking (`stats.zones_baked` 0), and a path goes around the props.
- Freeing a prop re-bakes only its zones (`stats.zones_baked` < `zones_total`, `parse_ms` 0).
- No movement, damage or network code inside `addons/prop_kit`.
