# Changelog de GrassKit

## 0.1.0

- **GrassField3D**: pasto alrededor de la cámara en la GPU, en celdas cuadradas que se mueven con ella.
  - Por tipo de hoja, un MultiMesh compartido por tier, cada tier un prefijo de las mismas hojas repartidas parejo, así nada aparece de golpe.
  - Los límites de cada celda se ajustan a su suelo, así el renderer la descarta.
  - Centrado donde mira la cámara (nunca más adelante de lo alta que está), o en un nodo `center`.
  - `enabled` libera todas las celdas. No se dibuja nada headless ni en un servidor dedicado.
  - En el editor sigue a la cámara de la vista 3D dentro de `editor_radius`.
  - `stats`: celdas, hojas, draws, en total, a la vista y por tipo.
- **GrassGround**: el suelo sobre `area`, en una textura float (altura, normal, suelo).
  - Horneado desde los colliders (alturas exactas) o escrito desde los datos del juego (`set_heights`).
  - `slope_fade` raleа y acorta el pasto en suelo empinado.
  - `density_texture` y `size_texture` pintadas, y la `color_texture` del suelo.
  - `area_changed` para una parte que cambió en el juego, con la textura subida una vez por frame.
  - `bake_cost()`, y un aviso en el inspector para un horneado grande.
- **GrassLook**: un `.tres` por look (un bioma, una estación, una paleta), todo uniforms, así cambiar de look no reconstruye nada.
  - Forma: alturas de 0,25 a 0,8 m, ancho, inclinación, `align_to_normal`, matas.
  - Color: base, punta, variación, el tinte del suelo, y un color que comparten el pasto lejano y el suelo.
  - Luz: translucidez, sombra en la raíz, redondez, engrosado según la vista.
  - Viento: respuesta, aleteo, luz de las ráfagas.
- **GrassMesh**: tipos de hoja mezclados por peso (la hoja del kit o cualquier malla), cada uno un prefijo de su parte.
  - Tamaño, una máscara de dónde crece.
  - Texturas albedo, normal y ORM, alpha scissor con sombras recortadas, tinte, cuánto se aplica la paleta, y doblado desde el color de vértice.
- **GrassWind**: el viento del mundo, compartido con uniforms globales de shader.
  - Bandas de ruido sin costuras viajan a su velocidad, y las ráfagas las coronan.
  - Los cambios entran mezclándose en `blend_time` y el patrón nunca salta.
  - `time_override` lo congela; se detiene con la pausa.
  - `grass_wind.gdshaderinc` para cualquier shader; `grass_ground.gdshaderinc` deja que el suelo del juego se encuentre con el color del pasto lejano y lleve las bandas de las ráfagas.
- **GrassQuality**: densidad, radio, densidad cercana y lejana, celdas, tiers (8), segmentos (a la mitad en cada paso hacia afuera, mezclados antes de un cambio), `min_blade_pixels`, `near_fade`, sombras; `preset()`, `blades_in_ring()`, `describe()`.
- **Claros** por grupo (`GrassClearing`) y a mano (`GrassClear3D`, con su gizmo); **pisoteo** por grupo, cada cuerpo con su propio ancho.
- **El shader de la hoja**:
  - Salidas tempranas, la más barata primero, con una sola lectura del suelo.
  - Una hoja Bézier cúbica a lo largo de la normal del suelo, el empuje y el aleteo del viento, el pisoteo.
  - Filas del LOD mezcladas con la forma más gruesa, engrosado en espacio de vista, normales redondeadas que tienden a la del suelo.
  - Ancho nunca menor a `min_blade_pixels`; más bajas cerca del lente y en el borde del anillo.
  - Nada de `instance uniform`. Forward+ y Compatibility.
- **Plugin**: gizmos, y los globales de shader de GrassKit agregados a Project Settings (solo los que faltan).
- **Ejemplo** `grass_3d`: tres looks (uno con flores), una tormenta, un cráter, pisoteo, claros, un shader de suelo que se encuentra con el pasto. **Tests**: `grasskit_lab` (31), y un chequeo del editor (`GRASSKIT_EDITOR_CHECK=1`).
