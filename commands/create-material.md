---
description: "Create a procedural material or texture with Material Maker and wire it into the Godot game as a .tres."
argument-hint: "[surface]"
---

Create a **procedural material / texture** for the **game's Godot project** with [Material Maker](https://github.com/RodZill4/material-maker): floor, wall, rock, terrain, metal, 2D tile or background.

This is **not** an animated sprite (`godot-animation` + Aseprite) or a model (Blender). It is **not** a post-process shader (a pass in `assets.md`).

Load: `godot-material-maker`, `godot-composition-first`.

If `godot-studio-workflow` is loaded: orchestrator → tree (this chat if 1–3 files; otherwise `studio-tech-lead`) → OK → `studio-developer`. No extra subagent.

## 1. Scope

If missing, ask in one batch (`AskUserQuestion` in Claude Code / `AskQuestion` in Cursor, if available):

1. Which **surface** and where it goes (scene / actor).
2. 2D or 3D. Style: realistic, stylized, flat, pixel.
3. References (2–5 images or URLs), scale, and resolution.
4. Material Maker (needs installing), the user's own texture, or a placeholder?

Without OK: placeholder and keep going. Install nothing.

## 2. Plan

- `res://assets/materials/<name>/`: `.ptex` + PNGs + `.tres`.
- Export target (`Godot/Godot 4 Standard` or `ORM`) and why.
- Which component receives it through `@export` and which scene assigns it in the inspector.

## 3. Implement

Follow [godot-material-maker](../skills/godot-material-maker/SKILL.md). Export from the CLI or the app, assign the `.tres`, set tiling on the material.

## 4. Done when

- The surface shows in F5/F6 with the exported material, no placeholder.
- The `.ptex` is versioned next to its exports.
- Changing the surface means swapping the `.tres` in the inspector, no code.
