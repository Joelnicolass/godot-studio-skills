---
description: "Crea un material o textura procedural con Material Maker y lo conecta al juego Godot como .tres."
argument-hint: "[superficie]"
---

Creá un **material / textura procedural** para el **proyecto Godot del juego** con [Material Maker](https://github.com/RodZill4/material-maker): piso, pared, roca, terreno, metal, tile o fondo 2D.

Esto **no** es un sprite animado (`godot-animation` + Aseprite) ni un modelo (Blender). **No** es un shader de post-proceso (pass de `assets.md`).

Cargar: `godot-material-maker`, `godot-composition-first`.

Si está `godot-studio-workflow`: orquestador → árbol (este chat si 1–3 archivos; si no `studio-tech-lead`) → OK → `studio-developer`. Sin subagente extra.

## 1. Acotar

Si falta, preguntá en un lote (`AskUserQuestion` en Claude Code / `AskQuestion` en Cursor, si está):

1. Qué **superficie** y dónde va (escena / actor).
2. 2D o 3D. Estilo: realista, estilizado, flat, pixel.
3. Referencias (2–5 imágenes o URLs), escala y resolución.
4. ¿Material Maker (hay que instalarlo), textura propia, o placeholder?

Sin OK: placeholder y seguí. No instales nada.

## 2. Plan

- `res://assets/materials/<nombre>/`: `.ptex` + PNG + `.tres`.
- Target de export (`Godot/Godot 4 Standard` u `ORM`) y por qué.
- Qué componente lo recibe por `@export` y qué escena lo asigna en el inspector.

## 3. Implementar

Seguí [godot-material-maker](../skills/godot-material-maker/SKILL.md). Export por CLI o desde la app, asigná el `.tres`, ajustá tiling en el material.

## 4. Listo cuando

- La superficie se ve en F5/F6 con el material exportado, sin placeholder.
- El `.ptex` está versionado junto a sus exports.
- Cambiar de superficie es cambiar el `.tres` en el inspector, sin tocar código.
