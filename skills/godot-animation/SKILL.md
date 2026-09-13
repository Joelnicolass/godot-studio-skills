---
name: godot-animation
description: >-
  Animate 2D sprites and motion in Godot 4 using the 12 basic principles
  (squash and stretch, anticipation, staging, pose to pose, follow through,
  slow in/out, arcs, secondary action, timing, exaggeration, solid drawing,
  appeal). Use when creating or editing pixel art, Aseprite MCP, SpriteFrames,
  AnimatedSprite2D, AnimationPlayer, idle/walk/attack cycles, or animation
  timing. Ask before using MCP or creating sprites; ask for references.
---

# Godot — 2D animation

Composition: [godot-composition-first](../godot-composition-first/SKILL.md). Assets / MCP: [assets.md](../godot-composition-first/assets.md).

## Before drawing or using MCP (required)

Do **not** install Aseprite MCP, do **not** call Aseprite tools, and do **not** create sprites until the user says yes.

1. Ask (AskQuestion if available): do you want sprites created / animated now (Aseprite MCP), or is a placeholder enough?
2. If **no**: `PlaceholderTexture2D` / ColorRect and continue with code. Do not push.
3. If **yes**: ask for **references** before a single pixel — images, URLs, palette, size (e.g. 16 / 32 / 48), style, which cycles (idle, walk, jump, attack), mood. With no references, **do not invent** a look: ask again.
4. Only then install or use the MCP. Export into the **Godot project**.

## The 12 basic principles

1. Estirar y encoger (Squash and stretch): Deforma un objeto para darle sensación de peso y flexibilidad sin cambiar su volumen total.
2. Anticipación (Anticipation): Prepara al espectador con un pequeño movimiento previo antes de la acción principal (como agacharse antes de saltar).
3. Puesta en escena (Staging): Organiza los elementos, la cámara y la iluminación para que la idea principal se entienda de forma clara.
4. Animación directa y pose a pose (Straight ahead and pose to pose): Combina dibujar fotograma a fotograma desde el inicio o planificar primero las posturas clave y rellenar después.
5. Acción continuada y superpuesta (Follow through and overlapping action): Muestra cómo las partes del cuerpo o la ropa se siguen moviendo y detienen a distinto tiempo tras parar el personaje.
6. Acelerar y desacelerar (Slow in and slow out): Añade más dibujos al inicio y al final de un movimiento para que las arrancadas y frenadas sean suaves y naturales.
7. Arcos (Arcs): Hace que la mayoría de los movimientos orgánicos sigan trayectorias curvas en lugar de líneas rectas.
8. Acción secundaria (Secondary action): Añade pequeños gestos complementarios (como silbar o mover los brazos) que refuerzan la acción principal sin robar protagonismo.
9. Timing (Ritmo o tiempos): Define el número de dibujos para controlar la velocidad y la cantidad de energía o peso de un objeto.
10. Exageración (Exaggeration): Amplifica los movimientos o rasgos de forma artística para darles más fuerza e impacto visual.
11. Dibujo tridimensional (Solid drawing): Cuida el volumen, el peso, el equilibrio y la profundidad en un espacio tridimensional.
12. Atractivo (Appeal): Otorga carisma y personalidad al diseño del personaje para que resulte interesante y agradable a la vista del público.

## How to apply them

In Aseprite (MCP): palette and silhouette first (12, 11). Key poses (4), squash on impact (1), anticipation frame (2), ease at the extremes (6), curved path (7), hair/cloth a frame late (5), one extra detail that does not compete (8), frame duration = weight (9), a stronger pose than real life (10). The clip reads on its own (3). `export_frame` at 8×; onion skin between poses.

In Godot: spritesheet / `SpriteFrames` → `AnimatedSprite2D`. Node motion (camera, scale squash, arcs) → `AnimationPlayer` with interpolation. Do not animate gameplay inside another pass’s shader.

One cycle = one tag / one `SpriteFrames` animation. Idle is not a single frozen frame if the character should feel alive (8, 9).
