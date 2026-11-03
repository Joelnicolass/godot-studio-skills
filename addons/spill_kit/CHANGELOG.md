# Changelog de SpillKit

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
