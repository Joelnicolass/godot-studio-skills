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

## Procedural materials and textures (Material Maker)

**Ask first.** If a surface (floor, wall, rock, terrain, 2D tile) needs a texture and the user brought none, offer to create it with [Material Maker](https://github.com/RodZill4/material-maker): `.ptex` graph → per-channel PNGs + a Godot material (`.tres`). Without OK + references: placeholder. Install, CLI export, and wiring: skill [godot-material-maker](../godot-material-maker/SKILL.md).

## 2D sprites (Aseprite MCP)

Animation: [godot-animation](../godot-animation/SKILL.md) (12 principles).

**Ask first.** Do not use MCP or create sprites until the user says yes. Ask for **references** (images, URLs, palette, size, cycles, style). No references and no OK: placeholder, no invented art.

If they said yes: pixel art / spritesheet via **Aseprite MCP**, not an eternal `ColorRect` or a base64 PNG.

Repo: [diivi/aseprite-mcp](https://github.com/diivi/aseprite-mcp)

1. User OK + references.
2. If MCP tools **already exist**: use them. If **not**: install (below), new session, then draw.
3. Export PNG / spritesheet into the game (`res://assets/…`) → `Sprite2D` / `AnimatedSprite2D`. The `.aseprite` can sit next to the PNG.

Short loop: palette (`generate_color_ramp` or a preset) → layers → silhouette → `export_frame` at 8× to look → iterate → `export_sprite` / `export_spritesheet` into the Godot project.

### Install the MCP

Needs: [Aseprite](https://www.aseprite.org/), Python 3.13+, [uv](https://github.com/astral-sh/uv). Set `ASEPRITE_PATH` if the binary is not on PATH.

Clone the server once (outside the game):

```bash
git clone https://github.com/diivi/aseprite-mcp.git
```

Claude Code: `.mcp.json` at the **game’s** root (or `claude mcp add`). Cursor: Settings → MCP, or `~/.cursor/mcp.json` / the game’s `.cursor/mcp.json`. Same content:

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

On macOS `uv` is often `/opt/homebrew/bin/uv`. Open a **new** session after saving (in Claude Code, `/mcp` shows whether it connected).

If the MCP does not start: do not fake the sprite; say what is missing (Aseprite, path, uv) and use a `PlaceholderTexture2D` **only** until the user enables it.

### A pixel font (from an image)

For a pixel art game, the font can be an image: a grid of equal cells, one character per cell, that Godot imports as a `FontFile`. With the same OK as the art, it is drawn from Aseprite with a Lua script (no MCP), so it stays reproducible.

1. **The glyphs as text.** Glyphs of 5×7 in cells of 6×8: the extra column and row are the space between letters and between lines.
2. **The Aseprite script** draws each glyph in its cell and exports the PNG:

   ```lua
   -- pixel_font.lua: aseprite -b --script-param out=assets/fonts/pixel_font.png --script pixel_font.lua
   local CW, CH, COLS = 6, 8, 16
   local GLYPHS = {
     A = {".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"},
     ["Ñ"] = {".##.#", "#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#"},
     ["¡"] = {"..#..", ".....", "..#..", "..#..", "..#..", "..#..", "..#.."},
     -- …one per character
   }
   local ORDER = {"A", "Ñ", "¡"}  -- the cells' order: the same as character_ranges
   local rows = math.ceil(#ORDER / COLS)
   local spr = Sprite(COLS * CW, rows * CH, ColorMode.RGB)
   local img = Image(spr.width, spr.height, ColorMode.RGB)
   local white = app.pixelColor.rgba(255, 255, 255, 255)
   for i, key in ipairs(ORDER) do
     local ox, oy = ((i - 1) % COLS) * CW, math.floor((i - 1) / COLS) * CH
     for y, row in ipairs(GLYPHS[key]) do
       for x = 1, #row do
         if row:sub(x, x) == "#" then img:drawPixel(ox + x - 1, oy + y - 1, white) end
       end
     end
   end
   spr:newCel(spr.layers[1], spr.frames[1], img, Point(0, 0))
   spr:saveCopyAs(app.params.out)
   spr:close()
   ```

   White on transparent: the `Label` sets the colour (`font_color`, modulate).
3. **The import** (the PNG's Import tab → *Font Data (Image Font)*, or the `.import`):

   ```ini
   importer="font_data_image"
   [params]
   character_ranges=PackedStringArray("32-127", "193", "201", "205", "211", "218", "209", "220", "225", "233", "237", "243", "250", "241", "252", "161", "191")
   columns=16
   rows=7
   scaling_mode=1
   ```

   - `character_ranges` goes **in the cells' order**, not sorted by code: cell 96 is the first code after `32-127` (here Á, 193). That is how ÁÉÍÓÚÑÜáéíóúñü¡¿ come after the ASCII. A range (`"32-127"`) is consecutive cells.
   - `columns` and `rows` give the cell's size: the image divided by them.
   - `scaling_mode=1` scales by integers only: the font's own size is the cell's height (8), and another size uses the integer multiple below, with no blurred pixels.
4. **In the game:** the font in the theme (or in the `Label`'s `theme_override_fonts/font`) with `font_size` equal to the cell's height or a multiple; the texture filter on Nearest (Project Settings › Rendering › Textures › Canvas Textures › Default Texture Filter).

**Accents on capitals:** in an 8-row cell, the accent takes the top row and the letter drops to 6 rows (from 7). It shows by one pixel; for whole letters, taller cells (for example 6×9) and `rows` and the height in the script to match.

Tested in Godot 4.7.2 with a PNG made this way: each character lands in its cell in the order of `character_ranges` (Ñ, 209, before ¡, 161), the font's size is 8 and each letter advances 6 px.

## 3D models (Blender MCP)

Official source: [MCP Server — Blender](https://www.blender.org/lab/mcp-server/).

**Ask first** (only if the game is **3D** or 2D+3D). Do not install the Blender MCP or run code in the scene until the user says yes. Ask for **references** (images, concepts, scale, poly budget, style). Without OK: `PlaceholderMesh` / a box and continue with code.

If they said yes:

1. Install and configure the official MCP (below). Blender must be **open** with the add-on started.
2. Model / tweak in Blender via MCP. Export **glTF 2.0** (`.glb`) to `res://assets/…` in the game.
3. In Godot: `MeshInstance3D` / packed scene. Do not leave the `.blend` as the only runtime asset.

The server executes LLM-generated Python **with no** sandbox. Do not use it on files with sensitive data. Prefer a working copy.

### Install the Blender MCP

Official requirements: **Blender 5.1 or newer**, Lab add-on, MCP client (Claude Code or Cursor), MCP server.

1. Blender → Edit → Preferences → Extensions → Get Extensions. Search **MCP** / Blender Lab and install the official add-on. (Drag & drop the Lab repo: twice — first the repository, then the add-on.)
2. In the add-on preferences: **Start MCP Server** (typically `localhost:9876`).
3. In the client (Cursor: Settings → MCP; Claude Code: `claude mcp add` or `.mcp.json`). If the client accepts **`.mcpb`**, download the bundle from the [release / docs page](https://www.blender.org/lab/mcp-server/) and add it. Otherwise follow the *setup instructions* on that same page (do not use a community `uvx blender-mcp`: it is a **different** protocol).
4. **New** session. Confirm Blender tools appear. If not: Blender open + server started + reload MCP.

If it does not start: do not invent a mesh; say what is missing (5.1, add-on, server, the client’s MCP config).
