---
name: godot-grass-kit
description: >-
  Dibuja pasto sobre un mundo 3D de Godot 4 con el addon GrassKit: hojas en la GPU
  alrededor de la cámara en celdas que se mueven con ella, un suelo leído de los
  colliders (alturas exactas, normales, pendiente), cualquier malla como hoja con
  texturas PBR, un viento compartido, claros, pisoteo y looks que cambian en el
  juego. Usar cuando el usuario quiere pasto, una pradera, flores entre el pasto,
  vegetación que se mece con el viento, pasto en caminos o laderas, pasto pisado,
  pasto que cuesta demasiado o /add-grass. No son props como árboles y rocas
  (PropKit) ni lo que significa el pasto para el juego.
---

# Godot — pasto (GrassKit)

Addon `addons/grass_kit/` en el proyecto del **juego**. Referencia: `addons/grass_kit/README.md`; API por pieza: [api.md](api.md).

Si el addon no está:

```bash
./install.sh --addon /path/to/godot-project grass_kit
```

Habilitá el plugin **GrassKit**. Pedido acotado: `/add-grass`. Composición: [godot-composition-first](../godot-composition-first/SKILL.md).

## Reglas

- **Un nodo, cuatro recursos.** Un `GrassField3D` en el origen con `ground` (GrassGround), `look` (GrassLook), `quality` (GrassQuality) y `wind` (GrassWind). No hay nada más que conectar.
- **Los looks son `.tres`.** Uno por bioma, estación o paleta; tipos de hoja (`GrassMesh`: la hoja del kit o cualquier malla, texturas PBR, alpha scissor) mezclados por peso. Cambiar looks o valores son solo uniforms.
- **El viento es compartido.** Los árboles, las partículas y el suelo del juego lo leen con `#include "res://addons/grass_kit/field/grass_wind.gdshaderinc"`; el suelo se encuentra con el pasto lejano con `grass_ground.gdshaderinc`. El clima fija `wind.strength` y `wind.direction`; los cambios entran mezclándose.
- **El suelo son los colliders del juego.** «Bake ground» los lee (alturas exactas y normales); un juego con sus propios datos de altura llama a `ground.set_heights(rect, sampler)`. `texel_size` de como mucho un cuarto de los triángulos del terreno; el inspector avisa cuando un horneado se agranda.
- **Un cambio en el juego es una llamada, no una reconstrucción.** Suelo: `field.ground_changed(position, radius)` (o `set_heights` en ese rect). Look, paleta: asigná o editá el `GrassLook`. Calidad: asigná otro `GrassQuality`. Apagado: `enabled = false`.
- **Los claros y el pisoteo son grupos.** `clearings` ({group, radius, soft}), nodos `GrassClear3D`, `trample_group` (el ancho propio de cada cuerpo con `grass_trample_radius`). El kit nunca nombra una clase del juego.
- **Ningún kit depende de otro.** GrassKit no tiene red: cada peer dibuja el pasto desde el mismo suelo. No se dibuja nada headless ni en un servidor dedicado.
- **El costo son las hojas instanciadas.** Leé `field.stats` (hojas y draws, a la vista y por tipo) y `quality.describe()`; bajá `density` o `radius` (o un preset) antes que cualquier otra cosa. Cada tipo de hoja suma una draw por celda. Nada de `instance uniform` (WebGL).

## Árbol

```
World
├── Terrain              # colisión en la capa de ground.collision_mask
├── Grass                # GrassField3D (ground, look, quality; sus celdas son internas)
├── Camp                 # en un grupo que nombra un GrassClearing
└── Units/…              # en trample_group
```

Arrancá desde `addons/grass_kit/examples/grass_3d/grass_3d.tscn`.

## Qué va dónde

| Kit | Juego |
|---|---|
| Hojas, celdas, tiers, el shader, la forma del viento | Qué significa el pasto (esconder, frenar), el clima que fija el viento |
| Leer el suelo (rayos o `set_heights`) | El terreno y cuándo cambia |
| Looks, presets de calidad, `enabled` | El menú de opciones y qué look usa un bioma |
| Claros y pisoteo por grupo | Qué nodos están en esos grupos |

## Listo cuando

- «Bake ground» guarda `<escena>_grass_ground.res` y el campo no muestra avisos; el pasto se ve en el editor alrededor de la vista 3D.
- F6: pasto alrededor de la cámara, nada en los claros ni en pendientes pasado `slope_fade`, hojas que se doblan alrededor de las unidades que pisan.
- `print(field.stats)` y `field.quality.describe()` dan el costo; otro look cambia los colores con las mismas celdas; el viento se mezcla cuando cambia el clima.
- `godot --headless --path grasskit_lab --script res://addons/grass_kit/tests/grass_test_runner.gd` da `GRASSKIT TESTS PASS` (en el repo del kit).

## Anti-patrones

- Una malla de pasto por hoja o por mata como nodos: miles de draw calls en vez de unas pocas celdas.
- Reconstruir el campo para cambiar el color o el viento: cambiá el look o el viento.
- `alpha_scissor` en hojas comunes: opaco cuesta menos; dejalo para pétalos y tarjetas.
- Un shader del juego que declara sus propios uniforms de viento en vez de incluir `grass_wind.gdshaderinc`: el pasto y los árboles se mecen por separado.
- Hornear un mapa enorme con texels de 0,5 m: subí `texel_size` (un cuarto de los triángulos alcanza) o escribí las alturas con `set_heights`.
- La capa del terreno fuera de `ground.collision_mask`, o unidades dentro de ella: el horneado lee la altura equivocada.
- Mover el GrassField3D fuera del origen.
