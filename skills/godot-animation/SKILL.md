---
name: godot-animation
description: >-
  Anima sprites y motion 2D en Godot 4 con los 12 principios básicos
  (squash and stretch, anticipation, staging, pose to pose, follow through,
  slow in/out, arcs, secondary action, timing, exaggeration, solid drawing,
  appeal). Usar al crear o editar pixel art, Aseprite MCP, SpriteFrames,
  AnimatedSprite2D, AnimationPlayer, cycles idle/walk/attack, o timing de
  animación. Preguntá antes de usar MCP o crear sprites; pedí referencias.
---

# Godot — animación 2D

Composición: [godot-composition-first](../godot-composition-first/SKILL.md). Assets / MCP: [assets.md](../godot-composition-first/assets.md).

## Antes de dibujar o usar MCP (obligatorio)

**No** instales Aseprite MCP, **no** abras tools de Aseprite y **no** crees sprites hasta que el usuario diga que sí.

1. Preguntá (AskQuestion si está): ¿querés que cree / anime sprites ahora (Aseprite MCP), o alcanza un placeholder?
2. Si dice **no**: `PlaceholderTexture2D` / ColorRect y seguí con código. No insistas.
3. Si dice **sí**: pedí **referencias** antes de un solo píxel — imágenes, URLs, paleta, tamaño (p. ej. 16 / 32 / 48), estilo, qué ciclos (idle, walk, jump, attack), mood. Sin referencias, **no inventes** un look: preguntá de nuevo.
4. Recién ahí instalá o usá el MCP. Exportá al **proyecto Godot**.

## Los 12 Principios Básicos

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

## Cómo aplicarlos

En Aseprite (MCP): paleta y silueta primero (12, 11). Poses clave (4), squash en el impacto (1), frame de anticipación (2), ease en los extremos (6), trayectoria curva (7), pelo/ropa un frame tarde (5), un detalle extra que no compita (8), duración de frame = peso (9), pose más fuerte que la real (10). El clip se lee solo (3). `export_frame` a 8×; onion skin entre poses.

En Godot: spritesheet / `SpriteFrames` → `AnimatedSprite2D`. Motion de nodos (cámara, squash de escala, arcos) → `AnimationPlayer` con interpolación. 3D: mesh/animación desde Blender MCP (solo con OK) exportado a `.glb`; mismos principios (1–12) en poses y curvas. No animes gameplay en un shader de otro pass.

Un ciclo = un tag / un `SpriteFrames` animation. Idle no es un solo frame estático si el personaje debe vivir (8, 9).
