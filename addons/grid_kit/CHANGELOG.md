# Cambios de GridKit

## 0.8.0

Niebla de guerra por jugador.

- **`CellFog`:** lo que sabe cada jugador del tablero, como datos puros. Para cada observador (un asiento, un equipo: un entero desde 0) cada casilla está `HIDDEN`, `EXPLORED` o `VISIBLE`. `see(observer, cells)` deja visibles exactamente esas casillas y pasa a exploradas las que se dejaron de ver; `reveal` suma visibles, `explore` hace conocer el terreno sin verlo, `clear_visible`, `clear()` y `clear_observer(observer)` vuelven atrás. Las señales `revealed`, `faded`, `explored` y `cleared` dicen solo lo que cambió, ordenado. `to_dict` / `CellFog.from_dict` para el guardado y el replay, también después de pasar por JSON; `observer_to_dict` / `set_observer_from_dict` para mandarle a cada jugador solo lo suyo. Anda en hexágonos y en cuadrados.
- **`GridFog`** (hijo de un `GridView3D`): envuelve un `CellFog` (el propio o el de tus reglas con `use_fog`) y dibuja la niebla de `shown_observer`: las losetas ocultas no se dibujan y quedan bajo una tapa, las exploradas se oscurecen, las visibles se ven como son. Redibuja solo lo que cambió. `fade_time` hace el cambio gradual y `tile_shown(cell, tile)` avisa para animar. `see_around(observer, cells, radius, blocks)` para lo que ven las unidades, con lo que tapa la vista. En el editor no tapa el mapa; **Preview** la muestra unos segundos.
- **`CellGrid.cells_near(centers, radius)`**, **`line(a, b)`** y **`cells_visible_from(center, radius, blocks)`** (y sus atajos en `GridBoard`): las casillas a `radius` pasos de cualquiera de las del centro; la línea recta entre dos casillas; lo que se ve desde una casilla cuando algunas tapan la vista.
- **Ejemplo `fog_3d`:** dos jugadores con una exploradora cada uno y la niebla de cada uno.
- **Chequeo del editor del lab:** la niebla en el editor real (**Preview** y lo que se guarda). Los chequeos de editor de los labs guardan sin miniatura y deshacen con el atajo del editor, así que ya no muestran `Parameter "t" is null` ni `Inconsistent redo history`.

Nada que actualizar en tu proyecto.

## 0.7.0

- **`GridView3D.cell_right_clicked(cell)`:** el clic derecho sobre una casilla, con la misma regla que `cell_clicked` (un arrastre no es un clic), `input_enabled` y la casilla alta de un tablero con alturas. Sirve para elegir con el izquierdo y ordenar con el derecho, como en Civilization. El botón del medio sigue siendo de la cámara, y el toque sigue siendo el izquierdo.

Nada que actualizar en tu proyecto: `cell_clicked` sigue igual.

## 0.6.1

- **Iconos propios en el editor:** cada nodo y recurso del kit tiene el suyo, del color del kit: se ven en el árbol de escena, en «Agregar nodo» y en el FileSystem. El emblema del kit está en su barra de la vista 3D.

Nada que actualizar en tu proyecto.

## 0.6.0

Alturas por casilla: mesetas, pozos, un marco de piedras más alto.

- **`GridBoard.height_key` y `height_scale`:** `height_key` dice qué valor de la casilla es su altura (por ejemplo `height`; un número, int o float) y `height_scale` cuántas unidades de mundo vale una altura de 1. `cell_to_position(cell)` devuelve la altura en Y, así que las losetas, las marcas de `GridCursor` y lo que el juego ubica con `cell_to_position` suben juntos. `cell_height(cell)` da la altura en unidades de mundo. Un valor que no es un número cuenta como 0, con un aviso.
- **Los clics eligen lo que se ve.** Con alturas, `GridView3D.cell_at_ray` y `cell_at_screen` (y con ellos `cell_clicked`, `cell_hovered` y el pincel del editor) tratan cada casilla como una columna que llega hasta su altura y eligen la primera que el rayo toca, por arriba o por el costado. Una casilla fuera del tablero cuenta con altura 0.
- **`position_to_cell` y `position_to_any_cell`** solo miran X y Z: la altura no cambia la respuesta.
- **Lo que cambia se mueve, no se recrea.** Cuando cambia la altura de una casilla (`set_value`, `paint`, deshacer), su loseta y su marca se mueven. Cambiar `height_key` o `height_scale` emite `rebuilt` y reubica todo, como `cell_size`.
- **Pincel de alturas** en la barra GridKit: **Raise** y **Lower** suben o bajan un paso cada casilla del trazo (Shift hace lo contrario) y **Set height** escribe un número. Un trazo es un paso de deshacer y queda en el `GridLayout`; si el tablero no tenía `height_key`, el primer trazo le pone `height`. La vista 3D del editor muestra el mapa con sus alturas.
- **Arreglo:** `set_value` (en `CellGrid` y en `GridLayout`) fallaba al reemplazar un valor por otro de otro tipo (un texto por un número). Ahora lo reemplaza.

Nada que actualizar en tu proyecto: sin `height_key`, el tablero es plano, y los clics y su costo son los de antes.

## 0.5.0

Cuatro consultas que antes cada juego escribía por su cuenta, en `CellGrid` (hexágonos y cuadrados) y como atajos en `GridBoard`:

- **Direcciones:** `direction_to(a, b)` dice hacia qué lado de `a` está `b` (0 a 5 en hexágonos, en el orden de `CUBE_DIRECTIONS`; 0 a 3, u 0 a 7 con diagonales), o -1 si no es vecina. `neighbor(cell, direction)` es el camino inverso, y `direction_count()` dice cuántas hay.
- **Vecinas fuera del tablero:** `neighbors(cell, false)` también devuelve las que quedan afuera, siempre en el orden de las direcciones. `outline(rings := 1)` da las casillas que rodean el tablero: un marco, una niebla, una costa.
- **`cells_with(key, value)`:** las casillas con ese valor (las de inicio de un jugador). También en `GridLayout`.
- **`center_cell()`:** la casilla más cercana al centro de la forma.

Nada que actualizar en tu proyecto: `neighbors(cell)` sigue igual.

## 0.4.0

- **`GridView3D.tile_created(cell, tile)`:** sale por cada loseta que arma, ya en el centro de su casilla y antes de que entre al árbol, así que lo que le pongas ahí (su casilla, sus datos) ya está en su `_ready`. Antes, el juego tenía que deducir la casilla por la posición.
- **`GridView3D.drawn`:** todas las losetas están en su lugar (después de un `rebuilt`, de cambiar `tiles`, `default_tile` o `value_key`, o de `redraw()`). Antes no había cómo saber que el tablero terminó de dibujarse.
- **README:** cómo ver el tablero en el editor cuando la grilla llega al correr (un `layout` o la forma del inspector como vista previa; `use_grid` la reemplaza).

Nada que actualizar en tu proyecto.

## 0.3.0

- **Cuadrados además de hexágonos, con la misma API.** Nueva base `CellGrid` (casillas, valores, `find_path`, `flood`, `to_dict`, señales) con `HexGrid` y `SquareGrid` encima. `SquareGrid` tiene `diagonals`: apagado, 4 vecinas y distancia Manhattan; encendido, 8 vecinas y distancia Chebyshev. Fábricas: `HexGrid.rect/hexagon`, `SquareGrid.rect/disc`.
- **`CellGrid.add_cells` / `remove_cells`** emiten `cells_changed` una sola vez; `erase_value(cell, key)` emite `value_changed` con `null`.
- **`GridLayout`** (`Resource`): el mapa (forma, diagonales y valores por casilla) se guarda en un `.tres` y se asigna en `GridBoard.layout`. `make_grid()` entrega una copia, `read_grid` / `from_grid` copian una grilla al recurso.
- **`GridBoard`**: `shape` (Hexagons o Squares), `diagonals`, `radius` vale para las dos formas, `layout`, `save_shape_as_layout()` (y un botón **Save shape as layout** en la barra GridKit, con deshacer), `grid` es un `CellGrid`, `paint(key, values)`, `set_cells(add, remove, values)` y `position_to_any_cell`. Con layout, la forma del inspector queda de solo lectura; en el editor, un layout que cambia rearma la grilla una vez por cuadro.
- **Pincel en la vista 3D del editor:** al seleccionar un `GridBoard` o un `GridView3D`, la barra **GridKit** trae un botón por loseta, **Erase**, **Add cells** y **Remove cells**. Un trazo es un paso de deshacer del editor y lo pintado queda en el `GridLayout` (se crea solo si falta).
- El pincel guarda un layout que es un `.tres` aparte al guardar la escena, con Guardar todo o al correr el juego, y avisa al cerrar si quedó algo sin guardar; solo escribe el que cambió de verdad.
- **`GridView3D`**: `cell_at_ray(origin, direction, on_board_only)`; borrar un valor redibuja la casilla con `default_tile`; cuando el tablero gana o pierde casillas solo se dibujan o se liberan esas losetas.
- **`GridCursor`: arreglo de rendimiento.** Ya no recrea todos sus marcadores en cada `rebuilt`: lo atiende una vez por cuadro, libera solo las marcas de casillas que ya no están y mueve las demás. El marcador por defecto comparte una malla y un material, y es un hexágono o un cuadrado según la forma.
- **Rompe (ver "Migrar desde 0.2" en el README):** `distance`, `cell_to_local` y `local_to_cell` ya no son estáticos (son de la grilla); `GridBoard.grid` es un `CellGrid`; `to_dict` escribe `"shape": "hex"` o `"square"` (`from_dict` lee también el formato viejo, `"shape": 0`); `HexGrid.Shape` desaparece (`shape_name()`).
- Ejemplos: `minimal_3d` lee su mapa de `map.tres`; nuevo `squares_3d`.
- Skill `godot-grid-kit` y command `/add-grid`.

## 0.2.0

- `HexGrid.add_cell` y `remove_cell` emiten la señal nueva `cells_changed`, y `GridBoard` la pasa como `rebuilt`: `GridView3D` dibuja o borra la loseta de una casilla agregada o quitada en juego.
- `GridCursor` escucha `rebuilt`: borra las marcas de casillas que ya no están y mueve las demás (también con un `cell_size` nuevo).
- README: qué consultas tiene `GridBoard` y cuáles van por `board.grid`.
- `gridkit_lab/project.godot`: el mismo comentario en español y en inglés.

## 0.1.0

Primera versión:

- `HexGrid`: el tablero hexagonal como datos puros (pointy-top, offset odd-r). Valores por casilla, vecinos, distancia, rango, caminos con costo, flood y `to_dict` / `from_dict`. Resultados en orden fijo.
- `GridBoard`: arma la grilla desde el inspector (rectángulo o hexágono) o muestra la de tus reglas (`use_grid`).
- `GridView3D`: una escena por casilla según un valor. Clic o toque sin arrastre (`cell_clicked`) y hover (`cell_hovered`), sin colliders.
- `GridCursor`: marca casillas con un hexágono o con tu escena.
- Ejemplo `examples/minimal_3d`, tests propios y `gridkit_lab/`.
