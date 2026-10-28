# PropKit

Props para mundos 2D y 3D, en tres piezas independientes:

1. **Scatter.** Planta props sobre cualquier suelo como nodos guardados y editables: grupos según un ruido, zonas prohibidas alrededor de los nodos del juego, una máscara pintada, variantes con peso.
2. **Dibujo en lotes (3D).** Dibuja miles de props en pocas llamadas de dibujo.
3. **Navmesh por zonas.** Hornea el navmesh en zonas cuadradas, con los props como obstrucciones proyectadas baratas, así un cambio rehornea solo las zonas que toca, en hilos de trabajo.

No tiene red, ni reglas de juego, ni autoload, y PropKit no depende de ningún otro kit. Cada pieza funciona sin las otras.

```bash
./install.sh --addon /path/to/godot-project prop_kit
```

Habilitá el plugin **PropKit**. Agrega Proyecto > Herramientas > *PropKit: Scatter the open scene*, que corre todos los scatters de la escena abierta. Los nodos del kit funcionan también sin el plugin.

Ejemplos:

- `examples/forest_3d/forest_3d.tscn`: un bosque, los lotes y un navmesh de 16 zonas. Dos clics marcan un camino, C tala y R da otro bosque.
- `examples/grove_2d/grove_2d.tscn`: arbustos alrededor de paredes y un navmesh 2D, con las mismas teclas.

## El plano del suelo

Todos los puntos del kit están sobre el plano del suelo: **(x, z) en 3D** y **(x, y) en 2D**, en coordenadas globales, como `Vector2`. Las distancias van en las unidades del mundo: metros en 3D, píxeles en 2D.

## 1. Scatter

```
World
├── Ground              # cualquier cosa con colisión (3D, para PropRayGround)
├── Forest              # PropScatter3D: rules, ground, variants, keep_out, mask
│   ├── Prop0000        # los props: hijos guardados, se mueven o borran como cualquier nodo
│   └── …
└── Camps/Start         # en un grupo que el scatter respeta
```

1. Agregá un **PropScatter3D** (o **PropScatter2D**).
2. Poné **rules**: un `PropScatterRules`, que podés compartir entre mapas.
3. Poné **ground** (abajo).
4. Agregá **variants**: un `PropVariant` por escena, cada uno con su peso.
5. Apretá **Scatter** en el inspector. **Clear** los saca.

Las mismas reglas y semilla dan siempre los mismos props. Volver a plantar reemplaza todos los hijos del nodo.

Los props son hijos comunes, del dueño de la escena: se guardan y se editan con el gizmo. Desde código: `scatter.scatter(scene_owner)`. Desde un paso de build o CI:

```bash
godot --headless --path . --script res://addons/prop_kit/tools/scatter_scene.gd -- --scene=res://maps/forest.tscn
```

Las `rules`:

| Regla | Qué hace |
|---|---|
| `random_seed` | El ruido y cada tirada |
| `cluster_size`, `cover`, `edge`, `density`, `lone_chance` | Los grupos: bosques y claros. `cover` 1 = un scatter parejo |
| `spacing` | Espacio entre dos props de escala 1, centro a centro. Crece con la escala |
| `scale_range`, `scale_jitter` | Chicos en el borde de un grupo, grandes en el corazón, más una parte al azar |
| `keep_out_shrink` | Props más chicos cerca de una zona prohibida |
| `random_rotation` | Un giro al azar para cada prop |
| `max_count` | El tope. Corta primero en los bordes de los grupos |
| `sink`, `align_to_normal` | En 3D: hundir en el suelo e inclinar con la pendiente |

**Ground** (`PropGround`): dónde puede ir un prop. Da el área, la altura y la normal (3D), y un peso de 0 (nunca) a 1 (del todo).

- `PropFlatGround`: un rect o el contorno de un polígono, a una altura. El suelo de siempre en 2D.
- `PropRayGround` (3D): un rayo hacia abajo contra `collision_mask`, con `max_slope_deg`. Funciona con cualquier collider, en el editor y en el juego. Dejá la capa de los props fuera de su máscara.
- **El suelo del juego**: un script que `extends PropGround` (o un suelo del kit) y responde desde el terreno del juego. Necesita `@tool`, porque el scatter lo llama en el editor. `examples/grove_2d/grove_ground.gd` saca así los arbustos de las paredes.

**Zonas prohibidas** (`PropKeepOut`): `{group, radius, soft}`. No hay ningún prop a menos de `radius` de un nodo de ese grupo, y hay menos y más chicos hasta `radius * (1 + soft)`. El kit nunca conoce las clases del juego: el juego pone en un grupo sus puntos de inicio, edificios o marcadores.

**Máscara** (`PropMask`): una textura sobre un área. Un canal ralea props (su valor multiplica la chance) y otro los prohíbe (por encima de `forbid_above`).

## 2. Dibujo en lotes (3D)

Agregá un **PropBatch3D** y poné en **props** los padres de los props (los PropScatter3D).

- **Los lotes.** Cada `MeshInstance3D` de cada prop va a un `MultiMeshInstance3D`, uno por tipo de parte (malla, material, sombra, capas, rango de visibilidad) y por cuadrado de `chunk_size`, así la cámara descarta por cuadrado. Los nodos de los props siguen ahí, por la colisión y el navmesh; solo se ocultan sus partes. Los 1600 árboles del ejemplo son unas pocas decenas de draws.
- **Liberar un prop** redibuja solo su cuadrado, en el frame siguiente.
- **`refresh(prop)`** después de ocultar un prop o moverlo dentro de su cuadrado.
- **`rebuild_all()`** después de agregar props o de cambiar lo que responde `mesh_of`.
- **`mesh_of`** (`func(prop, part) -> Mesh`) dibuja otro aspecto para el mismo prop, como el árbol de otro bioma, sin tocar la escena.
- **Dónde no dibuja:** en el editor (cada prop se muestra solo, para moverlo), en un servidor dedicado o headless, y en una parte con materiales por superficie, que queda como está.

En 2D no hay lotes: Godot ya agrupa los sprites.

## 3. Navmesh por zonas

```
Game
├── World               # source_root: lo que se parsea (terreno, edificios) y donde están los props
│   ├── Ground
│   └── Forest          # props en el grupo prop_obstruction, en una capa que el navmesh no parsea
└── Nav                 # PropNavZones3D (o PropNavZones2D): una NavigationRegion por zona, interna
```

1. Poné los props en el grupo **`prop_obstruction`**, en la escena del propio prop. Sus formas de colisión directas y habilitadas cortan el navmesh:
   - en 3D: Cylinder, Capsule, Sphere, Box, ConvexPolygon y CollisionPolygon3D;
   - en 2D: Circle, Rectangle, Capsule, ConvexPolygon y CollisionPolygon2D.
2. Poné los props en una **capa de colisión que el navmesh no parsea**: sacala de la máscara de colisión de la plantilla y parseá colliders estáticos. Si no, el horneado los paga dos veces, y el kit avisa una vez.
3. Agregá un **PropNavZones3D** con una plantilla `navigation_mesh`: agente, celdas, geometría parseada y máscara. Poné `source_root` y `zone_size` (un múltiplo del tamaño de celda).
4. Apretá **Bake** en el inspector. Hornea todas las zonas y las guarda junto a la escena en un `.res`, que es el `saved` del nodo.

En el juego:

- **Al arrancar** carga el horneado guardado de una. Si los props no son los mismos (por ejemplo, una partida sin su bosque), emite `stale` y rehornea todas las zonas en hilos de trabajo. Con `rebake_when_stale` apagado, solo emite `stale`.
- **`rebake(areas, reparse)`** después de que algo que bloquea cambió ahí. Las áreas son Rect2 en el plano del suelo. `PropObstructions.area_of(prop, true)` da el área de un prop, así que leela antes de liberarlo. `reparse = false` cuando solo cambiaron props: se reusa la geometría parseada y solo se leen las obstrucciones cerca de las zonas tocadas (un índice por zona, así no recorre el grupo entero).
- **Los pedidos que llegan mientras hornea** esperan y se juntan en el siguiente.
- **`apply_mode` MANUAL**: el resultado espera (`bake_ready`, `has_result()`) a `apply()`. Un juego en lockstep lo aplica en el tick que elige; `is_done()` dice sin bloquear si ya puede. Las piezas entran siempre en orden de zona, así el resultado depende solo de las entradas y nunca de qué zona terminó primero.
- **`applied`** avisa que las regiones tienen las piezas nuevas. **`synced`** (`is_synced()`) avisa que el mapa de navegación ya las usa: los caminos y consultas del servidor las ven unos frames de física después de `applied`.
- **`stats`** (PropNavStats) para los logs: `parse_ms`, `obstruct_ms`, `bake_ms`, `index_ms`, `zones_baked` / `zones_total`, `obstructions`, `polygons`, `components`.

**Cómo se tocan las zonas.** Cada zona se hornea con su propio filtro (`filter_baking_aabb` / `baking_rect`) y un borde (`zone_border`, 0 = según el radio del agente), con las líneas de zona ancladas en (0, 0). Las piezas se tocan justo en la línea de zona y el mapa de navegación las une sin edge connections (`use_edge_connections` queda apagado, y cada cambio sale barato). Un rehorneado parcial da las mismas piezas que hornear todo.

**Menos polígonos** (`merge_gap`):

- Los props más cerca que el hueco se vuelven una sola obstrucción. Es un cierre: cada contorno crece gap / 2, los que se tocan se unen y después se achican de nuevo. Así un paso más ancho que el hueco queda abierto; ponelo por debajo del diámetro del agente.
- Un claro cerrado por completo con huecos más angostos se rellena, porque ningún agente podría entrar ni salir. Dejá una abertura más ancha que el hueco donde tenga que haberla.
- `obstruction_sides` (los lados del contorno de una forma redonda) es la otra perilla.
- `carve` corta justo el contorno, sin el radio del agente alrededor.

**El índice** (`index`: PropNavIndex). Se arma en un hilo de trabajo con cada horneado, así está listo en el momento en que se cambian sus piezas. Responde lo que el servidor no:

| Consulta | Respuesta |
|---|---|
| `component_at(point)`, `same_component(a, b)` | Si un agente puede llegar de acá hasta allá |
| `polygon_at(point)` | El polígono bajo un punto |
| `closest_point(point)` | El punto caminable más cercano |
| `stitched(template)` | Todo el navmesh como una sola NavigationMesh |

En 2D, las mismas consultas terminan en `_2d`. Con `build_index` apagado no hay índice.

**2D** (`PropNavZones2D`, píxeles): el área caminable son los contornos de la plantilla, o la zona entera si no hay ninguno; los colliders parseados y los props la bloquean.

## Multijugador

PropKit no tiene red. Un scatter es determinista, así que todos los peers que cargan la misma escena tienen los mismos props.

Cuando algo que bloquea cambia durante la partida (un prop talado, un edificio levantado), cada peer recibe el cambio como un dato del juego, por su propio transporte (MpKit o cualquier otro). Después cada uno llama a `rebake(areas, false)`. Con `apply_mode` MANUAL, cada uno aplica el resultado en el mismo tick.

## Problemas de Godot que esquiva

- **Godot 4.7: una región puede perder una actualización.** Con las iteraciones asíncronas de regiones, una navmesh que se le pone a una región mientras su iteración anterior todavía corre se pierde: el mapa se queda con la vieja para siempre. El nodo de zonas guarda la pieza nueva hasta que la región tomó la anterior, así no se pierde nada. Se reproduce solo: una región y dos navmeshes puestas con un frame de diferencia. `test_a_saved_bake_loads_and_goes_stale` lo cubre.
- **2D: un aviso inofensivo.** El horneador 2D de Godot puede dejar astillas de menos de un píxel alrededor de los contornos redondos, y el mapa avisa "More than 2 edges tried to occupy the same map rasterization space". Pasa dentro de una misma pieza, no en las líneas de zona. Los caminos no se ven afectados.

## Medido

En una Mac, headless, con el bosque del ejemplo a 1365 props, 16 zonas y 11 678 polígonos:

| Horneado | Obstrucciones (hilo principal) | Horneado (hilos de trabajo) | Índice (hilo de trabajo) |
|---|---|---|---|
| Todas las zonas | 24 ms | 32 ms | 62 ms |
| Talar un claro (1 zona de 16) | 3,3 ms | 10 ms | 61 ms |

En una ventana, el primer horneado de una escena tarda más mientras Godot compila sus shaders. Después, los 343 props del ejemplo se hornean en unos 24 ms.

Las zonas se hornean en tareas propias del kit, no en el horneado asíncrono del servidor. Así, liberar el nodo o cerrar el juego a mitad de un horneado espera a los hilos de trabajo en vez de colgarse.

## Tests

```bash
godot --headless --path propkit_lab --script res://addons/prop_kit/tests/prop_test_runner.gd
```

El resultado es `PROPKIT TESTS PASS (n)`. Los tests cubren:

- **el planner**: determinismo, espacio, zonas prohibidas, máscaras, contornos, variantes y el tope;
- **el scatter**: hijos guardados, suelo por rayos, pendientes, normales, 2D, guardar una escena;
- **cada forma de obstrucción**, el merge y el fingerprint;
- **la grilla de zonas**;
- **las zonas 3D y 2D**: zonas que se tocan, props que bloquean, parcial = completo, props agregados, aplicar en MANUAL, pedidos que se juntan, horneados guardados y vencidos, merge, componentes;
- **los lotes**;
- **los dos ejemplos, de punta a punta.**

## Lo que no está en el kit

Esto es del juego:

- qué es un prop (vida, botín, sincronización en red);
- cuándo rehornear;
- el transporte;
- los datos del suelo.

El pasto es un kit aparte, GrassKit, planeado para después de PropKit 0.1.
