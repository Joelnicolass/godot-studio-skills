---
name: godot-grass-kit
description: >-
  Dibuja pasto sobre un mundo 3D de Godot 4 con el addon GrassKit: hojas en la GPU
  alrededor de la cámara en celdas que se mueven con ella, pintado a mano con
  pinceles en la vista 3D (dónde crece, qué tan alto, el color del suelo, dónde
  crecen las flores), un suelo leído de los colliders (alturas exactas, normales,
  pendiente), cualquier malla como hoja con texturas PBR, un viento compartido,
  claros, pisoteo que se recupera y looks que cambian en el juego. Usar cuando el
  usuario quiere pasto, una pradera, flores entre el pasto, senderos en el pasto,
  pintar pasto, vegetación que se mece con el viento, pasto en laderas, pasto
  pisado, pasto que cuesta demasiado o /add-grass. No son props como árboles y
  rocas (PropKit) ni lo que significa el pasto para el juego.
---

# Godot — pasto (GrassKit)

Addon `addons/grass_kit/` en el proyecto del **juego**. Referencia: `addons/grass_kit/README.md`; API por pieza: [api.md](api.md).

Si el addon no está:

```bash
./install.sh --addon /path/to/godot-project grass_kit
```

Habilitá el plugin **GrassKit**. Pedido acotado: `/add-grass`. Composición: [godot-composition-first](../godot-composition-first/SKILL.md).

## Reglas

- **La persona pinta, el agente arma.** Dónde crece el pasto, los senderos, el pasto corto, el color del suelo y las manchas de flores se pintan a mano: seleccioná el GrassField3D y usá los pinceles arriba de la vista 3D (Grass, Height, Colour, Kind; Ctrl/Cmd borra, Shift suaviza, `[` `]` tamaño, `-` `=` fuerza). Nunca escribas esos mapas por código para el nivel de una persona; el agente agrega el campo, el look y los shaders, y le dice a la persona cómo pintar. El código pinta solo lo que el juego cambia en el juego (`ground.paint()` con un `GrassBrush`: una mancha quemada, un sendero gastado).
- **Un nodo, cuatro recursos.** Un `GrassField3D` en el origen con `ground` (GrassGround), `look` (GrassLook), `quality` (GrassQuality) y `wind` (GrassWind). Agregado en el editor se arma solo (`set_up()`: un suelo ajustado a los colliders, el look meadow, calidad media, un viento) y hornea cuando la escena está guardada.
- **Los looks son `.tres`.** Arrancá desde `addons/grass_kit/looks/` (meadow, autumn, lush, steppe); uno por bioma, estación o paleta. Tipos de hoja (`GrassMesh`: la hoja del kit o cualquier malla, texturas PBR, alpha scissor) mezclados por peso; un tipo con `map_name` crece donde lo pinta el pincel Kind, sumando sus hojas. Cambiar looks o valores son solo uniforms.
- **El viento es compartido.** Los árboles, las partículas y el suelo del juego lo leen con `#include "res://addons/grass_kit/field/grass_wind.gdshaderinc"`. El clima fija `wind.strength` y `wind.direction`; los cambios entran mezclándose.
- **El suelo del juego incluye `grass_ground.gdshaderinc`.** `grasskit_ground_color(rgb, xz, grass_here)` toma el color del pasto bajo las hojas (`look.under_grass`, `under_relief`) y se encuentra con el pasto lejano; `grasskit_painted_grass(xz)` muestra tierra en un sendero pintado. Una `color_texture` que hace el juego es el suelo *con* ese color.
- **El suelo son los colliders del juego.** «Bake ground» los lee (alturas exactas y normales); un juego con sus propios datos de altura llama a `ground.set_heights_image(image)` (rojo = metros; 4 veces más rápido que `set_heights(rect, sampler)`). `texel_size` de como mucho un cuarto de los triángulos del terreno; el inspector avisa cuando un horneado se agranda. El área sigue a los colliders (GrassKit ▸ Fit area) o a sus asas.
- **Un cambio en el juego es una llamada, no una reconstrucción.** Suelo: `field.ground_changed(position, radius)`. Look, paleta: asigná o editá el `GrassLook`. Calidad: asigná otro `GrassQuality`. Apagado: `enabled = false`.
- **Los claros y el pisoteo son grupos.** `clearings` ({group, radius, soft}), nodos `GrassClear3D` (su señal `changed` para la flora del juego), `trample_group` (el ancho propio de cada cuerpo con `grass_trample_radius`), `trample_recover` para que el pasto se vuelva a levantar. El kit nunca nombra una clase del juego.
- **Ningún kit depende de otro.** GrassKit no tiene red: cada peer dibuja el pasto desde el mismo suelo. No se dibuja nada headless ni en un servidor dedicado.
- **El costo son las hojas instanciadas.** Leé `field.stats` (hojas y draws, a la vista y por tipo) y la línea de costo de la calidad (botones Low / Medium / High en el inspector); bajá `density` o `radius` antes que cualquier otra cosa. Un tipo suma una draw por celda donde crece; las celdas despintadas no dibujan nada. Nada de `instance uniform` (WebGL).

## Árbol

```
World
├── Terrain              # colisión en la capa de ground.collision_mask
├── Grass                # GrassField3D (ground, look, quality, wind; sus celdas son internas)
├── Camp                 # en un grupo que nombra un GrassClearing
└── Units/…              # en trample_group
```

Arrancá desde `addons/grass_kit/examples/grass_3d/grass_3d.tscn`: su sendero, el pasto corto, las manchas de flores y la mancha seca se pintaron con los pinceles.

## Qué va dónde

| Kit | Juego |
|---|---|
| Hojas, celdas, tiers, el shader, la forma del viento | Qué significa el pasto (esconder, frenar), el clima que fija el viento |
| Leer el suelo (rayos o alturas), los pinceles y sus mapas | El terreno y cuándo cambia; lo que pinta la persona |
| Looks, presets de calidad, `enabled` | El menú de opciones y qué look usa un bioma |
| Claros y pisoteo por grupo | Qué nodos están en esos grupos |

## Listo cuando

- El campo no muestra avisos; `<escena>_grass_ground.res` está junto a la escena; el pasto se ve en el editor alrededor de la vista 3D.
- La persona sabe cómo pintar: seleccionar el campo, elegir un pincel, pintar, Ctrl borra, guardar la escena.
- F6: pasto alrededor de la cámara, nada en senderos pintados, en los claros ni en pendientes pasado `slope_fade`; hojas que se doblan alrededor de las unidades que pisan y se vuelven a levantar detrás.
- `print(field.stats)` y el costo de la calidad dan el costo; otro look cambia los colores con las mismas celdas; el viento se mezcla cuando cambia el clima.
- `godot --headless --path grasskit_lab --script res://addons/grass_kit/tests/grass_test_runner.gd` da `GRASSKIT TESTS PASS` (en el repo del kit).

## Anti-patrones

- Escribir como código o texturas generadas los senderos, las manchas de flores o las zonas peladas de una persona: los pinta con los pinceles, y los puede cambiar.
- Una malla de pasto por hoja o por mata como nodos: miles de draw calls en vez de unas pocas celdas.
- Reconstruir el campo para cambiar el color o el viento: cambiá el look o el viento.
- `alpha_scissor` en hojas comunes: opaco cuesta menos; dejalo para pétalos y tarjetas.
- Un shader del juego que declara sus propios uniforms de viento en vez de incluir `grass_wind.gdshaderinc`: el pasto y los árboles se mecen por separado.
- Hornear un mapa enorme con texels de 0,5 m: subí `texel_size` (un cuarto de los triángulos alcanza) o escribí las alturas con `set_heights_image`.
- La capa del terreno fuera de `ground.collision_mask`, o unidades dentro de ella: el horneado lee la altura equivocada.
- Mover el GrassField3D fuera del origen.
