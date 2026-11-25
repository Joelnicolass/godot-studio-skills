# Assets — shaders, 2D y 3D

No inventes arte o FX “de memoria” si hay catálogo o herramienta. El juego (PNG, `.gdshader`, `.blend` o `.glb`) vive en el **proyecto Godot**, no en este framework.

## Shaders

Buscá primero, adaptá, envolvé en un **pass** (packed scene). Un efecto = un archivo `.gdshader`. Knobs en el material (`shader_parameter`), no 80 floats en un autoload.

- Cada `uniform` numérico lleva `hint_range` (los colores, `source_color`), y se agrupan con `group_uniforms` cuando son más que unos pocos: 27 uniforms sueltos no se leen en el inspector.
- El `.gdshader` vive junto al componente o el pass que lo usa, o en `assets/shaders/` si RULES.md eligió el arte por tipo.

| Fuente | Uso |
|--------|-----|
| [Godot Shaders](https://godotshaders.com/shader/?orderby=date&order=DESC) | Preferido: ya está en shading language de Godot. |
| [Shadertoy](https://www.shadertoy.com) | Portar: `mainImage` → `fragment()`, `iTime` → `TIME`, `iResolution` / `fragCoord` → `SCREEN_UV` / `UV`. No pegues GLSL de Shadertoy tal cual. |

Respetá la licencia y la atribución de la página. No copies un FX de otro título (CRT, wrap, plasma) “porque estaba en el ejemplo”.

El pass no conoce puntaje ni sesión. Gameplay tweenea **ese** pass.

## Materiales y texturas procedurales (Material Maker)

**Preguntá primero.** Si una superficie (piso, pared, roca, terreno, tile 2D) necesita textura y el usuario no trajo una, ofrecé crearla con [Material Maker](https://github.com/RodZill4/material-maker): grafo `.ptex` → PNG por canal + material Godot (`.tres`). Sin OK + referencias: placeholder. Instalación, export por CLI y wiring: skill [godot-material-maker](../godot-material-maker/SKILL.md).

## Sprites 2D (Aseprite MCP)

Animación: [godot-animation](../godot-animation/SKILL.md) (12 principios; Tween o `AnimationPlayer` según el clip).

**Preguntá primero.** No uses MCP ni crees sprites hasta que el usuario diga que sí. Pedí **referencias** (imágenes, URLs, paleta, tamaño, ciclos, estilo). Sin referencias y sin OK: placeholder, no arte inventado.

Si dijo que sí: pixel art / spritesheet vía **Aseprite MCP**, no un `ColorRect` eterno ni un PNG en base64.

Repo: [diivi/aseprite-mcp](https://github.com/diivi/aseprite-mcp)

1. Usuario OK + referencias.
2. Si las tools MCP **ya están**: usalas. Si **no**: instalá (abajo), sesión nueva, dibujá.
3. Exportá PNG / spritesheet al juego (`res://assets/…`) → `Sprite2D` / `AnimatedSprite2D`. El `.aseprite` puede ir junto al PNG.

Flujo corto: paleta (`generate_color_ramp` o preset) → capas → silueta → `export_frame` a 8× para mirar → iterar → `export_sprite` / `export_spritesheet` al proyecto Godot.

### Instalar el MCP

Requisitos: [Aseprite](https://www.aseprite.org/), Python 3.13+, [uv](https://github.com/astral-sh/uv). `ASEPRITE_PATH` si el binario no está en el PATH.

Cloná el server (una vez, fuera del juego):

```bash
git clone https://github.com/diivi/aseprite-mcp.git
```

Claude Code: `.mcp.json` en la raíz del **juego** (o `claude mcp add`). Cursor: Settings → MCP, o `~/.cursor/mcp.json` / `.cursor/mcp.json` del juego. Mismo contenido:

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

En macOS el `uv` suele estar en `/opt/homebrew/bin/uv`. Sesión **nueva** después de guardar (en Claude Code, `/mcp` muestra si conectó).

Si el MCP no arranca: no finjas el sprite; avisá qué falta (Aseprite, path, uv) y usá un placeholder `PlaceholderTexture2D` **solo** hasta que el usuario lo habilite.

### Una fuente pixel (de imagen)

Para un juego de pixel art, la fuente puede ser una imagen: una grilla de celdas iguales, un carácter por celda, que Godot importa como `FontFile`. Con el mismo OK del arte, se dibuja desde Aseprite con un script de Lua (sin el MCP), así queda reproducible.

1. **Los glifos como texto.** Glifos de 5×7 en celdas de 6×8: la columna y la fila de más son el espacio entre letras y entre líneas.
2. **El script de Aseprite** dibuja cada glifo en su celda y exporta el PNG:

   ```lua
   -- pixel_font.lua: aseprite -b --script-param out=assets/fonts/pixel_font.png --script pixel_font.lua
   local CW, CH, COLS = 6, 8, 16
   local GLYPHS = {
     A = {".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"},
     ["Ñ"] = {".##.#", "#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#"},
     ["¡"] = {"..#..", ".....", "..#..", "..#..", "..#..", "..#..", "..#.."},
     -- …uno por carácter
   }
   local ORDER = {"A", "Ñ", "¡"}  -- el orden de las celdas: el mismo que character_ranges
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

   Blanco sobre transparente: el color lo pone el `Label` (`font_color`, modulate).
3. **El import** (pestaña Import del PNG → *Font Data (Image Font)*, o el `.import`):

   ```ini
   importer="font_data_image"
   [params]
   character_ranges=PackedStringArray("32-127", "193", "201", "205", "211", "218", "209", "220", "225", "233", "237", "243", "250", "241", "252", "161", "191")
   columns=16
   rows=7
   scaling_mode=1
   ```

   - `character_ranges` va **en el orden de las celdas**, no ordenado por código: la celda 96 es el primer código después de `32-127` (acá Á, 193). Así entran ÁÉÍÓÚÑÜáéíóúñü¡¿ después del ASCII. Un rango (`"32-127"`) son celdas seguidas.
   - `columns` y `rows` dan el tamaño de la celda: la imagen dividida por ellos.
   - `scaling_mode=1` escala solo en enteros: el tamaño propio de la fuente es el alto de la celda (8), y otro tamaño usa el múltiplo entero de abajo, sin píxeles borrosos.
4. **En el juego:** la fuente en el tema (o en `theme_override_fonts/font` del `Label`) con `font_size` igual al alto de la celda o un múltiplo; el filtro de texturas en Nearest (Project Settings › Rendering › Textures › Canvas Textures › Default Texture Filter).

**Las tildes en las mayúsculas:** en una celda de 8 filas, la tilde ocupa la fila de arriba y la letra baja a 6 filas (de 7). Se nota un píxel; para letras enteras, celdas más altas (por ejemplo 6×9) y `rows` y el alto en el script de acuerdo.

Probado en Godot 4.7.2 con un PNG hecho así: cada carácter cae en su celda en el orden de `character_ranges` (Ñ, 209, antes de ¡, 161), el tamaño de la fuente es 8 y cada letra avanza 6 px.

## Sprites en un mundo 3D

Un sprite en 3D es un `Sprite3D` (o un nodo componente con un `@export var texture`), con la textura en el inspector. No un material `.tres` por sprite.

## Modelos 3D (Blender MCP)

Fuente oficial: [MCP Server — Blender](https://www.blender.org/lab/mcp-server/).

**Preguntá primero** (solo si el juego es **3D** o 2D+3D). No instales el MCP de Blender ni ejecutes código en la escena hasta que el usuario diga que sí. Pedí **referencias** (imágenes, conceptos, escala, poly budget, estilo). Sin OK: `PlaceholderMesh` / caja y seguí con código.

Si dijo que sí:

1. Instalá y configurá el MCP oficial (abajo). Blender tiene que estar **abierto** con el add-on arrancado.
2. Modelá / ajustá en Blender vía MCP.
3. Elegí cómo entra al juego:
   - **El `.blend` directo** (importación oficial desde Godot 4.0) si el equipo edita en Blender: guardalo en `res://assets/…` y cada cambio se reimporta solo. Pide la ruta de Blender en Editor Settings › FileSystem › Import › Blender; cada máquina que importa, el CI incluido, necesita Blender o la carpeta `.godot/imported` en caché.
   - **Un `.glb`** (File › Export › glTF 2.0) a `res://assets/…` si el modelo viene de otro lado o el CI no tiene Blender. El `.blend` queda fuera del proyecto (uno adentro también se importa).
4. Los materiales, afuera del modelo: en el import, **Advanced…** › Materials › el material › **Use External** con un `.tres` por material (o **Actions… › Extract Materials** para sacarlos todos). Se editan y se cambian en el inspector, no por código ni por el nombre del slot.
5. En Godot: la escena importada como packed scene, o su malla en un `MeshInstance3D`.

El servidor ejecuta Python generado por la IA **sin** sandbox. No lo uses sobre archivos con datos sensibles. Preferí una copia de trabajo.

### Instalar el MCP de Blender

Requisitos (docs oficiales): **Blender 5.1 o más nuevo**, add-on Lab, cliente MCP (Claude Code o Cursor), servidor MCP.

1. Blender → Edit → Preferences → Extensions → Get Extensions. Buscá **MCP** / Blender Lab e instalá el add-on oficial. (Drag & drop del repo Lab: dos veces — primero el repositorio, después el add-on.)
2. En las preferencias del add-on: **Start MCP Server** (suele escuchar `localhost:9876`).
3. En el cliente (Cursor: Settings → MCP; Claude Code: `claude mcp add` o `.mcp.json`). Si el cliente acepta **`.mcpb`**, bajá el bundle de la [página de releases](https://www.blender.org/lab/mcp-server/) y agregalo. Si no: seguí las *setup instructions* de esa misma página (no uses un `uvx blender-mcp` comunitario: es **otro** protocolo).
4. Sesión **nueva**. Verificá que las tools de Blender aparezcan. Si no: Blender abierto + server started + recargar MCP.

Si no arranca: no inventes un mesh; avisá qué falta (versión 5.1, add-on, server, config MCP del cliente).
