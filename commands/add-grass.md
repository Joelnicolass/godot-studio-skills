---
description: "Pasto (addon GrassKit): hojas en la GPU alrededor de la cámara sobre los colliders del suelo, pintado a mano con pinceles en la vista 3D, con claros, pisoteo y un look que cambia en el juego."
---

Agregá **pasto** al **proyecto Godot del juego** con el addon GrassKit: un `GrassField3D` sobre el terreno, su suelo leído de los colliders, un look y una calidad. Después la persona lo pinta a mano (dónde crece, senderos, manchas de flores) con los pinceles de la vista 3D; el agente arma y explica, no pinta.

Esto **no** son props (árboles, rocas: PropKit) ni lo que hace el pasto en el juego (esconder unidades, frenarlas): eso queda en el juego. **No** es 2D. **No** inventa el terreno.

Cargar: `godot-grass-kit`, `godot-composition-first`.

Si falta `addons/grass_kit/`:

```bash
./install.sh --addon /ABS/GODOT_ROOT grass_kit
```

Habilitá **GrassKit**. Si `godot-studio-workflow` está cargado: orquestador → árbol (este chat si son 1–3 archivos; si no, `studio-tech-lead`) → OK → `studio-developer`. Sin subagente extra.

## 1. Alcance

Si falta, preguntá en una sola tanda:

1. Qué escena, y qué es el terreno (colliders en qué capa, o los propios datos de altura del juego).
2. La cámara: ¿RTS desde arriba, tercera persona, primera persona? ¿Sigue a una unidad?
3. El look: colores, altura, uno o varios (biomas, estaciones, una paleta que cambia en el juego); mallas propias (matas, flores) y sus texturas; el viento y qué lo cambia (el clima).
4. Dónde no hay pasto: alrededor de qué nodos (por grupo) y en pendientes fuertes. Los senderos, las zonas peladas y las manchas de flores los pinta la persona con los pinceles después.
5. Qué lo pisa (unidades, el jugador), y el hardware objetivo (para elegir la calidad).

## 2. Plan

Mostrá el árbol de archivos antes de tocar el juego (`[+]` nuevo, `[~]` cambiado, `[-]` borrado), por ejemplo:

```
[~] scenes/maps/meadow/map.tscn          # GrassField3D (se arma solo: ground, look, quality, wind)
[+] scenes/maps/meadow/map_grass_ground.res   # lo escriben «Bake ground» y los pinceles (alturas, mapas pintados)
[+] scenes/look/grass_summer.tres        # GrassLook desde addons/grass_kit/looks/ (uno por bioma o estación)
[+] scenes/look/flower.tres              # GrassMesh: una malla, sus texturas, su peso, map_name "flower"
[+] scenes/look/wind.tres                # GrassWind
[~] scenes/maps/meadow/ground.gdshader   # incluye grass_ground.gdshaderinc (color del pasto bajo las hojas, tierra en senderos pintados)
[~] scenes/units/unit.tscn               # grupo para trample_group
[~] project.godot                        # plugin GrassKit
```

Arrancá desde `addons/grass_kit/examples/grass_3d`.

## 3. Implementar

Seguí [godot-grass-kit](../skills/godot-grass-kit/SKILL.md) y `addons/grass_kit/README.md`.

- Agregá el `GrassField3D` en el editor (se arma solo, ajusta el área a los colliders y hornea cuando la escena está guardada), o poné `ground.area` y `collision_mask` y apretá «Bake ground». Un juego con sus propias alturas: `ground.set_heights_image(image)`.
- Decile a la persona cómo pintar: seleccionar el campo; arriba de la vista 3D, los pinceles Grass (dónde crece), Height, Colour y Kind (flores, por el `map_name` del tipo); Ctrl/Cmd borra, Shift suaviza, `[` `]` tamaño, `-` `=` fuerza; GrassKit ▸ Fill con Erase prendido, y después pintar dónde crece; guardar la escena.
- En el juego: `ground_changed(position, radius)` cuando cambia el terreno; otro `GrassLook` para otra paleta; `wind.strength` / `wind.direction` desde el clima; `enabled` y `GrassQuality.preset()` desde las opciones; `ground.paint()` solo para lo que el juego cambia en el juego.
- Claros por grupo, `GrassClear3D` a mano, `trample_group` (y `trample_recover`) para las unidades.

## 4. Listo cuando

- El suelo está guardado junto a la escena y el campo no muestra avisos; el pasto se ve en el editor.
- La persona pintó (o sabe cómo pintar) los senderos y las manchas a mano.
- F6: pasto alrededor de la cámara, nada en senderos pintados, en los claros ni en pendientes pasado `slope_fade`; las unidades lo doblan y se vuelve a levantar.
- `field.stats` y `quality.describe()` entran en el presupuesto del hardware objetivo.
- Nada de unidades, combate ni red dentro de `addons/grass_kit`.
