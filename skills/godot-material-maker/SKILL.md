---
name: godot-material-maker
description: >-
  Crea materiales y texturas procedurales para Godot 4 con Material Maker
  (grafo de nodos .ptex → PNG por canal + material Godot). Usar cuando el
  juego necesita texturas PBR (albedo, normal, roughness, ORM, height),
  superficies tileables, materiales de piso / pared / roca / terreno,
  texturas 2D procedurales, o /create-material. Preguntá antes de instalar
  o generar; pedí referencias.
---

# Godot — materiales procedurales (Material Maker)

[Material Maker](https://github.com/RodZill4/material-maker) es una app de escritorio (hecha en Godot) para materiales y texturas procedurales por nodos. El grafo vive en un `.ptex`; el export sale como PNG por canal + material listo para Godot. **No** es un addon del juego: es una herramienta de autor, como Aseprite o Blender.

Composición: [godot-composition-first](../godot-composition-first/SKILL.md). Otros assets: [assets.md](../godot-composition-first/assets.md). Pedido acotado: command `/create-material`.

## Cuándo ofrecerlo

El slice necesita una superficie que ya no puede ser placeholder (piso, pared, roca, metal, madera, tela, terreno 3D; fondo o tile 2D) y el usuario no trajo textura. Decí que se puede crear con Material Maker. **No** lo instales ni generes nada sin OK.

## Antes (obligatorio)

1. Preguntá: ¿material procedural con Material Maker, textura propia del usuario, o placeholder por ahora?
2. Pedí referencias: fotos o URLs, paleta, estilo (realista, estilizado, pixel), escala (metros por repetición) y resolución objetivo.
3. Sin OK: `StandardMaterial3D` con color plano o `PlaceholderTexture2D`, y seguí con el código.

## Instalar (solo con OK)

Binario de [releases](https://github.com/RodZill4/material-maker/releases) (Windows, Linux, macOS). Vive fuera del juego. Si no está en el `PATH`, usá `MATERIAL_MAKER=/ABS/PATH/material_maker`.

## Flujo

1. **Grafo**: lo arma o ajusta el usuario en la app, o se parte de un material de la [biblioteca](https://www.materialmaker.org) / un ejemplo. El agente propone nodos y parámetros (noise → warp → colorize → normal map, escala, contraste); no inventes un `.ptex` a ciegas. Respetá la licencia del material de la biblioteca.
2. **Fuente versionada**: `.ptex` junto a sus exports, `res://assets/materials/<nombre>/<nombre>.ptex` (como el `.aseprite` junto al PNG). Godot ignora la extensión.
3. **Export** por CLI (o File → Export material en la app):

   ```bash
   "$MATERIAL_MAKER" --export -t "Godot/Godot 4 Standard" \
     -o /ABS/GODOT_ROOT/assets/materials/rock --output-file %n rock.ptex
   ```

   | Target | Sale |
   |--------|------|
   | `Godot/Godot 4 Standard` | `StandardMaterial3D` + mapas separados (albedo, normal, roughness, metallic, AO, height) |
   | `Godot/Godot 4 ORM` | Igual, con occlusion / roughness / metallic empaquetados en un PNG |
   | `Godot/Godot 4` | Materiales dinámicos / raymarching: shader en vez de PNG |

   El CLI renderiza los nodos: necesita GPU y puede abrir una ventana un momento. En la versión actual exporta a 2048 px aunque pases `--size`; para otro tamaño exportá desde la app o bajá **Max Size** en el import de Godot.
4. **En Godot**: el tipo de superficie es un `.tres` (`rock.tres`, `moss.tres`), no un `if kind`. El componente lo recibe por `@export var surface: Material` o va en `material_override` del `MeshInstance3D`. Tiling con `uv1_scale` del material, no en código. 2D: el albedo como `Texture2D` en `Sprite2D` / `TileSet` / `TextureRect`; normal 2D con `CanvasTexture`.
5. **Cambios**: se edita el `.ptex` y se re-exporta. No retoques los PNG a mano.

## Anti-patrones

- Material generado sin referencias ni OK.
- Material Maker como dependencia de runtime del juego.
- 4K para un prop de 2 m; 6 mapas cuando el estilo es flat y alcanza albedo.
- Un `.gd` que arma el material por código cuando un `.tres` exportado lo resuelve.
- Material de la biblioteca sin revisar su licencia.
