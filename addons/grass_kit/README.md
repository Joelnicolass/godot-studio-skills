# GrassKit

Pasto para mundos 3D, dibujado en la GPU alrededor de la cámara:
- **Celdas:** las hojas están en celdas cuadradas que se mueven con la cámara.
- **Distancia:** las celdas cercanas tienen más hojas, las lejanas menos y más anchas, y nada salta.
- **El suelo:** sale de los colliders del juego: alturas exactas, la pendiente y la normal por la que crecen las hojas.
- **El viento:** un viento compartido las mueve, y el suelo, los árboles o las partículas del juego pueden leer el mismo viento.
- **Las hojas:** la hoja propia del kit, o cualquier malla con texturas PBR, mezcladas por peso.

No tiene red, reglas de juego ni autoload, y GrassKit no depende de ningún otro kit.

```bash
./install.sh --addon /path/to/godot-project grass_kit
```

Habilitá el plugin **GrassKit**. Agrega los uniforms globales de shader de GrassKit a Project Settings (solo los que falten), y gizmos para los círculos de un claro y el área del suelo. Los nodos funcionan sin él.

**Ejemplo:** `examples/grass_3d/grass_3d.tscn`. Lomas de pasto con:
- un caminante que pisa un sendero;
- campamentos despejados por grupo, y un claro puesto a mano;
- un montículo demasiado empinado para el pasto;
- un suelo que se encuentra con el pasto lejano.

Teclas:
- **1 2 3:** calidad.
- **L:** el look siguiente (verano, otoño, flores).
- **T:** una tormenta que sube o se calma.
- **G:** pasto apagado y prendido.
- **C:** un cráter bajo el mouse.

## Empezar

1. Agregá un **GrassField3D** al mundo, en el origen.
2. Poné **ground**: un `GrassGround` con `area` (x, z en metros) sobre el terreno y el `collision_mask` del terreno.
3. Apretá **Bake ground** en el inspector. Lee el terreno cada `texel_size` metros desde sus colliders y lo guarda junto a la escena.
4. Poné **look**, **quality** y **wind**: un `GrassLook`, un `GrassQuality` (o `GrassQuality.preset(GrassQuality.Level.MEDIUM)` desde código) y un `GrassWind`.

El pasto se ve en el editor alrededor de la cámara de la vista 3D, con un radio menor (`editor_radius`).

## En el juego

| Querés | Escribí |
|---|---|
| Cambiar de bioma, estación o la paleta de un dios | `field.look = autumn` (un `.tres`), o `field.look.tip_color = …`: solo uniforms |
| Levantar una tormenta | `field.wind.strength = 1.3`, `field.wind.direction = …`: entra mezclándose en `blend_time` |
| Que el jugador elija la calidad | `field.quality = GrassQuality.preset(GrassQuality.Level.LOW)` |
| Apagar el pasto desde las opciones | `field.enabled = false`: se liberan todas las celdas |
| Un cráter o un montículo cambió el suelo | `field.ground_changed(position, radius)`: vuelve a leer los colliders ahí |
| Escribir el suelo desde los datos propios del juego | `field.ground.set_heights(rect, func(x, z): return terrain.height_at(x, z))` |
| Despejar el pasto alrededor de edificios o puntos de aparición | `clearings`: un `GrassClearing` {group, radius, soft}; o un nodo `GrassClear3D` |
| Que las unidades aparten el pasto | `trample_group`, `trample_radius` (o `grass_trample_radius` en la unidad) |
| Centrar el pasto en lo que sigue una cámara de RTS | `field.center = unit` |
| Mover árboles, partículas o el suelo con el mismo viento | `#include "res://addons/grass_kit/field/grass_wind.gdshaderinc"` |
| Que el suelo se encuentre con el pasto lejano | `#include "res://addons/grass_kit/field/grass_ground.gdshaderinc"` |
| Ver cuánto cuesta | `print(field.stats)`, `field.quality.describe()` |

## El suelo (`GrassGround`)

Dónde crece el pasto y qué tan alto está el suelo, sobre `area`.

- **Alturas.** `bake()` (el botón Bake ground, o `field.bake_ground()` desde código) tira un rayo hacia abajo en cada texel contra `collision_mask`. Guarda la altura exacta, la normal del suelo y si había suelo, todo en una textura float (`data`), así una hoja la lee una sola vez. Un juego con sus propios datos de altura la escribe con `set_heights(rect, sampler)`; `sampler` es `func(x, z) -> float`, NAN donde no hay suelo.
- **Resolución.** Con `texel_size` de como mucho un cuarto de los triángulos del terreno, una raíz queda a menos de 5 cm del suelo exacto, aun en laderas empinadas y ásperas (`test_roots_sit_on_the_ground` lo mide a 30° y 60°). Sobre un plano la lectura es exacta a cualquier pendiente; el error solo viene de los pliegues entre triángulos.
- **Tamaño.** `bake_cost()` dice cuántos rayos tira un horneado completo y cuántos megabytes guarda (16 bytes por texel), y el inspector avisa por encima de 64 MB. Un mapa de 2560 m a 0,5 m son 26 millones de rayos y 400 MB; a 2,5 m son 16 MB.
- **Pendientes.** `slope_fade` (grados): desde el primero, las hojas ralean y se acortan; pasado el segundo, no hay. Las hojas crecen siguiendo la normal del suelo en su base (`look.align_to_normal`) y se enderezan hacia la punta. Su ancho se apoya en la ladera, así ninguna base se hunde en una cuesta.
- **Mapas pintados**, estirados sobre `area`:
  - `density_texture` (rojo): blanco = pasto, negro = nada.
  - `size_texture` (rojo): 0,5 = como dice el look, negro = al ras, blanco = el doble de alto. Sirve para pasto corto en los caminos.
  - `color_texture`: el color propio del suelo, que entra en la base de las hojas. Hacelo como el juego pueda: su mapa de albedo, o su shader de suelo renderizado una vez desde arriba. Cambiarlo en el juego (otro bioma) cambia un uniform.
- **Cambios en el juego.** `bake(space, rect)` y `set_heights(rect, …)` emiten `area_changed(rect)` en el momento. El campo les da cajas nuevas solo a las celdas de ahí. La textura sube a la GPU una sola vez al final del frame, por más cambios que haya tenido.

## El look (`GrassLook`)

Un `.tres` para duplicar y editar en el inspector; un juego tiene varios (una pradera, un desierto, nieve, flores) y los cambia en el juego.

- **Forma:** `height_range` (de 0,25 a 0,8 m por defecto, lo justo para un RTS), `width`, `tip_width`, `lean`, `align_to_normal`, `clump_size`. Las hojas de un clump son más altas cerca de su centro, se inclinan hacia afuera y comparten su tono.
- **Color:**
  - `base_color` y `tip_color`, con `color_variation`;
  - `ground_tint` (cuánto del color del suelo se ve en la base) y `ground_color` (cuando el suelo no tiene textura de color);
  - `fade_to_ground` y `far_grass` (dónde se encuentran el pasto lejano y el suelo del juego, abajo);
  - `roughness`.
- **Luz:** `translucency` (la luz que pasa a través de las hojas desde atrás, más en la punta fina), `root_shade`, `roundness` (la normal de una hoja se abre hacia sus bordes), `view_thicken` (las hojas vistas de canto se ensanchan, así un campo nunca se ve ralo de costado).
- **Viento:** `wind_response`, `flutter` (el temblor propio de cada hoja, cruzado al viento), `gust_lighten` (las ráfagas aclaran las puntas y su brillo, así las olas se leen de lejos).
- **Mallas:** los tipos de hoja (abajo).

Cada valor es un uniform del shader: otro look, o un valor cambiado, no reconstruye nada. Solo otras mallas, u otros pesos, vuelven a armar las mallas del campo.

## Tipos de hoja (`GrassMesh`)

`look.meshes` mezcla tipos de hoja por `weight`: por ejemplo 90 % la hoja del kit, 8 % una mata, 2 % una flor. Vacío es solo la hoja del kit.

- **La malla.** `mesh` es cualquier malla, como un `.glb` de Blender: y hacia arriba, la raíz en y 0. Se escala a la altura de hoja del look (por `size`) y se gira al azar. Su base crece siguiendo la normal del suelo y su punta queda derecha. El viento y el pisoteo la doblan más cuanto más alto está un vértice, o según el rojo de su color de vértice con `bend_from_color`. Vacío = la hoja del kit, una curva Bézier cúbica.
- **Material.**
  - `albedo_texture`, `normal_texture`, `orm_texture` (oclusión, rugosidad, metálico);
  - `tint`;
  - `alpha_scissor` para pétalos o tarjetas recortadas. Usa el shader de recorte, y la sombra de la hoja también sale recortada. Dejalo en 0 para hojas comunes: opaco cuesta menos.
- **La paleta.** `palette` es cuánto la tiñen los colores del look: 1 para hojas, 0 para una flor con sus propios colores.
- **Dónde.** `mask_texture` (rojo sobre el área del suelo) dice dónde crece ese tipo: flores solo en una pradera.
- **Cómo se reparten las hojas.** Cada hoja de la secuencia compartida pertenece a un tipo por un sorteo fijo sobre los pesos. Así cada tipo es un prefijo de su propia parte, y la densidad sigue cambiando suave con la distancia.
- **Para copiar:** `examples/grass_3d/flower.tres` es una flor hecha así (`flower_mesh.tres`, `flower_petals.png`, alpha scissor 0,5, palette 0), y el look de flores del ejemplo la pone al 3 % entre las hojas.

## El viento (`GrassWind`)

El viento del mundo, compartido: el campo lo hace avanzar, y cualquier shader puede leerlo.

- **Ajustes:** `direction`, `strength` (0 calma, 1 tormenta), `speed` (qué tan rápido viajan las bandas), `scale` (el tamaño de una banda) y `noise` (una textura sin costuras; vacío = la del kit).
- **Sin saltos.** La posición del patrón se acumula frame a frame, así una dirección o velocidad nueva nunca hace saltar el campo. Una dirección o fuerza nueva se alcanza en `blend_time`.
- **Congelado.** `time_override` (0 o más) lo congela, para tests y capturas.
- **Pausa.** Se mueve con el procesamiento del campo, así que se queda quieto mientras el árbol está en pausa (process mode por defecto). Poné el campo a procesar siempre para que siga soplando.
- **Compartido.** Varios campos pueden compartir un viento; avanza una vez por frame.
- **En las hojas.** Una brisa constante más ráfagas donde crestan las bandas del ruido. Cada hoja además tiembla cruzada al viento con su propia fase, y las ráfagas aclaran las puntas por donde pasan.
- **Para otros shaders.** `field/grass_wind.gdshaderinc` da `grasskit_wind_wave(xz)` (0..1), `grasskit_wind_gust(xz)` y `grasskit_wind_push(xz)`.
- **Para el suelo.** `field/grass_ground.gdshaderinc` da `grasskit_ground_color(rgb, xz, grass_here)`, que lleva el suelo al color al que se funde el pasto lejano para que el borde del pasto dibujado nunca se vea, y `grasskit_ground_bands(xz, amount)`, bandas pálidas donde las ráfagas cruzan el suelo. Las lomas del ejemplo usan las dos.

Los valores son uniforms globales de shader (`grasskit_wind`, `grasskit_wind_offset`, `grasskit_wind_time`, `grasskit_wind_noise`, `grasskit_field`, `grasskit_grass`). El plugin agrega a Project Settings los que falten y no toca ningún otro; al deshabilitarlo los deja, por si un shader del juego los lee. Sin el plugin, un campo los declara antes de que compilen sus propios shaders.

## La calidad (`GrassQuality`)

| Ajuste | Qué hace |
|---|---|
| `density` | Hojas por m² cerca del centro |
| `radius`, `near_radius`, `far_density` | Densidad completa hasta `near_radius`, raleando hasta `far_density` en `radius`, nada más allá |
| `cell_size`, `tiers` | Las celdas del anillo, y cuántos grupos de menos hojas por distancia |
| `segments` | Los segmentos de las hojas más cercanas (1, 2, 4 u 8), a la mitad en cada paso hacia afuera hasta un solo triángulo |
| `min_blade_pixels` | Las hojas lejanas se ensanchan en vez de quedar por debajo de esta cantidad de píxeles (sin parpadeo) |
| `near_fade` | Las hojas así de cerca de la lente se achican hasta el suelo, así ninguna tapa la pantalla |
| `cast_shadows` | Las hojas proyectan sombras |

`preset(LOW | MEDIUM | HIGH)` da tres listas para usar. `blades_in_ring()` dice cuántas hojas instancia un anillo entero, y `describe()` lo pone en una línea para un log.

`field.stats` (GrassStats) cuenta lo que se dibuja ahora:
- celdas y hojas, en total y a la vista;
- las hojas a la vista de cada tipo;
- las draw calls (una por tipo por celda a la vista: un tipo agregado a un look suma una draw por celda).

Las hojas están instanciadas, así que su vertex shader corre aunque después el shader las ralee; las que están a la vista son las que paga la GPU.

## Cambios suaves

Ningún cambio con la distancia o en el juego es un escalón:

- **Densidad:** una hoja se va cuando su rango pasa la densidad. Es la misma hoja en cada tier, así tener menos hojas nunca salta, y las que quedan se ensanchan.
- **Segmentos:** antes de que una celda pase a una malla con la mitad de segmentos, cada fila que le falta a la malla más gruesa ya se mezcló con sus vecinas.
- **El borde:** las hojas se acortan hasta desaparecer en el radio.
- **Color a la distancia:** las hojas se funden a un color entre el del suelo y el del pasto (`GrassLook.average_color()`). El suelo del juego se funde al mismo con `grass_ground.gdshaderinc`, así el pasto dibujado y el suelo de más allá se juntan sin costura.
- **El viento:** acumulado y mezclado, nunca reiniciado.

## Claros y pisoteo

- **Por grupo:** `clearings`, una lista de `GrassClearing` {group, radius, soft}. No hay pasto a menos de `radius` de cada nodo del grupo, y vuelve a la densidad completa a lo largo de `soft`. Los nodos se vuelven a leer cada medio segundo, así un edificio puesto en el juego despeja su suelo.
- **A mano:** un nodo `GrassClear3D` con `radius` y `soft`. El editor dibuja sus dos círculos.
- **Los dos** cuentan juntos, hasta 48 claros.
- **Pisoteo:** los nodos de `trample_group` cerca del campo doblan el pasto alejándolo de ellos. Cada uno pisa `trample_radius` de ancho, o su propio `grass_trample_radius` (propiedad o meta). Hasta 48 a la vez.

## En el editor

- **Bake ground** lee los colliders y guarda el suelo junto a la escena. El inspector avisa mientras el suelo es plano, y cuando un horneado sería demasiado grande.
- El pasto sigue a la cámara de la vista 3D dentro de `editor_radius`. Sus celdas son internas y nunca se guardan. `editor_preview` apagado lo oculta.
- Gizmos: los círculos de un GrassClear3D, el área del suelo.

## Rendimiento

El pasto cuesta por hoja instanciada: en un vertex shader cada vértice de una hoja vuelve a hacer el trabajo de la hoja. Los píxeles importan poco; renderizar a un cuarto de los píxeles ahorró menos del 10 % acá.

Lo que lo mantiene bajo:

- **Mallas:** un MultiMesh por tier y por tipo, compartido por todas las celdas, y un material por tipo.
- **Celdas:** cruzar una celda solo mueve nodos, y la caja de cada celda se ajusta a su suelo, así el renderer descarta las que no se ven.
- **Lo más barato primero:** el shader decide si una hoja se dibuja con la distancia y el rango, y después una sola lectura del suelo. Solo las hojas que quedan hacen los clumps, el viento y el pisoteo. Una hoja que no se dibuja colapsa a un punto.
- **Sin discard:** las hojas son opacas y de dos caras, y solo los tipos con `alpha_scissor` descartan.

**Medido** en una Mac M4 a 1280×720, renderer Compatibility, sin vsync, en el ejemplo. La calidad MEDIUM instancia unas 200 000 hojas, 175 000 a la vista:

| Qué | Costo |
|---|---|
| El pasto | unos 5,4 ms por frame |
| Las sombras del sol sobre él | unos 1,1 ms de eso |
| Los clumps | 0,4 ms |
| Cuatro segmentos contra uno | 1,4 ms |

**Qué ajustar:**
- el costo escala con `density` y `radius`, así que un preset es la primera perilla;
- `cast_shadows` queda apagado;
- un tipo de hoja suma una draw por celda.

Con un depth prepass (Forward+) el vertex shader de cada hoja corre dos veces; un juego con mucho pasto puede medir con `rendering/driver/depth_prepass/enable` apagado.

**WebGL y la web.** Nada usa `instance uniform`, que WebGL limita: las hojas leen custom data del MultiMesh y uniforms de material (un test lo verifica).

**No se dibuja nada headless ni en un servidor dedicado.** `can_draw()` lo dice, y los tests ponen `GrassField3D.draw_anywhere`.

## De dónde vienen las ideas

La charla sobre el pasto de Ghost of Tsushima (Eric Wohllaib, GDC 2021) y los análisis de esa charla dieron forma a casi todo esto:
- hojas Bézier con inclinación y arco;
- clumps de Voronoi que fijan altura, tono e inclinación;
- un solo viento de ruido desplazado, compartido por todo, más un balanceo por hoja;
- hojas que se descartan y se ensanchan con la distancia, y vértices de LOD mezclados antes de un cambio;
- engrosado en espacio de vista y normales redondeadas que tienden a una común a lo lejos;
- un suelo lejano que toma el color del pasto.

El pigmento desde el color del suelo sigue a The Witcher 3. Breath of the Wild no tiene una fuente técnica pública; su aspecto (colores planos de la base a la punta, clumps, olas de viento que se leen de lejos) es la referencia de los valores por defecto.

## Tests

```bash
godot --headless --path grasskit_lab --script res://addons/grass_kit/tests/grass_test_runner.gd
```

El resultado es `GRASSKIT TESTS PASS (n)`. Los tests cubren:

- **la calidad**: la curva de densidad, tiers que son prefijos, presets, la cuenta del anillo;
- **las celdas y las hojas**:
  - el anillo cubre su círculo;
  - el patrón compartido se reparte parejo en cualquier prefijo, y cada tier es un prefijo de él;
  - los tipos se reparten las hojas por peso;
  - los segmentos bajan a la mitad y se mezclan donde una celda puede cambiar;
- **el suelo**:
  - plano;
  - escrito desde los datos del juego, con normales y pendientes;
  - horneado desde colliders, y vuelto a hornear en una parte;
  - raíces a menos de 5 cm del suelo exacto a 30° y 60°;
  - cambios en un frame subidos una sola vez;
  - el costo del horneado;
- **el campo**:
  - celdas que siguen a la cámara sin mallas nuevas, y cajas que se ajustan al suelo;
  - las cuentas y las draws por tipo, enabled apagado;
  - un look nuevo sin reconstruir, tipos de hoja con sus shaders;
  - una parte del suelo cambiada;
  - claros, pisoteo, el ancho propio de cada cuerpo;
  - dónde se centra el anillo, un tamaño pintado;
  - el viento (compartido, suave, congelado, quieto con la pausa);
  - nada headless;
- **ningún instance uniform** en los shaders;
- **el ejemplo, de punta a punta.**

Las herramientas del editor tienen su propio chequeo en un editor real. Cubre el pasto alrededor de la cámara de la vista 3D, el aviso de suelo plano, Bake ground y el archivo que guarda, y el gizmo del claro:

```bash
GRASSKIT_EDITOR_CHECK=1 godot --headless --editor --path grasskit_lab
```

Imprime `EDITOR CHECK PASS`. Los shaders en sí (la hoja, la de recorte, el suelo del ejemplo) se verifican en una ventana, en Forward+ y en Compatibility, corriendo el ejemplo, incluida la sombra recortada de una flor.

## Lo que no está en el kit

Esto es del juego:

- qué significa el pasto para el juego (esconder unidades, frenarlas);
- su terreno, y cuándo cambia;
- su clima, que fija el viento;
- el menú de opciones que fija la calidad.
