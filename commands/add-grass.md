---
description: "Pasto (addon GrassKit): hojas en la GPU alrededor de la cámara sobre los colliders del suelo, con claros, pisoteo y un look que cambia en el juego."
---

Agregá **pasto** al **proyecto Godot del juego** con el addon GrassKit: un `GrassField3D` sobre el terreno, su suelo leído de los colliders, un look y una calidad.

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
4. Dónde no hay pasto: alrededor de qué nodos (por grupo), caminos, pendientes fuertes.
5. Qué lo pisa (unidades, el jugador), y el hardware objetivo (para elegir la calidad).

## 2. Plan

Mostrá el árbol de archivos antes de tocar el juego (`[+]` nuevo, `[~]` cambiado, `[-]` borrado), por ejemplo:

```
[~] scenes/maps/meadow/map.tscn          # GrassField3D (ground, look, quality)
[+] scenes/maps/meadow/map_grass_ground.res   # lo escribe «Bake ground»
[+] scenes/look/grass_summer.tres        # GrassLook (y uno por bioma o estación)
[+] scenes/look/flower.tres              # GrassMesh: una malla, sus texturas, su peso
[+] scenes/look/wind.tres                # GrassWind
[~] scenes/maps/meadow/ground.gdshader   # incluye grass_ground.gdshaderinc (se encuentra con el pasto lejano)
[~] scenes/units/unit.tscn               # grupo para trample_group
[~] project.godot                        # plugin GrassKit
```

Arrancá desde `addons/grass_kit/examples/grass_3d`.

## 3. Implementar

Seguí [godot-grass-kit](../skills/godot-grass-kit/SKILL.md) y `addons/grass_kit/README.md`.

- Poné `ground.area` y `collision_mask`, apretá «Bake ground».
- En el juego: `ground_changed(position, radius)` cuando cambia el terreno; otro `GrassLook` para otra paleta; `wind.strength` / `wind.direction` desde el clima; `enabled` y `GrassQuality.preset()` desde las opciones.
- Claros por grupo, `GrassClear3D` a mano, `trample_group` para las unidades.

## 4. Listo cuando

- «Bake ground» guardó el suelo y el campo no muestra avisos; el pasto se ve en el editor.
- F6: pasto alrededor de la cámara, nada en los claros ni en pendientes pasado `slope_fade`; las unidades lo doblan.
- `field.stats` y `quality.describe()` entran en el presupuesto del hardware objetivo.
- Nada de unidades, combate ni red dentro de `addons/grass_kit`.
