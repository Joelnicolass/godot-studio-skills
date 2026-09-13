# Assets — shaders, 2D and 3D

Do not invent art or FX from memory when a catalog or tool exists. The game (PNG, `.gdshader`, `.glb`) lives in the **Godot project**, not in this framework.

## Shaders

Search first, adapt, wrap in a **pass** (packed scene). One effect = one `.gdshader` file. Knobs on the material (`shader_parameter`), not 80 floats in an autoload.

| Source | Use |
|--------|-----|
| [Godot Shaders](https://godotshaders.com/shader/?orderby=date&order=DESC) | Preferred: already Godot shading language. |
| [Shadertoy](https://www.shadertoy.com) | Port: `mainImage` → `fragment()`, `iTime` → `TIME`, `iResolution` / `fragCoord` → `SCREEN_UV` / `UV`. Do not paste Shadertoy GLSL as-is. |

Honor the page’s license and attribution. Do not copy another title’s FX (CRT, wrap, plasma) “because it was in the example”.

The pass does not know score or session. Gameplay tweens **that** pass.

## 2D sprites (Aseprite MCP)

Animation: [godot-animation](../godot-animation/SKILL.md) (12 principles).

**Ask first.** Do not use MCP or create sprites until the user says yes. Ask for **references** (images, URLs, palette, size, cycles, style). No references and no OK: placeholder, no invented art.

If they said yes: pixel art / spritesheet via **Aseprite MCP**, not an eternal `ColorRect` or a base64 PNG.

Repo: [diivi/aseprite-mcp](https://github.com/diivi/aseprite-mcp)

1. User OK + references.
2. If MCP tools **already exist**: use them. If **not**: install (below), new chat, then draw.
3. Export PNG / spritesheet into the game (`res://assets/…`) → `Sprite2D` / `AnimatedSprite2D`. The `.aseprite` can sit next to the PNG.

Short loop: palette (`generate_color_ramp` or a preset) → layers → silhouette → `export_frame` at 8× to look → iterate → `export_sprite` / `export_spritesheet` into the Godot project.

### Install the MCP

Needs: [Aseprite](https://www.aseprite.org/), Python 3.13+, [uv](https://github.com/astral-sh/uv). Set `ASEPRITE_PATH` if the binary is not on PATH.

Clone the server once (outside the game):

```bash
git clone https://github.com/diivi/aseprite-mcp.git
```

In Cursor → Settings → MCP, or in `~/.cursor/mcp.json` / the **game’s** `.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "aseprite": {
      "command": "uv",
      "args": ["--directory", "/ABS/PATH/aseprite-mcp", "run", "-m", "aseprite_mcp"],
      "env": {
        "ASEPRITE_PATH": "/ABS/PATH/to/aseprite"
      }
    }
  }
}
```

On macOS `uv` is often `/opt/homebrew/bin/uv`. Open a **new** chat after saving.

If the MCP does not start: do not fake the sprite; say what is missing (Aseprite, path, uv) and use a `PlaceholderTexture2D` **only** until the user enables it.

## 3D models (Blender MCP)

Official source: [MCP Server — Blender](https://www.blender.org/lab/mcp-server/).

**Ask first** (only if the game is **3D** or 2D+3D). Do not install the Blender MCP or run code in the scene until the user says yes. Ask for **references** (images, concepts, scale, poly budget, style). Without OK: `PlaceholderMesh` / a box and continue with code.

If they said yes:

1. Install and configure the official MCP (below). Blender must be **open** with the add-on started.
2. Model / tweak in Blender via MCP. Export **glTF 2.0** (`.glb`) to `res://assets/…` in the game.
3. In Godot: `MeshInstance3D` / packed scene. Do not leave the `.blend` as the only runtime asset.

The server executes LLM-generated Python **with no** sandbox. Do not use it on files with sensitive data. Prefer a working copy.

### Install the Blender MCP

Official requirements: **Blender 5.1 or newer**, Lab add-on, MCP client (Cursor), MCP server.

1. Blender → Edit → Preferences → Extensions → Get Extensions. Search **MCP** / Blender Lab and install the official add-on. (Drag & drop the Lab repo: twice — first the repository, then the add-on.)
2. In the add-on preferences: **Start MCP Server** (typically `localhost:9876`).
3. In Cursor: Settings → MCP. If the client accepts **`.mcpb`**, download the bundle from the [release / docs page](https://www.blender.org/lab/mcp-server/) and add it. Otherwise follow the *setup instructions* on that same page (do not use a community `uvx blender-mcp`: it is a **different** protocol).
4. **New** chat. Confirm Blender tools appear. If not: Blender open + server started + reload MCP.

If it does not start: do not invent a mesh; say what is missing (5.1, add-on, server, Cursor MCP).
