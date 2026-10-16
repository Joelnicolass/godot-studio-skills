---
name: godot-material-maker
description: >-
  Creates procedural materials and textures for Godot 4 with Material Maker
  (.ptex node graph → per-channel PNGs + Godot material). Use when the game
  needs PBR textures (albedo, normal, roughness, ORM, height), tileable
  surfaces, floor / wall / rock / terrain materials, procedural 2D textures,
  or /create-material. Ask before installing or generating; ask for
  references.
---

# Godot — procedural materials (Material Maker)

[Material Maker](https://github.com/RodZill4/material-maker) is a desktop app (built on Godot) for node-based procedural materials and textures. The graph lives in a `.ptex`; the export is one PNG per channel + a Godot-ready material. It is **not** a game addon: it is an authoring tool, like Aseprite or Blender.

Composition: [godot-composition-first](../godot-composition-first/SKILL.md). Other assets: [assets.md](../godot-composition-first/assets.md). Scoped request: command `/create-material`.

## When to offer it

The slice needs a surface that can no longer be a placeholder (floor, wall, rock, metal, wood, cloth, 3D terrain; 2D background or tile) and the user brought no texture. Say it can be created with Material Maker. Do **not** install it or generate anything without OK.

## Before (mandatory)

1. Ask: procedural material with Material Maker, the user's own texture, or a placeholder for now?
2. Ask for references: photos or URLs, palette, style (realistic, stylized, pixel), scale (meters per repeat), and target resolution.
3. Without OK: flat-color `StandardMaterial3D` or `PlaceholderTexture2D`, and keep coding.

## Install (only with OK)

Binary from [releases](https://github.com/RodZill4/material-maker/releases) (Windows, Linux, macOS). It lives outside the game. If it is not on `PATH`, use `MATERIAL_MAKER=/ABS/PATH/material_maker`.

## Flow

1. **Graph**: the user builds or tweaks it in the app, or you start from a [library](https://www.materialmaker.org) material / an example. The agent proposes nodes and parameters (noise → warp → colorize → normal map, scale, contrast); do not invent a `.ptex` blind. Respect the library material's license.
2. **Versioned source**: the `.ptex` next to its exports, `res://assets/materials/<name>/<name>.ptex` (like the `.aseprite` next to the PNG). Godot ignores the extension.
3. **Export** from the CLI (or File → Export material in the app):

   ```bash
   "$MATERIAL_MAKER" --export -t "Godot/Godot 4 Standard" \
     -o /ABS/GODOT_ROOT/assets/materials/rock --output-file %n rock.ptex
   ```

   | Target | Output |
   |--------|--------|
   | `Godot/Godot 4 Standard` | `StandardMaterial3D` + separate maps (albedo, normal, roughness, metallic, AO, height) |
   | `Godot/Godot 4 ORM` | Same, with occlusion / roughness / metallic packed into one PNG |
   | `Godot/Godot 4` | Dynamic / raymarching materials: a shader instead of PNGs |

   The CLI renders the nodes: it needs a GPU and may open a window briefly. The current version exports at 2048 px even if you pass `--size`; for another size, export from the app or lower **Max Size** in Godot's import settings.
4. **In Godot**: the surface type is a `.tres` (`rock.tres`, `moss.tres`), not an `if kind`. The component receives it through `@export var surface: Material`, or it goes in the `MeshInstance3D`'s `material_override`. Tiling through the material's `uv1_scale`, not in code. 2D: the albedo as a `Texture2D` on `Sprite2D` / `TileSet` / `TextureRect`; 2D normals with `CanvasTexture`.
5. **Changes**: edit the `.ptex` and re-export. Do not retouch the PNGs by hand.

## Anti-patterns

- A material generated without references or OK.
- Material Maker as a runtime dependency of the game.
- 4K for a 2 m prop; six maps when the style is flat and albedo is enough.
- A `.gd` that builds the material in code when an exported `.tres` solves it.
- A library material whose license you did not check.
