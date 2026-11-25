# GridKit

Tableros de hexágonos **o de cuadrados** para juegos de estrategia, tácticos, de mesa o puzzles, con la misma API para las dos formas. Hay tres niveles:

- **`CellGrid`** (`HexGrid` y `SquareGrid`): el tablero como datos puros (`RefCounted`, sin nodos ni escena). Guarda valores por casilla y responde vecinos, distancia, rango, caminos y flood. Las reglas de tu juego lo usan directo y se testea headless.
- **`GridLayout`**: el mapa (la forma y los valores de cada casilla) como un `Resource` que se guarda en un `.tres`.
- **Nodos para verlo y pintarlo**:
  - `GridBoard` arma o muestra una grilla, desde el inspector o desde un `GridLayout`.
  - `GridView3D` la dibuja con una escena por casilla y reporta clics y hover.
  - `GridCursor` marca casillas.
  - Un **pincel en la vista 3D del editor** pinta los valores de las casillas, sube y baja sus alturas y agrega o quita casillas.

GridKit **no tiene** reglas de juego, unidades, niebla ni red, y no tiene autoload.

## Instalar

```bash
./install.sh --addon /path/to/godot-project grid_kit
```

Habilitá el plugin **GridKit** (tipos `GridBoard`, `GridView3D` y `GridCursor` en Create Node, y la barra del pincel en la vista 3D).

## En 3 pasos

**Por el editor**

1. Agregá un `GridBoard` y elegí la forma en el inspector: `shape` (Hexagons o Squares), `columns` × `rows`, o `radius`. Elegí también `cell_size`.
2. Agregale un hijo `GridView3D`. En `tiles` poné una escena por valor (por ejemplo `plain`, `forest`, `water`) y en `value_key` la clave que elige la escena (por defecto `terrain`).
3. Seleccioná el `GridBoard` y pintá con la barra **GridKit** de la vista 3D. Guardá la escena: el mapa queda adentro. Si lo querés en su propio archivo, guardalo como `.tres` desde el inspector.

**Por código**

Al hacer clic en una casilla se marcan sus vecinas, y la casilla (2, 3) pasa a ser bosque. Los tres `@export` se asignan en el inspector:

```gdscript
@export var board: GridBoard
@export var view: GridView3D
@export var moves: GridCursor


func _ready() -> void:
	board.set_value(Vector2i(2, 3), &"terrain", &"forest")
	view.cell_clicked.connect(_on_cell_clicked)


func _on_cell_clicked(cell: Vector2i) -> void:
	moves.highlight(board.neighbors(cell))
```

## Pintar el mapa en el editor

Seleccioná un `GridBoard` (o su `GridView3D`) y arriba de la vista 3D aparece la barra **GridKit**:

| Botón | Qué hace |
| --- | --- |
| Un botón por cada clave de `tiles` (por ejemplo `plain`, `water`) | Pinta esa loseta: escribe esa clave en el valor `value_key` de la casilla |
| **Erase** | Borra el valor: la casilla vuelve a `default_tile` |
| **Add cells** | Agrega casillas, también pegadas al borde del tablero |
| **Remove cells** | Quita casillas y todos sus valores |
| **Raise** y **Lower**, con su paso (`±`) | Suben o bajan un paso cada casilla del trazo. Con Shift hacen lo contrario |
| **Set height**, con su número | Escribe esa altura en cada casilla del trazo (para aplanar una meseta) |
| **Save shape as layout** | (No es una herramienta: es un botón.) Crea un `GridLayout` desde la forma actual y lo asigna a `layout`, sin pintar. Solo está habilitado si el tablero no tiene `layout`. Es un paso de deshacer |

- **Una herramienta a la vez.** Con ninguna activa, el editor se comporta como siempre: la selección y los gizmos no cambian. Escape suelta la herramienta.
- **Un trazo** es apretar el botón izquierdo, arrastrar y soltar. Se ve en vivo mientras arrastrás, y es **un solo paso** de deshacer y rehacer (Ctrl+Z) del editor. Repetir una casilla en el mismo trazo no cuenta dos veces. La cámara del editor (botón del medio o derecho) sigue andando.
- **Dónde queda guardado.** Lo pintado se escribe en un `GridLayout`. Si el `GridBoard` no tenía `layout`, el primer trazo crea uno desde su forma actual y lo asigna (deshacer también lo saca). Así queda como sub-recurso dentro de la escena. Para guardarlo en su propio archivo: en el inspector, clic derecho sobre `layout` → *Save*.
- **Guardar el mapa.** Un layout que es un archivo `.tres` se guarda en su archivo cuando guardás la escena (Ctrl+S), con Guardar todo o al correr el juego (F5, F6). Un layout que está dentro de la escena se guarda con ella. Si cerrás con un mapa pintado sin guardar, el editor pregunta. Solo se escribe un `.tres` que el pincel cambió de verdad: pintar y deshacer hasta el estado original no lo toca.
- **Con `layout`, manda el layout.** `shape`, `diagonals`, `columns`, `rows` y `radius` quedan de solo lectura. Para pasar la forma actual a un layout sin pintar, usá el botón **Save shape as layout** de la barra.
- **La barra se rearma** cuando cambian las losetas de `tiles`.
- **Las alturas** se escriben en la clave `height_key` del tablero y quedan en el layout como cualquier otro valor. Si el tablero no tiene `height_key`, el primer trazo de alturas le pone `height` (deshacer también la saca). La loseta sube mientras arrastrás, y el pincel elige la casilla por donde se la ve: por arriba o por el costado. Ver [Alturas](#alturas).
- **Al jugar, el layout no se toca.** El `GridBoard` juega una copia: lo que el juego cambia con `set_value` no vuelve al `.tres`.

## Alturas

Cada casilla puede tener su altura: una meseta, un pozo, un marco de piedras más alto. La altura es un valor más de la casilla (un número, int o float) y el `GridBoard` dice cuál con dos propiedades:

| Propiedad | Qué hace |
| --- | --- |
| `height_key` | La clave del valor que es la altura, por ejemplo `height`. Vacía (por defecto): el tablero es plano |
| `height_scale` | Cuántas unidades de mundo vale una altura de 1 (por defecto 1): una casilla con altura 2 queda en Y = 2 × `height_scale` |

- **Todo sube junto.** `cell_to_position(cell)` devuelve el centro de la casilla con su altura en Y. Las losetas de `GridView3D`, las marcas de `GridCursor` y lo que tu juego ubica con `cell_to_position` quedan a la misma altura sin saber nada de alturas.
- **Se pinta en el editor** con **Raise**, **Lower** y **Set height** de la barra GridKit, y la vista 3D muestra el mapa con sus alturas.
- **Cuando cambia una altura** (`set_value`, `paint`, deshacer), la loseta y la marca de esa casilla se mueven; no se crean de nuevo. Cambiar `height_key` o `height_scale` reubica todo, igual que `cell_size`.
- **Los clics eligen lo que se ve.** Cada casilla es una columna que llega hasta su altura, y el rayo de la cámara elige la primera columna que toca, por arriba o por el costado: una casilla alta tapa a la baja que tiene detrás. Una casilla fuera del tablero cuenta con altura 0.
- **`position_to_cell` ignora la altura.** Solo cuentan X y Z: un punto arriba, abajo o adentro de una columna es esa casilla.
- **Un valor que no es un número** (un texto, un `bool`) cuenta como altura 0, con un aviso por tablero.
- **Las losetas, macizas.** Como los clics tratan cada casilla como una columna, conviene que la escena de la loseta tenga cuerpo hacia abajo (un prisma, no una lámina), o se ve el hueco bajo las casillas altas.

Una ficha se ubica sobre la casilla (2, 3) y sube con ella si la casilla cambia de altura. Los dos `@export` se asignan en el inspector:

```gdscript
@export var board: GridBoard
@export var piece: Node3D

var cell := Vector2i(2, 3)


func _ready() -> void:
	piece.position = board.cell_to_position(cell)
	board.cell_changed.connect(_on_cell_changed)


func _on_cell_changed(changed: Vector2i, key: StringName, _value: Variant) -> void:
	if changed == cell and key == board.height_key:
		piece.position = board.cell_to_position(cell)
```

## Ejemplos

- `examples/minimal_3d/minimal_3d.tscn` (F6): un hexágono de radio 4 con agua en el borde, llanura, bosque y montaña, que sale de `map.tres` (un `GridLayout`). Un clic marca la casilla y sus 6 vecinas, y el puntero marca la casilla de abajo.

```
Minimal3D                 # minimal_3d.gd: solo conecta las señales; sus @export (board, view, selection, hover) apuntan a los nodos de abajo
├── Camera, Sun
└── Board                 # GridBoard: layout = map.tres
    └── View              # GridView3D: tiles = {plain, forest, mountain, water}
        ├── Selection     # GridCursor amarillo
        └── Hover         # GridCursor blanco
```

- `examples/squares_3d/squares_3d.tscn` (F6): un tablero de cuadrados de 8 × 8 con dos losetas. Un clic marca las casillas a 2 pasos (`cells_in_range`) y el camino desde el clic anterior (`find_path`).

## Coordenadas

**Hexágonos**

- **Pointy-top** en coordenadas **offset odd-r**: `Vector2i(columna, fila)`, con las filas impares corridas media casilla a la derecha.
- Por dentro se calcula en coordenadas cúbicas (`HexGrid.to_cube` / `from_cube`).
- Vecinos, en orden fijo: este, noreste, noroeste, oeste, suroeste, sureste (`HexGrid.CUBE_DIRECTIONS`).
- Distancia: pasos entre casillas (cúbica). `cell_size` es el ancho de lado a lado.

**Cuadrados**

- `Vector2i(columna, fila)`; el norte es la fila anterior (`fila - 1`).
- Vecinos, en orden fijo: este, norte, oeste, sur y, con `diagonals`, después noreste, noroeste, suroeste, sureste.
- Distancia: sin diagonales, **Manhattan** (4 vecinas); con diagonales, **Chebyshev** (8 vecinas, un paso en diagonal vale 1). `cells_in_range` usa la misma distancia. `cell_size` es el lado.

**Las dos**

- En 3D el tablero está en el plano XZ: la columna avanza en X y la fila en Z. El centro de la casilla (0, 0) está en el origen. Con `height_key`, la altura de cada casilla va en Y.
- `CellGrid.NO_CELL` significa "ninguna casilla", por ejemplo un clic fuera del tablero.
- Las listas siempre vuelven en el mismo orden: por fila y después por columna. Así los resultados no dependen del orden de un diccionario, y una partida con semilla se repite igual.

## API

### `CellGrid` (RefCounted): lo común a las dos formas

| Miembro | Qué hace |
| --- | --- |
| `add_cell`, `remove_cell`, `has_cell`, `size()`, `cells()` | Las casillas del tablero. Agregar o quitar una emite `cells_changed` |
| `add_cells(list)` / `remove_cells(list)` | Lo mismo para muchas casillas, con **un solo** `cells_changed` |
| `set_value(cell, key, value)`, `get_value(cell, key, default)`, `values(cell)` | Valores por casilla y clave (`StringName`) |
| `erase_value(cell, key)` | Saca un valor. Emite `value_changed` con `null` |
| `neighbors(cell, on_board_only := true)` | Las vecinas, en el orden de las direcciones. Con `on_board_only` apagado también las que quedan fuera del tablero: siempre `direction_count()` casillas, y el índice es la dirección |
| `direction_count()`, `neighbor(cell, direction)` | Cuántas vecinas tiene una casilla (6 en hexágonos; 4, u 8 con diagonales) y la casilla a un paso en esa dirección, esté o no en el tablero |
| `direction_to(a, b)` | Hacia qué lado de `a` está `b` (la dirección), o -1 si no es vecina |
| `outline(rings := 1)` | Las casillas que rodean el tablero, a `rings` de profundidad (en cuadrados alcanza con tocar una esquina). Para un marco, una niebla o una costa |
| `cells_with(key, value)` | Las casillas con ese valor (las de inicio: `cells_with(&"start", seat)`). Un `String` y un `StringName` con el mismo texto coinciden, y también un int y un float con el mismo número |
| `center_cell()` | La casilla más cercana al centro de la forma (el promedio de los centros), o `NO_CELL` si el tablero está vacío |
| `distance(a, b)` | Pasos entre dos casillas (método de la grilla: depende de la forma) |
| `cells_in_range(cell, radius)` | Las casillas a `radius` pasos o menos, incluida `cell` |
| `find_path(from, to, cost)` | El camino más barato (A*). `cost` es `func(from, to) -> float`; `INF` o un valor negativo es intransitable. Sin `cost`, cada paso vale 1 |
| `flood(cell, accepts)` | Las casillas conectadas a `cell` que cumplen `accepts(cell) -> bool` |
| `cell_to_local(cell, cell_size)` / `local_to_cell(point, cell_size)` | Del centro de una casilla al plano y del plano a una casilla |
| `cell_outline(cell_size)` | Las esquinas de una casilla alrededor de su centro |
| `shape_name()` | `&"hex"` o `&"square"` |
| `to_dict()` / `CellGrid.from_dict(data)` | Datos planos para guardar o mandar por red. `from_dict` devuelve un `HexGrid` o un `SquareGrid` según `"shape"` y también lee el formato de 0.2 |
| `CellGrid.NO_CELL` | "Ninguna casilla" |
| señal `value_changed(cell, key, value)` | Cambió o se borró (`null`) un valor |
| señal `cells_changed` | Se agregaron o se quitaron casillas |

`to_dict()` devuelve `{"shape": "hex" | "square", "diagonals": bool (solo cuadrados), "cells": [[columna, fila, {clave: valor}], …]}`.

### `HexGrid` (extiende `CellGrid`)

| Miembro | Qué hace |
| --- | --- |
| `HexGrid.rect(columns, rows)` / `HexGrid.hexagon(radius)` | Tablero rectangular, o hexagonal centrado en (0, 0) |
| `HexGrid.to_cube(cell)` / `from_cube(cube)` | Coordenadas cúbicas (estáticas) |
| `HexGrid.CUBE_DIRECTIONS` | Las seis direcciones, en el orden de los vecinos |

### `SquareGrid` (extiende `CellGrid`)

| Miembro | Qué hace |
| --- | --- |
| `SquareGrid.rect(columns, rows, diagonals := false)` | Tablero rectangular, de (0, 0) a (columns - 1, rows - 1) |
| `SquareGrid.disc(radius, diagonals := false)` | Todas las casillas a `radius` pasos de (0, 0): un rombo, o un cuadrado con diagonales |
| `diagonals` | Apagado: 4 vecinas y distancia Manhattan. Encendido: 8 vecinas y distancia Chebyshev |

### `GridLayout` (Resource)

| Miembro | Qué hace |
| --- | --- |
| `shape` (`HEX` o `SQUARE`), `diagonals` | La forma (las diagonales solo para cuadrados) |
| `cells` | `Dictionary[Vector2i, Dictionary]`: cada casilla y sus valores. La forma del mapa son sus claves |
| `make_grid()` | Una grilla **nueva** con estas casillas y valores. Es una copia: el juego la cambia sin tocar el recurso. Devuelve un `CellGrid`; si tu estado tipa la forma, `layout.make_grid() as HexGrid` (o `as SquareGrid`) |
| `read_grid(grid)` / `GridLayout.from_grid(grid)` | Copia la forma y los valores de una grilla al recurso |
| `has_cell`, `add_cell`, `remove_cell` | Editan las casillas |
| `set_value(cell, key, value)`, `erase_value(cell, key)`, `get_value(cell, key, default)` | Editan los valores (`set_value` agrega la casilla si no está) |
| señal `changed` | Cada edición la emite (la del `Resource`) |

### `GridBoard` (Node)

- **Inspector:** `layout`, `shape` (Hexagons o Squares), `diagonals` (solo cuadrados), `columns`, `rows`, `radius` (si es mayor a 0: todas las casillas a `radius` pasos de (0, 0), en las dos formas), `cell_size`, `height_key` (la clave de la altura; vacía: tablero plano) y `height_scale` (unidades de mundo por altura 1). Con `layout`, la grilla sale del layout y la forma del inspector no aplica. `save_shape_as_layout()` crea un layout desde la forma actual (en el editor, el botón de la barra GridKit hace lo mismo con deshacer).
- **Grilla:** `grid` es la `CellGrid` que muestra. `use_grid(grid)` muestra la grilla de tus reglas en vez de la propia y `use_own_grid()` vuelve a la del layout o el inspector.
- **Consultas:** `has_cell`, `cells`, `set_value`, `get_value`, `neighbors`, `neighbor`, `direction_to`, `distance`, `cells_in_range`, `find_path`, `flood`, `outline`, `cells_with` y `center_cell`, más `cell_to_position(cell) -> Vector3` (el centro de la casilla, con su altura en Y), `cell_height(cell) -> float` (la altura en unidades de mundo; 0 sin `height_key`), `position_to_cell(point) -> Vector2i` (`NO_CELL` fuera del tablero) y `position_to_any_cell(point)` (la casilla bajo el punto aunque no esté en el tablero). Estas dos solo miran X y Z: la altura no cambia la respuesta. Lo demás (`values`, `size`, `add_cell`, `erase_value`, `to_dict`) va por `board.grid`.
- **Editar de a muchas:** `paint(key, {casilla: valor})` (un valor `null` borra la clave) y `set_cells(add, remove, values)` (`values` es `{casilla: {clave: valor}}` para las casillas nuevas). En el editor, con `layout`, escriben también en el layout; al jugar, solo en la grilla.
- **Señales:** `cell_changed(cell, key, value)` y `rebuilt` (otra grilla, otra forma, `cell_size`, `height_key` o `height_scale`, o casillas agregadas o quitadas). Las vistas y los cursores se actualizan solos con ella.

### `GridView3D` (Node3D, hijo de un `GridBoard`)

- **Inspector:**
  - `tiles`: `Dictionary[StringName, PackedScene]`.
  - `default_tile` y `value_key`.
  - `input_enabled`.
  - `click_max_drag_px`: si el puntero se mueve más que esto entre apretar y soltar, es un arrastre y no un clic.
  - `camera`: si queda vacía, usa la cámara actual.
- **Métodos:** `redraw()`, `tile_at(cell)`, `cell_at_screen(point)`, `cell_at_ray(origin, direction, on_board_only := true)` y `board()`.
- **Señales:** `cell_clicked(cell)` (mouse o toque) y `cell_hovered(cell)` (`NO_CELL` al salir del tablero); `tile_created(cell, tile)` cuando arma una loseta, y `drawn` cuando todas las losetas están en su lugar.
- **Cada loseta sabe su casilla.** La loseta ya está en el centro de su casilla cuando sale `tile_created`, y todavía no entró al árbol: lo que le pongas ahí (su casilla, sus datos) ya está en su `_ready`. `drawn` sale después de un `rebuilt`, de cambiar `tiles`, `default_tile` o `value_key`, o de `redraw()`; una casilla que cambia de valor solo emite `tile_created`.
- **Clics sin colliders:** el rayo de la cámara se cruza con el plano del tablero. En un tablero con alturas (`height_key`), elige la primera casilla que el rayo toca, por arriba o por el costado; `cell_at_ray`, `cell_at_screen`, `cell_clicked` y `cell_hovered` responden así. Sin `height_key`, todo sigue como antes y cuesta lo mismo.
- Cuando el tablero gana o pierde casillas, solo se dibujan o se liberan esas losetas. Al borrar un valor (`erase_value`), la casilla vuelve a `default_tile`. Cuando cambia la altura de una casilla, su loseta se mueve (no se crea de nuevo).

### `GridCursor` (Node3D, hijo de un `GridView3D`)

- **Inspector:**
  - `marker`: la escena del marcador. Si queda vacía, dibuja un hexágono o un cuadrado plano (según la forma del tablero) del `color` elegido.
  - `color`, `lift` y `fill`.
- **Métodos:** `highlight(cells)` (reemplaza la marca anterior), `clear()` y `highlighted()`.
- Si el tablero cambia (`rebuilt`), el cursor lo atiende **una vez por cuadro**: las marcas sobre casillas que ya no están se liberan y las demás se mueven a su lugar (no se recrean). El marcador por defecto comparte una malla y un material entre todas las marcas.
- En un tablero con alturas, cada marca queda `lift` por encima de su casilla y la sigue cuando cambia de altura.
- Usá un cursor por significado: movimientos válidos, selección, hover.

## Tips

- **Las reglas usan `CellGrid`, no los nodos.** Guardá la grilla en el estado de tu partida y mostrala con `board.use_grid(state.grid)`. Así las reglas corren headless y la vista se actualiza sola con `value_changed`. Sin ningún nodo: `layout.make_grid()` o `HexGrid.rect(…)` / `SquareGrid.rect(…)`.
- **Ver el tablero en el editor aunque la grilla llegue al correr.** Dejá un `layout` (o las columnas y filas) en el `GridBoard`: es lo que muestra el editor, y `use_grid` lo reemplaza al correr.
- **El arrastre de la cámara no es un clic.** Ajustá `click_max_drag_px`. Si tu cámara tiene su propio estado de arrastre, apagá `input_enabled` mientras arrastra.
- **Losetas de otros packs.** Si vienen flat-top, rotalas 90° en su escena. En hexágonos `cell_size` es el ancho de lado a lado; en cuadrados, el lado.
- **Muchas casillas de golpe.** `add_cells` y `remove_cells` emiten una sola señal; `add_cell` en un bucle emite una por casilla (igual la vista y los cursores agrupan lo que dibujan en un cuadro).
- **El costo de subir.** La altura es un valor más: en el `cost` de `find_path`, compará `get_value(to, &"height", 0)` con el de `from` y devolvé `INF` si el escalón es muy alto.
- **Un mapa tuyo.** Cargá el layout con `ResourceLoader.load` o asignalo en el inspector; para armar uno por código: `layout.set_value(cell, &"terrain", &"forest")`, o `GridLayout.from_grid(grid)` y `ResourceSaver.save(layout, "res://map.tres")`.

## Migrar desde 0.2

| Antes (0.2) | Ahora (0.3) |
| --- | --- |
| `HexGrid.distance(a, b)` (estático) | `grid.distance(a, b)` (de la grilla; el tablero también: `board.distance(a, b)`) |
| `HexGrid.cell_to_local(cell, size)` / `local_to_cell(point, size)` (estáticos) | `grid.cell_to_local(cell, size)` / `grid.local_to_cell(point, size)` |
| `GridBoard.grid` es un `HexGrid` | Es un `CellGrid` (un `HexGrid` o un `SquareGrid`) |
| `to_dict()` con `"shape": 0` | `"shape": "hex"` (o `"square"`). `CellGrid.from_dict` lee el formato viejo |
| `HexGrid.from_dict(data)` | `CellGrid.from_dict(data)` (devuelve lo que diga el dato; `HexGrid.from_dict` sigue andando) |
| `HexGrid.NO_CELL`, `HexGrid.Shape` | `CellGrid.NO_CELL` (`HexGrid.NO_CELL` también anda); `shape_name()` reemplaza a `Shape` |
| Un mapa propio (filas de letras, un diccionario) que se pinta en `_ready` | Un `GridLayout`: `layout.set_value(cell, &"terrain", …)` una vez, o `GridLayout.from_grid(grid)` y `ResourceSaver.save`; se asigna en `GridBoard.layout` |
| `GridBoard.radius` solo hexágonos | Vale para las dos formas |
| `GridView3D.cell_at_screen` | Sigue igual; `cell_at_ray(origin, direction)` es lo que usa por dentro |

## Tests

```bash
godot --headless --path gridkit_lab --script res://addons/grid_kit/tests/grid_test_runner.gd
```

Sale `GRIDKIT TESTS PASS (n)`. Los tests cubren:

- Hexágonos y cuadrados: formas y coordenadas, vecinos (4 y 8, en orden), distancia, rango, caminos con costo, con y sin diagonales, flood, ida y vuelta casilla ↔ punto, direcciones (`direction_to`, `neighbor`), vecinas fuera del tablero, `outline` (con las esquinas en cuadrados), `cells_with` (texto y números de distinto tipo) y `center_cell`.
- `CellGrid`: `from_dict` elige la clase y lee el formato de 0.2, `add_cells` emite una vez, `erase_value`.
- `GridLayout`: `make_grid`, `read_grid`, `from_grid`, `changed` y guardar y cargar un `.tres`.
- Los nodos: forma desde el inspector, `radius` en cuadrados, el layout manda, rearmado agrupado, `paint` y `set_cells` (con y sin layout), `position_to_any_cell`, losetas por casilla, `tile_created` y `drawn`, redibujo, `use_grid`, `cell_at_ray`, clic, arrastre y avisos del editor.
- `GridCursor`: los mismos nodos tras 1000 `add_cell`, que solo se libera la marca de la casilla quitada, `cell_size` mueve sin recrear, marcador cuadrado.
- Las alturas: `cell_to_position` con y sin `height_key`, con int y float, un valor que no es número; que la loseta y la marca se mueven sin recrearse; que `height_scale` y `height_key` reubican todo; la vista previa de un layout; los clics sobre una casilla alta que tapa a una baja y sobre una baja descubierta, en hexágonos y en cuadrados, con la vista movida, girada y escalada, fuera del tablero y después de cada cambio; y que sin `height_key` nada cambia.
- El trazo del pincel (sin editor): pintar, repetir, borrar, agregar y quitar casillas con sus valores, subir, bajar y fijar alturas, crear el layout y la clave de altura, y que el resultado deshace todo.
- La herramienta del pincel con un historial de deshacer de prueba: los botones de la barra, un trazo de alturas como un solo paso que se deshace y se rehace, Shift, los números de la barra y que el pincel encuentra una casilla alta por arriba.
- Los dos ejemplos jugados con eventos de mouse.
- Que el addon no nombre a ningún otro kit.

El chequeo del editor (`godot --headless --editor --path gridkit_lab -- --gridkit-editor-check`) pasa por el editor real: la barra, los trazos de losetas y de alturas con el deshacer del editor, elegir una casilla alta desde la cámara de la vista 3D y lo que queda guardado en disco.

Lo que **no** cubre ninguno de los dos (necesita una ventana y un mouse de verdad): cómo se ve la barra, el arrastre real y el marcador del pincel sobre una casilla alta.
