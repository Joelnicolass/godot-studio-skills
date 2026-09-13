# Assets — shaders and 2D sprites

Do not invent art or FX from memory when a catalog or tool exists. The game (PNG, `.gdshader`) lives in the **Godot project**, not in this framework.

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
