# GridKit

Tableros hexagonales para juegos de estrategia, tácticos, de mesa o puzzles. Hay dos niveles:

- **`HexGrid`**: el tablero como datos puros (`RefCounted`, sin nodos ni escena). Guarda valores por casilla y responde vecinos, distancia, rango, caminos y flood. Las reglas de tu juego lo usan directo y se testea headless.
- **Nodos para verlo**:
  - `GridBoard` arma o muestra un `HexGrid`.
  - `GridView3D` lo dibuja con una escena por casilla y reporta clics y hover.
  - `GridCursor` marca casillas.

GridKit **no tiene** reglas de juego, unidades, niebla ni red, y no tiene autoload.

## Instalar

```bash
./install.sh --addon /path/to/godot-project grid_kit
```

Habilitá el plugin **GridKit** (tipos `GridBoard`, `GridView3D` y `GridCursor` en Create Node).

## En 3 pasos

1. Agregá un `GridBoard` y elegí la forma en el inspector: `columns` × `rows`, o `radius` para un hexágono. Elegí también `cell_size`, el ancho de un hex de lado a lado.
2. Agregale un hijo `GridView3D`. En `tiles` poné una escena por valor (por ejemplo `plain`, `forest`, `water`) y en `value_key` la clave que elige la escena (por defecto `terrain`).
3. Conectá `cell_clicked` y consultá el tablero:

```gdscript
@onready var board: GridBoard = $Board
@onready var moves: GridCursor = $Board/View/Moves


func _ready() -> void:
	board.set_value(Vector2i(2, 3), &"terrain", &"forest")
	$Board/View.cell_clicked.connect(_on_cell_clicked)


func _on_cell_clicked(cell: Vector2i) -> void:
	moves.highlight(board.neighbors(cell))
```

## Ejemplo mínimo

`examples/minimal_3d/minimal_3d.tscn` (F6): un hexágono de radio 4 con agua en el borde, llanura, bosque y montaña. Un clic marca la casilla y sus 6 vecinas, y el puntero marca la casilla de abajo.

```
Minimal3D                 # minimal_3d.gd: pinta el terreno y conecta las señales
├── Camera, Sun
└── Board                 # GridBoard: radius = 4
    └── View              # GridView3D: tiles = {plain, forest, mountain, water}
        ├── Selection     # GridCursor amarillo
        └── Hover         # GridCursor blanco
```

## Coordenadas

- Hexágonos **pointy-top** en coordenadas **offset odd-r**: `Vector2i(columna, fila)`, con las filas impares corridas media casilla a la derecha.
- Por dentro se calcula en coordenadas cúbicas (`HexGrid.to_cube` / `from_cube`).
- En 3D el tablero está en el plano XZ: la columna avanza en X y la fila en Z.
- `HexGrid.NO_CELL` significa "ninguna casilla", por ejemplo un clic fuera del tablero.
- Las listas siempre vuelven en el mismo orden: por fila y después por columna. Los vecinos van en el orden fijo de `CUBE_DIRECTIONS`. Así los resultados no dependen del orden de un diccionario, y una partida con semilla se repite igual.

## API

### `HexGrid` (RefCounted)

| Miembro | Qué hace |
| --- | --- |
| `HexGrid.rect(columns, rows)` / `HexGrid.hexagon(radius)` | Tablero rectangular, o hexagonal centrado en (0, 0) |
| `add_cell`, `remove_cell`, `has_cell`, `size()`, `cells()` | Las casillas del tablero |
| `set_value(cell, key, value)`, `get_value(cell, key, default)`, `values(cell)` | Valores por casilla y clave (`StringName`) |
| `neighbors(cell)` | Las vecinas que están en el tablero |
| `HexGrid.distance(a, b)` | Pasos entre dos casillas |
| `cells_in_range(cell, radius)` | Las casillas a `radius` pasos o menos, incluida `cell` |
| `find_path(from, to, cost)` | El camino más barato (A*). `cost` es `func(from, to) -> float`; `INF` o un valor negativo es intransitable. Sin `cost`, cada paso vale 1 |
| `flood(cell, accepts)` | Las casillas conectadas a `cell` que cumplen `accepts(cell) -> bool` |
| `HexGrid.cell_to_local(cell, cell_size)` / `local_to_cell(point, cell_size)` | Del centro de una casilla al plano y del plano a una casilla |
| `to_dict()` / `HexGrid.from_dict(data)` | Datos planos para guardar o mandar por red |
| señal `value_changed(cell, key, value)` | Cambió un valor |

### `GridBoard` (Node)

- **Inspector:** `columns`, `rows`, `radius` (si es mayor a 0, el tablero es hexagonal) y `cell_size`.
- **Grilla:** `grid` es la `HexGrid` que muestra. `use_grid(grid)` muestra la grilla de tus reglas en vez de la propia y `use_own_grid()` vuelve a la del inspector.
- **Consultas:** las mismas de `HexGrid`, más `cell_to_position(cell) -> Vector3` y `position_to_cell(point) -> Vector2i`.
- **Señales:** `cell_changed(cell, key, value)` y `rebuilt`.

### `GridView3D` (Node3D, hijo de un `GridBoard`)

- **Inspector:**
  - `tiles`: `Dictionary[StringName, PackedScene]`.
  - `default_tile` y `value_key`.
  - `input_enabled`.
  - `click_max_drag_px`: si el puntero se mueve más que esto entre apretar y soltar, es un arrastre y no un clic.
  - `camera`: si queda vacía, usa la cámara actual.
- **Métodos:** `redraw()`, `tile_at(cell)`, `cell_at_screen(point)` y `board()`.
- **Señales:** `cell_clicked(cell)` (mouse o toque) y `cell_hovered(cell)` (`NO_CELL` al salir del tablero).
- **Clics sin colliders:** el rayo de la cámara se cruza con el plano del tablero.

### `GridCursor` (Node3D, hijo de un `GridView3D`)

- **Inspector:**
  - `marker`: la escena del marcador. Si queda vacía, dibuja un hexágono plano del `color` elegido.
  - `color`, `lift` y `fill`.
- **Métodos:** `highlight(cells)` (reemplaza la marca anterior), `clear()` y `highlighted()`.
- Usá un cursor por significado: movimientos válidos, selección, hover.

## Tips

- **Las reglas usan `HexGrid`, no los nodos.** Guardá la grilla en el estado de tu partida y mostrala con `board.use_grid(state.grid)`. Así las reglas corren headless y la vista se actualiza sola con `value_changed`.
- **El arrastre de la cámara no es un clic.** Ajustá `click_max_drag_px`. Si tu cámara tiene su propio estado de arrastre, apagá `input_enabled` mientras arrastra.
- **Losetas de otros packs.** Si vienen flat-top, rotalas 90° en su escena. `cell_size` es el ancho de lado a lado.

## Tests

```bash
godot --headless --path gridkit_lab --script res://addons/grid_kit/tests/grid_test_runner.gd
```

Sale `GRIDKIT TESTS PASS (n)`. Los tests cubren:

- Formas y coordenadas, vecinos, distancia, rango, caminos con costo y flood.
- `to_dict`.
- Los nodos: losetas por casilla, redibujo, `use_grid`, clic, arrastre y avisos del editor.
- El ejemplo jugado con eventos de mouse.
- Que el addon no nombre a ningún otro kit.
