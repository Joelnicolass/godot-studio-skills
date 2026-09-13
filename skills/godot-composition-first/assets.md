# Assets — shaders y sprites 2D

No inventes arte o FX “de memoria” si hay catálogo o herramienta. El juego (PNG, `.gdshader`) vive en el **proyecto Godot**, no en este framework.

## Shaders

Buscá primero, adaptá, envolvé en un **pass** (packed scene). Un efecto = un archivo `.gdshader`. Knobs en el material (`shader_parameter`), no 80 floats en un autoload.

| Fuente | Uso |
|--------|-----|
| [Godot Shaders](https://godotshaders.com/shader/?orderby=date&order=DESC) | Preferido: ya está en shading language de Godot. |
| [Shadertoy](https://www.shadertoy.com) | Portar: `mainImage` → `fragment()`, `iTime` → `TIME`, `iResolution` / `fragCoord` → `SCREEN_UV` / `UV`. No pegues GLSL de Shadertoy tal cual. |

Respetá la licencia y la atribución de la página. No copies un FX de otro título (CRT, wrap, plasma) “porque estaba en el ejemplo”.

El pass no conoce puntaje ni sesión. Gameplay tweenea **ese** pass.

## Sprites 2D (Aseprite MCP)

Animación: [godot-animation](../godot-animation/SKILL.md) (12 principios).

**Preguntá primero.** No uses MCP ni crees sprites hasta que el usuario diga que sí. Pedí **referencias** (imágenes, URLs, paleta, tamaño, ciclos, estilo). Sin referencias y sin OK: placeholder, no arte inventado.

Si dijo que sí: pixel art / spritesheet vía **Aseprite MCP**, no un `ColorRect` eterno ni un PNG en base64.

Repo: [diivi/aseprite-mcp](https://github.com/diivi/aseprite-mcp)

1. Usuario OK + referencias.
2. Si las tools MCP **ya están**: usalas. Si **no**: instalá (abajo), chat nuevo, dibujá.
3. Exportá PNG / spritesheet al juego (`res://assets/…`) → `Sprite2D` / `AnimatedSprite2D`. El `.aseprite` puede ir junto al PNG.

Flujo corto: paleta (`generate_color_ramp` o preset) → capas → silueta → `export_frame` a 8× para mirar → iterar → `export_sprite` / `export_spritesheet` al proyecto Godot.

### Instalar el MCP

Requisitos: [Aseprite](https://www.aseprite.org/), Python 3.13+, [uv](https://github.com/astral-sh/uv). `ASEPRITE_PATH` si el binario no está en el PATH.

Cloná el server (una vez, fuera del juego):

```bash
git clone https://github.com/diivi/aseprite-mcp.git
```

En Cursor → Settings → MCP, o en `~/.cursor/mcp.json` / `.cursor/mcp.json` del **juego**:

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

En macOS el `uv` suele estar en `/opt/homebrew/bin/uv`. Chat **nuevo** después de guardar.

Si el MCP no arranca: no finjas el sprite; avisá qué falta (Aseprite, path, uv) y usá un placeholder `PlaceholderTexture2D` **solo** hasta que el usuario lo habilite.
