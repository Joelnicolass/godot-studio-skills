# Changelog de SpillKit

## 0.2.0

Lo que encontró El Eternauta al planificar su migración.

- **La salpicadura fuerte se ajusta aparte.** El tipo tiene un grupo Heavy spray con sus propios valores: `heavy_drop_size_m`, `heavy_drop_speed_m_s`, `heavy_spread_deg`, `heavy_rise_deg`, `heavy_drop_life_s`, `heavy_drop_scale_min`/`max`. Antes era la liviana multiplicada por `heavy_scale`, que ya no existe. El rango de tamaño de las gotas livianas también es del tipo (`drop_scale_min`/`max`, 0,6 a 1,4), y `rise_deg` pasa de 50° a 51°.
- **El alcance del piso, por componente.** `SpillSource3D.floor_reach_m`: hasta dónde debajo de él puede estar el piso de sus manchas y su charco (0 = el del pool). Un bicho con el componente a 0,8 m y un jugador a 1,25 m dejan de manchar en el aire a la misma altura sobre sus pies. `spill()` y `puddle()` del pool toman un `reach_m` opcional.
- **El pool del nivel reemplaza al que se armó solo.** Si un cuerpo entraba antes que el pool de su mundo (una escena persistente con los jugadores y el nivel cargado después), el pool armado con los valores de entrada se quedaba con el mundo y el del nivel no dibujaba nada. Ahora el del nivel toma su lugar.
- **Tests:** 42.

Qué actualizar: si un tipo cambió `heavy_scale`, pasá sus valores al grupo Heavy spray. Con los de entrada, un golpe fuerte sale como en la 0.1 pero un poco más rápido (3 m/s), más largo (0,85 s), más bajo (45°) y con gotas algo más grandes (0,7 a 1,6), como la sangre de El Eternauta.

## 0.1.1

- **Un shader de gotas propio que toma el color de la partícula ya no avisa** (lo encontré revisando la migración de El Eternauta). Su `blood_drop.gdshader` usa `COLOR`, el color de cada gota, y no declara `albedo_tex` ni `albedo_color`. Con eso en `drop_material`, la 0.1.0 avisaba que le faltaban esos uniforms, aunque las gotas se dibujaban bien. Ahora solo los pide un shader de manchas o de charco; uno de gotas recibe los que declare.
- **Tests:** 39 (`test_a_drops_shader_that_takes_its_colour_from_the_particle`).

Qué actualizar: nada.

## 0.1.0

La primera versión, pedida por El Eternauta: la sangre de su RFC-041, hecha genérica para cualquier sustancia.

- **`SpillType`:** una sustancia en el inspector (sangre, icor, aceite, baba, tinta). Define su color, cómo vuelan sus gotas, sus manchas y su charco, y cómo se ven:
  - el aspecto húmedo del kit, con normales propias;
  - texturas PBR propias (albedo, normal, ORM) para las gotas, las manchas y el charco;
  - o el material del juego (su shader PS1), que recibe la textura y el color por `texture_parameter` y `color_parameter`.
- **`SpillSource3D`:** el componente del cuerpo.
  - `hit(damage, max_hp, from, heavy)` aplica las reglas: fuerte desde `heavy_from` (40 %) o por el golpe, livianas separadas por `every_s` (0,25 s), golpecitos que se suman hasta `min_lost`.
  - `die()` hace crecer un charco; `spray()` salpica sin reglas.
  - Una sola propiedad para la red, `wound`: cada máquina dibuja lo que cambió, y quien entra tarde no ve nada viejo.
  - Su propio cuerpo nunca recibe manchas.
- **`SpillPool3D`:** el que dibuja un mundo. Todo se arma una vez por tipo y se reusa:
  - las salpicaduras, anillos de CPUParticles3D;
  - las manchas, un MultiMesh por tipo que reusa la más vieja;
  - los charcos, un anillo que crece y se achica para no subirse a un cordón, sobre la pendiente del piso.

  Ninguna mancha cae detrás de un muro. `shown` es la opción del jugador y `clear()` arranca una ronda nueva. `spill()` y `puddle()` andan sin componente. Precalienta los shaders de cada tipo al cargar, así el primer golpe no traba. En un servidor dedicado no arma nada.
- **`SpillRules`, `SpillWound`, `SpillShapes`, `SpillMaterials`:** la regla, el valor empaquetado, las formas propias del kit y los materiales, públicos y puros.
- **Editor:**
  - los botones «Try it» (Spray, Heavy spray, Die (puddle), Clear the floor) dibujan en la vista 3D, sobre el piso de la escena;
  - el costo en el inspector del pool y del componente;
  - avisos por un tipo que falta, una `floor_mask` vacía, un segundo pool, un charco muy chico, tamaños de mancha al revés y un shader propio sin sus uniforms.
- **Compatibility y WebGL 2;** nada se dibuja en un servidor dedicado.
- **Ejemplos:** `minimal_3d` y `substances_3d` (sangre, aceite, baba, mercurio, pintura PBR, tinta con shader propio), y seis tipos en `examples/types/`.
- **Tests:** 38, y un chequeo del editor (27 chequeos).
