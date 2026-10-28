---
name: godot-prop-kit
description: >-
  Scatters props (trees, rocks, bushes) over a Godot 4 world, 2D or 3D, with the
  PropKit addon, draws thousands in batches (3D), and bakes the navmesh in
  zones with the props as cheap obstructions that re-bake only what changed, on
  worker threads. Use when the user wants a forest, scattered props, foliage
  placement, keep-outs, a navmesh that props cut, slow navmesh re-bakes,
  connected regions of a navmesh, or /add-props. Not grass (GrassKit) and not
  what a prop does in the game.
---

# Godot — props and their navmesh (PropKit)

Addon `addons/prop_kit/` in the **game** project. Reference: `addons/prop_kit/README.md`; API by piece: [api.md](api.md).

If the addon is missing:

```bash
./install.sh --addon /path/to/godot-project prop_kit
```

Enable plugin **PropKit**. Bounded request: `/add-props`. Composition: [godot-composition-first](../godot-composition-first/SKILL.md).

## Rules

- **Three pieces, each on its own.** Scatter (`PropScatter3D` / `PropScatter2D`), batch drawing (`PropBatch3D`) and the navmesh in zones (`PropNavZones3D` / `PropNavZones2D`). A game takes one, two or all three.
- **The props are the scene's nodes.** A scatter plants saved children: edit them with the gizmo, and scatter again only to replace them all. Never generate props at runtime "to save the scene" when they must collide or cut the navmesh the same on every peer; the scatter is deterministic anyway.
- **The ground is a contract.** `PropFlatGround`, `PropRayGround` (3D, any collider), or the game's own script that `extends PropGround` with `@tool`. The kit never names a game class: keep-outs are groups (`PropKeepOut`).
- **Props cut the navmesh as obstructions, not geometry.** Each prop scene sets the group `prop_obstruction`, and its collision layer stays out of the navmesh template's collision mask. Read `PropObstructions.area_of(prop, is_3d)` before freeing a prop, then `rebake([area], false)`.
- **No kit depends on another.** PropKit has no network: a deterministic scatter gives every peer the same props. A change in play travels as game data over the game's transport, every peer calls `rebake`, and `apply_mode` MANUAL plus `apply()` swaps it in at the same tick.
- **Distances are world units**: metres in 3D, pixels in 2D (`spacing`, `zone_size`, `merge_gap`).

## Tree

```
World                    # source_root of the navmesh
├── Ground               # collision on a layer the navmesh parses
├── Forest               # PropScatter3D (its children: the props, group prop_obstruction, own layer)
└── Camps/…              # nodes in a group the scatter keeps out of
Batch                    # PropBatch3D (props = [Forest])
Nav                      # PropNavZones3D (navigation_mesh template, saved .res)
```

Start from `addons/prop_kit/examples/forest_3d/forest_3d.tscn` or `grove_2d/grove_2d.tscn`.

## What belongs where

| Kit | Game |
|---|---|
| Where props stand, how many, which variant | What a prop is (health, loot, a chop animation) |
| Drawing them cheaply | Its meshes and materials; another look per biome (`mesh_of`) |
| Obstructions, zones, re-bakes, the index | When to re-bake, the transport, the tick to apply |
| The ground contract (`PropGround`) | The terrain's data behind it |

## Done when

- «Scatter» fills the area: none within a keep-out, none on a forbidden mask, the same result twice.
- «Bake» saves `<scene>_nav.res`; F6 loads it without baking (`stats.zones_baked` 0) and a path goes around the props.
- Freeing a prop and `rebake([area], false)` re-bakes only its zones (`stats.zones_baked` < `zones_total`, `parse_ms` 0).
- In CI, `tools/bake_scene.gd -- --scene=… --check` exits 0: the committed bake matches a fresh one.
- `godot --headless --path propkit_lab --script res://addons/prop_kit/tests/prop_test_runner.gd` gives `PROPKIT TESTS PASS` (in the kit repo).

## Anti-patterns

- Props parsed as navmesh geometry: their layer is in the template's mask, so the bake pays twice. The kit warns once.
- Baking one big NavigationRegion3D again on every change instead of zones.
- `rebake` with `reparse = true` when only props changed.
- `merge_gap` larger than the agent's diameter: it closes passages an agent could walk through.
- A ground script without `@tool`: the scatter cannot call it in the editor.
