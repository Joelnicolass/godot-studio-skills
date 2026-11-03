# SpillKit

Lo que derrama un cuerpo, en 3D: sangre, icor, aceite, baba, tinta.
- **Cada golpe** salpica gotas y deja manchas en el piso, que quedan toda la partida.
- **Al morir** crece un charco: sigue la pendiente del piso, se achica para no subirse a un cordón y, si al lado del cordón no entra, se corre al piso plano más cercano del lado del cuerpo.
- **Cada sustancia es un tipo** (`SpillType`) en el inspector: su color, cómo vuelan sus gotas, sus manchas, su charco y cómo se ven. Puede tener el aspecto húmedo del kit (con normales propias), tus texturas PBR (albedo, normal, ORM) o el material de tu juego (un shader PS1).
- **Las reglas son valores** del componente: golpe fuerte desde el 40 % de la vida, salpicaduras livianas cada 0,25 s como mucho, golpecitos que se suman.
- **Una sola propiedad para la red:** `wound`. Cada máquina dibuja lo que cambió, y quien entra tarde no ve nada viejo.
- **En el editor:** botones para probarlo en la vista 3D, el costo en el inspector y avisos.

Anda en Compatibility y en WebGL 2: usa CPUParticles3D, MultiMesh y quads con materiales estándar, que se dibujan igual en todos los renderers. En un servidor dedicado no dibuja nada. No tiene código de red ni autoload, y SpillKit no depende de ningún otro kit. Tres llamadas son todo lo que escribe el juego: `hit()`, `die()` y, en red, sincronizar `wound`.

```bash
./install.sh --addon /path/to/godot-project spill_kit
```

Habilitá el plugin **SpillKit** para la línea de costo del inspector. Los nodos, sus botones y sus avisos andan sin él.

**Ejemplos:**

- `examples/minimal_3d/minimal_3d.tscn`: lo mínimo, un muñeco que sangra (abajo, [Ejemplo mínimo](#ejemplo-mínimo)).
- `examples/substances_3d/substances_3d.tscn`: seis sustancias lado a lado, un tipo cada una:
  - **sangre:** un tipo con solo su color, el aspecto húmedo del kit;
  - **aceite:** negro y brillante, con un charco grande y lento;
  - **baba:** verde y translúcida, de bordes suaves, al lado de un cordón (su charco se achica para no subirse);
  - **mercurio:** un metal, sobre una rampa (su charco sigue la pendiente);
  - **pintura:** un tipo PBR con sus propias texturas de albedo, normal y ORM;
  - **tinta:** con un shader propio del juego (plano y en bandas), como pone un juego su material PS1.

  Teclas:
  - **Clic en un muñeco, o 1 a 6:** un golpe (clic derecho o Shift: fuerte).
  - **Espacio:** un golpe a todos. **K:** mueren todos. **R:** una ronda nueva.
  - **L:** una linterna desde la cámara. **N:** noche. **Izquierda y derecha:** girar alrededor.
- `examples/types/`: los seis tipos, para copiar.

## Empezar

1. **Creá un tipo.** En el FileSystem: clic derecho → Nuevo recurso → `SpillType`, por ejemplo `blood.tres`. Ponele un color: con eso ya se ve húmedo. O copiá uno de `examples/types/`.
2. **Agregá un `SpillSource3D`** en el cuerpo, donde salen las gotas (el pecho, el caparazón), y asignale el tipo.
3. **Agregá un `SpillPool3D`** al nivel (uno por mundo) y listá en `types` los tipos que usa. Si falta, el primer componente arma uno con los valores de entrada y lo avisa; si el nivel trae el suyo más tarde, el del nivel toma su lugar.
4. **Llamá `hit(daño, vida_máxima, desde)`** donde el juego saca vida, y **`die()`** cuando el cuerpo muere.
5. **Probalo en el editor:** seleccioná el componente y apretá **Spray**, **Heavy spray** o **Die (puddle)** en su grupo «Try it». Las gotas, las manchas y el charco aparecen en la vista 3D, sobre el piso de tu escena.

## Ejemplo mínimo

`examples/minimal_3d/minimal_3d.tscn` (F6): un muñeco en un piso. Un clic es un golpe del 20 %, un clic derecho uno del 50 % (fuerte), K lo mata y R limpia el piso.

```
Minimal3D (minimal_3d.gd)
├── WorldEnvironment, Sun, Camera3D
├── Floor (StaticBody3D)               # en la capa 1: el piso que buscan las manchas
├── SpillPool3D                        # types: [blood.tres]
├── Dummy (StaticBody3D)               # en la capa 2: los rayos del piso no lo ven
│   └── Spill (SpillSource3D)          # en el pecho, a 1,25 m; type: blood.tres
└── Label
```

```gdscript
# minimal_3d.gd (lo esencial)
func strike(damage: float) -> void:
	hp -= damage
	spill.hit(damage, MAX_HP, camera.global_position)  # las gotas vuelan lejos de vos
	if hp <= 0.0:
		spill.die()                                     # un charco crece debajo
```

**Tips del ejemplo:**
- `hit()` decide si sangra y cuánto. Dos clics más juntos que `every_s` salpican una sola vez, y uno del 40 % o más es fuerte (3 manchas en vez de 1).
- El tercer argumento es de dónde vino el golpe: el punto del impacto o el atacante. Las gotas vuelan para el otro lado.
- El cuerpo del muñeco se encuentra solo (el cuerpo de física más cercano arriba del componente), así que los rayos que buscan el piso lo atraviesan.

## Red

El kit no tiene red. Un juego en red llama a `hit()` y `die()` solo donde se decide el daño (el servidor) y sincroniza una propiedad del componente, `wound` (un `Vector4`). Cada máquina dibuja lo que cambió: la salpicadura y sus manchas, o el charco. Una máquina que se encuentra con el cuerpo tarde arranca desde el valor que trae y no dibuja nada viejo.

**Con MpKit:** en el `MpActor` del cuerpo, agregá `Spill:wound` a **Sync › sync_extra**. Todo viaja al nacer, así que quien entra tarde arranca desde el valor actual.

```gdscript
# enemy.gd: el servidor decide el daño; los clientes solo dibujan lo que llega en wound
func take_damage(amount: float, from: Vector3) -> void:
	if not MpKit.is_authority():
		return
	hp -= amount
	$Spill.hit(amount, max_hp, from)
	if hp <= 0.0:
		$Spill.die()
```

**Con el `MultiplayerSynchronizer` de Godot:** en su Replication agregá la propiedad `Spill:wound`, con **Spawn** prendido y **Replicate: On Change**. Llamá a `hit()` y `die()` detrás de `multiplayer.is_server()`.

Dos salpicaduras más juntas que un intervalo de envío llegan como una sola (la última). La regla de `every_s` ya las separa más que eso, salvo un golpe fuerte justo después de otro.

## El tipo (`SpillType`)

Un recurso por sustancia. Solo describe cómo se ve; cuándo sangra lo decide el componente.

| Valor | Qué hace |
|---|---|
| `color` | El color de las gotas, las manchas y el charco. Su alfa es la opacidad con `alpha_scissor` en 0 |
| `roughness` | 0 = un espejo (fresco, húmedo), 1 = mate (seco). Multiplica el verde de un ORM |
| `metallic` | 0 = un líquido, 1 = un metal (mercurio, metal fundido). Multiplica el azul de un ORM |
| `specular` | Qué tan brillantes son los reflejos |
| `normal_scale` | Cuánto levantan la superficie los mapas de normales (0 = plano) |
| `alpha_scissor` | Arriba de 0, corta los píxeles con menos alfa: bordes duros, sin problemas de orden donde se pisan manchas. 0 = bordes suaves, mezclados por alfa |
| **Spray:** `drops` | Gotas de un golpe liviano |
| `drop_size_m`, `drop_speed_m_s` | Lado de una gota; velocidad de salida (cada una un 25 % más o menos) |
| `spread_deg`, `rise_deg` | Qué tan abierto sale el chorro, y cuánto sube sobre el horizonte |
| `drop_life_s` | Lo que vuela una gota (atraviesa el piso: lo que deja son las manchas) |
| `drop_scale_min`, `drop_scale_max` | Cada gota mide `drop_size_m` por un tamaño entre estos |
| **Heavy spray:** `heavy_drops`, `heavy_drop_size_m`, `heavy_drop_speed_m_s`, `heavy_spread_deg`, `heavy_rise_deg`, `heavy_drop_life_s`, `heavy_drop_scale_min`, `heavy_drop_scale_max` | Lo mismo para un golpe fuerte, ajustado aparte (32 gotas de 0,12 m a 3 m/s, abiertas 38°, a 45°, 0,85 s, 0,7 a 1,6). Sus gotas se ven como las livianas: las texturas y el material del grupo Spray |
| **Marks:** `marks_per_spray`, `marks_per_heavy` | Manchas que deja un golpe liviano y uno fuerte |
| `mark_radius_m`, `mark_min_m`, `mark_max_m` | Caen en cualquier lugar a esta distancia del cuerpo, entre estos tamaños |
| **Puddle:** `puddle_size_m`, `puddle_grow_s` | El lado del charco crecido (menos donde el piso no es plano), y lo que tarda en crecer |
| `drop_` / `mark_` / `puddle_albedo_texture` | Su forma (alfa) y su color, multiplicado por `color`. Vacío = la forma del kit |
| `drop_` / `mark_` / `puddle_normal_texture` | Su mapa de normales. Vacío = el de la forma del kit, o ninguno con un albedo tuyo |
| `drop_` / `mark_` / `puddle_orm_texture` | Oclusión (rojo), rugosidad (verde), metálico (azul). Vacío = `roughness` y `metallic` solos |
| `drop_` / `mark_` / `puddle_material` | Reemplaza el material del kit en esa superficie: el shader o material de tu juego. Un shader de gotas puede tomar el color de `COLOR` (el de la partícula) y no declarar ningún uniform |
| **Own material:** `texture_parameter`, `color_parameter` | En un ShaderMaterial tuyo, el uniform que recibe la textura de la superficie y el que recibe `color` (`albedo_texture`, `albedo_color`). Un shader de manchas o de charco los tiene que declarar; uno de gotas, no |

## El componente (`SpillSource3D`)

Va en el cuerpo, donde salen las gotas. Las gotas salen de su posición, y las manchas y el charco caen en el piso debajo de él.

| Valor | Qué hace |
|---|---|
| `type` | Qué derrama este cuerpo |
| `pool` | El pool que lo dibuja. Vacío = el `SpillPool3D` de su mundo |
| `floor_reach_m` | Hasta dónde debajo del componente puede estar el piso de sus manchas y su charco; más lejos (en el aire), nada. 0 = el `floor_reach_m` del pool. Un componente bajo (el caparazón de un bicho) quiere menos que un pecho |
| **Rules:** `heavy_from` | Un golpe que saca al menos esta parte de la vida máxima es fuerte (0,4) |
| `every_s` | Las salpicaduras livianas quedan al menos así de separadas; los golpes del medio se suman (0,25 s) |
| `min_lost` | El daño (parte de la vida máxima) que se tiene que sumar para una salpicadura liviana; un golpe que llega solo (ningún otro en `every_s`) sangra igual (0,05) |
| **Try it:** Spray, Heavy spray, Die (puddle), Clear the floor | Botones que lo prueban en la vista 3D del editor (y en juego). Las gotas vuelan hacia donde mira el nodo (-Z) |
| `wound` | La última salpicadura y muerte, empaquetadas: el valor que se sincroniza. No se guarda ni se muestra |

| Método | Qué hace |
|---|---|
| `hit(damage, max_hp, from = INF, heavy = false) -> bool` | Un golpe. Las gotas vuelan lejos de `from` (sin `from`, para cualquier lado). `heavy`: un golpe que siempre es fuerte (el remate de un combo). True si sangró |
| `spray(heavy = false, from = INF)` | Salpica ya, sin las reglas (una herida propia del juego) |
| `die()` | Un charco crece debajo. Un cuerpo que revive puede morir de nuevo |
| `current_pool() -> SpillPool3D` | El pool que lo dibuja (null en un servidor dedicado) |
| static `body_above(node)` | El cuerpo de física más cercano arriba de un nodo: los rayos del piso lo atraviesan |

## El pool (`SpillPool3D`)

Uno por mundo (un nivel). Arma todo una vez por tipo y lo reusa: un golpe no crea nada.

| Valor | Qué hace |
|---|---|
| `shown` | Apagado, lo nuevo no se dibuja y lo que ya está en el piso queda (la opción «sangre» de un jugador) |
| `types` | Los tipos que arma al arrancar. Un componente arma su tipo al entrar, esté o no en la lista |
| `floor_mask` | Lo que cuenta como piso para manchas y charcos. Dejá los cuerpos afuera |
| `floor_reach_m` | Busca el piso hasta esta distancia debajo del golpe; más lejos (en el aire), no hay mancha |
| **Sprays:** `sprays_per_type` | Salpicaduras guardadas por tipo y peso; más a la vez reusan la más vieja (6) |
| **Marks:** `marks_per_type` | Manchas guardadas por tipo; pasado eso se reusa la más vieja (64) |
| `mark_shade_min` | El tono de cada mancha va de este (más oscuro) a 1, para que no se repitan |
| `mark_lift_m`, `mark_lift_step_m` | Separación del piso, y un poco más por mancha para que dos que se pisan no titilen (64 alturas y vuelve a empezar) |
| **Puddles:** `puddles` | Charcos guardados, todos los tipos juntos (12) |
| `puddle_start_m`, `puddle_lift_m` | El lado con que empieza a crecer; su separación del piso (debajo de las manchas) |
| `puddle_probes`, `puddle_edge_share`, `puddle_flat_m`, `puddle_shrink`, `puddle_min_m` | Antes de crecer, tira rayos alrededor del borde; si uno encuentra el piso más lejos que `puddle_flat_m` (un cordón, un escalón), lo achica hasta que entre. Debajo de `puddle_min_m` no entra ahí |
| `puddle_seek_m` | Si no entra ni de `puddle_min_m` debajo del cuerpo (al lado de un cordón, sobre su bisel), busca piso plano hasta esta distancia, del lado del cuerpo: primero del lado contrario a la pendiente, nunca más alto que donde quedó el cuerpo (un líquido no sube un cordón) y sin nada en el medio a ras del piso (el borde de un cordón, un muro bajo). 0 = ahí no hay charco (0,75) |
| `puddle_drop_m` | Cuánto más abajo que el cuerpo puede quedar ese charco: baja un poco por un bisel, pero no cae por un cordón hasta la calle (0,08) |
| **Try it:** Clear the floor | Saca todas las manchas y charcos |

| Método | Qué hace |
|---|---|
| `spill(type, at, away = ZERO, heavy = false, exclude = [], reach_m = 0)` | Una salpicadura sin componente (un barril que pierde aceite). `away` es hacia dónde vuela, plano; `reach_m`, hasta dónde debajo puede estar el piso (0 = `floor_reach_m`) |
| `puddle(type, at, exclude = [], reach_m = 0)` | Un charco debajo de `at` |
| `clear()` | Saca todo del piso y del aire (una ronda nueva) |
| `prepare(type)` / `refresh(type)` | Arma un tipo ya / le pasa de nuevo los valores del tipo, sin tocar lo que está en el piso |
| `material_of(type, shape)` | El material con que dibuja las gotas, manchas o charcos de un tipo (`SpillShapes.Shape.DROP`, `MARK`, `PUDDLE`) |
| `mark_count(type)`, `marks_of(type)`, `puddles_of(type)`, `sprays_played(type)` | Lo que hay en el piso, para tests o un sondeo de depuración |
| `cost()`, `cost_text()` | Lo que guarda: gotas, manchas, charcos y draw calls como mucho |
| static `of(world)`, `draws_here()` | El pool de un mundo; false en un servidor dedicado |

## En el juego

| Querés | Escribí |
|---|---|
| Que un golpe sangre | `$Spill.hit(damage, max_hp, attacker.global_position)` |
| El tercer golpe del combo siempre fuerte | `$Spill.hit(damage, max_hp, from, true)` |
| Que muera con un charco | `$Spill.die()` |
| Una herida sin reglas (un guion, una trampa) | `$Spill.spray(true)` |
| La opción «sangre» del jugador | `pool.shown = prefs.blood` (lo que ya está en el piso queda) |
| Una ronda nueva | `pool.clear()` |
| Aceite que pierde un barril, sin cuerpo | `pool.spill(oil, barrel.global_position)` y `pool.puddle(oil, barrel.global_position)` |
| Que una especie sangre más fácil | `heavy_from = 0.25` en su componente |
| Menos manchas en una máquina lenta | `marks_per_type` del pool, o `marks_per_spray` del tipo |
| Que un bicho bajo no manche cuando salta | `floor_reach_m` de su componente: la altura del componente más lo que tolera en el aire (0,8 + 0,6 = 1,4) |
| Un golpe fuerte más violento | El grupo Heavy spray del tipo: más `heavy_drops`, más `heavy_drop_speed_m_s` |
| Un juego en red | [Red](#red): `hit()` y `die()` en el servidor, `wound` sincronizado |
| No dibujar en un servidor dedicado | Nada: un export con la feature `dedicated_server`, o un export corrido headless, no arma nada. Uno corrido con el editor headless sí dibuja: `pool.shown = false` ahí |
| Cambiar el material en vivo | `pool.material_of(type, SpillShapes.Shape.MARK)`, o cambiá el tipo y llamá `pool.refresh(type)` |

## Materiales: PBR o el tuyo

Cada tipo dibuja tres superficies (las gotas, las manchas y el charco), y cada una se ve de una de tres formas:

1. **El aspecto húmedo del kit:** solo `color`, `roughness`, `metallic`, `specular`. El kit dibuja su propia gota (una perla redonda), su mancha (con gotitas alrededor) y su charco, cada uno con un mapa de normales: borde redondeado, centro plano. La luz se engancha en el borde y el centro refleja como un espejo.
2. **Tu PBR:** poné `mark_albedo_texture`, `mark_normal_texture`, `mark_orm_texture` (y las mismas para `drop_` y `puddle_`), como en el `GrassMesh` de GrassKit. El albedo trae la forma en el alfa. Con un ORM el kit usa un `ORMMaterial3D`, y su verde y su azul se multiplican por `roughness` y `metallic` (dejalos en 1 para que mande la textura).
3. **El material de tu juego:** asigná `mark_material` (y `drop_material`, `puddle_material`), por ejemplo el ShaderMaterial PS1 del juego. Cada superficie recibe una copia:
   - si es un ShaderMaterial, el kit escribe la textura de la superficie en `texture_parameter` y `color` en `color_parameter`, cuando el shader los declara;
   - si es un BaseMaterial3D, el kit escribe `albedo_texture` (si no tiene uno) y `albedo_color`.

   La sombra de cada mancha llega como color de vértice (`COLOR` en un shader), igual que el color de cada gota. Un shader de gotas tiene que mirar a la cámara (ver `examples/types/flat_ink.gdshader`); puede tomar su color de `COLOR` y no declarar ningún uniform.

Todo eso anda en Compatibility y WebGL 2: los materiales del kit son StandardMaterial3D u ORMMaterial3D. En una pendiente, las normales del charco y de las manchas siguen al piso.

## En el editor

- Seleccioná un `SpillSource3D`. Arriba del inspector, el costo de un golpe y de una muerte; en «Try it», los botones **Spray**, **Heavy spray**, **Die (puddle)** y **Clear the floor**. Las gotas vuelan hacia donde mira el nodo (-Z), y las manchas y el charco caen sobre el piso de la escena (la física del editor lo encuentra). Cada botón toma primero los valores actuales del tipo, así que cambiar el tipo y apretar de nuevo muestra el cambio.
- En la escena de un cuerpo sola (sin pool), el botón arma un pool ahí, que no se guarda.
- Seleccioná el `SpillPool3D`: arriba, lo que guarda (gotas, manchas, charcos y los draw calls como mucho). Se actualiza al cambiar los valores.
- El árbol de escena avisa por un componente sin tipo, por una `floor_mask` vacía, por un segundo pool en el mismo mundo, por un charco más chico que `puddle_min_m`, por `mark_min_m` arriba de `mark_max_m` y por un shader propio de manchas o de charco sin los uniforms de `texture_parameter` o `color_parameter` (uno de gotas no los necesita).

Lo que dibujan los botones nunca se guarda en la escena.

## Rendimiento

Nada se crea por golpe: cada tipo tiene sus salpicaduras (un anillo de CPUParticles3D por peso), sus manchas (un MultiMesh) y comparte los charcos (MeshInstance3D). Las manchas son un draw call por tipo; cada salpicadura en el aire y cada charco, uno.

**Medido** en una Mac M4, a 1280 × 720 y con el aspecto del kit:

| Qué | Costo |
|---|---|
| Una salpicadura (`spill()`: sus 1 o 3 manchas y sus rayos) | 9 µs |
| Un charco (`puddle()`: con sus 8 rayos de borde) | 12 µs; 0,16 ms al lado de un cordón, donde busca piso plano (0,19 ms si no encuentra) |
| 2 tipos: 128 manchas, 12 charcos y 552 gotas en el aire | Dentro del ruido del cuadro (1,2 a 1,9 ms en total), en Compatibility y en Forward+ |
| Compilar los shaders de un tipo nuevo | Unos 230 ms, mientras carga el nivel |

Godot compila un shader la primera vez que lo dibuja. Para que eso no pase en el primer golpe, el pool dibuja una gota, una mancha y un charco de cada tipo apenas lo arma, durante dos cuadros, más chicos que un píxel delante de la cámara. Listá los tipos del nivel en `types` y todo eso pasa en la carga. Sin precalentar, el primer golpe de cada tipo trababa unos 180 ms.

El costo por máquina lo muestra el inspector del pool (`cost_text()`). Con muchos tipos, bajá primero `sprays_per_type` y `marks_per_type`.

## Tips y recomendaciones

- **El componente en el pecho.** Las gotas salen de ahí, y las manchas buscan el piso debajo, hasta `floor_reach_m`. Un cuerpo en el aire salpica pero no mancha. Cuerpos de alturas distintas: el `floor_reach_m` de cada componente.
- **Una capa para el piso.** `floor_mask` es lo que cuenta como piso. Los cuerpos en otra capa, o el propio cuerpo, que se encuentra solo, nunca reciben manchas.
- **Bordes duros para muchas manchas.** Con `alpha_scissor` arriba de 0, dos manchas que se pisan nunca se ordenan mal. Los bordes suaves (`alpha_scissor` en 0, la baba del ejemplo) se ven mejor de a pocas.
- **Un tipo por especie, no por cuerpo.** Todos los cuerpos de un tipo comparten sus salpicaduras, sus manchas y su material.
- **Un cuerpo puesto en el nivel** (no creado por un spawner) en un juego en red: su primer valor de red puede llegar después de que esté listo, y quien entra tarde vería esa salpicadura vieja una vez. Los cuerpos que hace aparecer un spawner (o MpKit) traen su valor al nacer.
- **El shader PS1 de tu juego** va en `mark_material` / `puddle_material` / `drop_material`. Con `texture_parameter` y `color_parameter`, un mismo material sirve para todos los tipos.

## De dónde salen las ideas

La primera versión fue la sangre de un juego en red, medida con cuatro jugadores. Este kit la hizo genérica:
- **Salpicaduras que no se crean por golpe:** anillos de partículas reusados, como hacen los juegos de acción con muchos enemigos.
- **Manchas que quedan toda la partida y se reusan de la más vieja:** como las decals de sangre de los shooters, pero en un MultiMesh, que se dibuja igual en todos los renderers y en la web.
- **Un charco que crece al morir y se achica para no subirse a un cordón.**
- **Una sola propiedad para la red, con contadores:** quien entra tarde compara contadores, no eventos, así que nunca ve lo viejo.

El aspecto húmedo (un borde redondeado con centro plano, baja rugosidad) es el de un menisco: un líquido se apoya en el piso con el borde curvo.

## Tests

```bash
godot --headless --path spillkit_lab --script res://addons/spill_kit/tests/spill_test_runner.gd
```

El resultado es `SPILLKIT TESTS PASS (n)`. Los tests cubren:

- **las reglas:** fuerte al 40 % o por el golpe, livianas separadas por `every_s`, golpecitos que se suman, un roce solo que igual sangra;
- **el valor que viaja:** sus contadores, las muertes que vuelven a empezar, de ningún lado;
- **el componente con física:**
  - un golpe salpica y mancha el piso debajo; las gotas vuelan lejos de donde vino el golpe;
  - una muerte hace crecer un charco, y un cuerpo que revive muere de nuevo;
  - una máquina que lee el valor dibuja lo mismo, debajo de su propio cuerpo; quien entra tarde no dibuja nada viejo;
  - su propio cuerpo nunca recibe manchas; ninguna detrás de un muro ni en el aire; el alcance del piso de cada componente;
  - sin pool se arma uno; una salpicadura propia del juego; el aviso sin tipo;
- **el pool:**
  - el anillo de manchas y sus alturas; el anillo de charcos; la salpicadura fuerte con sus propios valores;
  - un charco sobre una pendiente y al lado de un cordón; al lado de un cordón o sobre su bisel, el charco se corre al piso plano; nunca sube a un bloque ni se mete en un hueco angosto;
  - sobre el bisel de una vereda, el charco queda en la vereda y nunca cae a la calle; no pasa del otro lado de un muro bajo;
  - la opción del jugador y una ronda nueva; arma una vez por tipo, todo interno; el costo;
  - un pool por mundo y sus avisos; el pool que se armó solo deja su lugar al del nivel; salpicar sin componente;
  - cada tipo dibujado una vez al cargar, chico y frente a la cámara, y después borrado;
- **los materiales:**
  - un tipo con solo su color se ve húmedo (las normales del kit);
  - el mapa de normales y el ORM de un tipo PBR llegan al material y a lo que dibuja el pool;
  - un ShaderMaterial y un StandardMaterial3D del juego, copiados, con su textura y su color;
  - un shader de gotas que toma el color de la partícula, sin uniforms ni avisos;
  - las formas del kit suben como un líquido;
- **una escena guardada y cargada de nuevo:** sus valores y nada de lo dibujado ni de `wound`;
- **cada script carga; lo que corre en un servidor no usa cámara, pantalla ni material; no se nombra ningún otro kit;**
- **los dos ejemplos, de punta a punta**, y un clic que golpea al muñeco de abajo.

Un test que se corta por un error de script, o que nunca llega a chequear nada, falla.

Los botones tienen su propio chequeo en un editor real. Revisa:
- en `minimal_3d`, apretar Spray, Heavy spray, Die (puddle) y Clear the floor en el inspector dibuja y limpia en la vista 3D, sobre el piso que encuentra la física del editor;
- las líneas de costo y el aviso sin tipo;
- la escena guardada, sin nada de lo dibujado;
- la escena de un cuerpo sola, donde Spray arma un pool que no se guarda.

```bash
SPILLKIT_EDITOR_CHECK=1 godot --headless --editor --path spillkit_lab
```

Imprime `EDITOR CHECK PASS`.

## Fuera del kit

Esto es del juego:

- la vida y el daño (el kit recibe el daño de un golpe y la vida máxima, nunca la vida);
- quién decide el daño en un juego en red, y cómo viaja `wound`;
- de dónde vino un golpe (el punto del impacto o el atacante);
- la opción «sangre» del jugador (`shown`) y dónde se guarda;
- su shader o material, si no usa el del kit.
