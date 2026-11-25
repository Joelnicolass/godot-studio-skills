---
name: godot-grid-kit
description: >-
  Tableros de hexágonos o de cuadrados en un juego Godot 4 3D, con el addon
  GridKit: la grilla como datos puros (CellGrid: HexGrid y SquareGrid, con
  valores por casilla, vecinos, distancia, rango, caminos con costo y flood), el
  mapa como un recurso que se guarda (GridLayout), un GridBoard que lo muestra,
  un GridView3D que dibuja una escena por casilla y reporta clics y hover sin
  colliders, GridCursor para marcar casillas y un pincel en la vista 3D del
  editor para pintar el terreno y agregar o quitar casillas con deshacer. Usar
  cuando el usuario quiere un tablero, una grilla de hexágonos o de cuadrados,
  un juego de estrategia por turnos, táctico, de mesa o un puzzle sobre una
  grilla, pintar un mapa en el editor, caminos o rangos de movimiento sobre una
  grilla o /add-grid. No son las reglas del juego, las unidades, la niebla, los
  turnos ni la red.
---

# Godot — tableros de hexágonos o de cuadrados (GridKit)

Addon `addons/grid_kit/` en el proyecto del **juego**. Referencia: `addons/grid_kit/README.md`.

Si el addon no está:

```bash
./install.sh --addon /path/to/godot-project grid_kit
```

Habilitá el plugin **GridKit** (la barra del pincel en la vista 3D; los nodos andan sin él). Pedido acotado: `/add-grid`. Composición: [godot-composition-first](../godot-composition-first/SKILL.md).

## Reglas

- **Dos formas, una API.** `HexGrid` (pointy-top, odd-r) y `SquareGrid` (`diagonals` apagado: 4 vecinas y Manhattan; encendido: 8 y Chebyshev). Se elige con `shape` en el `GridBoard`. El código del juego no pregunta la forma: usa `grid.neighbors`, `grid.distance`, `grid.cells_in_range`.
- **Las reglas usan la grilla, no los nodos.** El estado de la partida guarda un `CellGrid` y el tablero lo muestra con `board.use_grid(state.grid)`. Las reglas corren headless y la vista se actualiza sola con `value_changed`.
- **El mapa es un `GridLayout`.** La forma y el terreno que se arman a mano van en un layout (`GridBoard.layout`), no en un `_ready` que pinta casilla por casilla ni en un diccionario del juego. El juego juega una copia: el `.tres` no se toca al jugar.
- **Pintar en el editor.** Seleccionar el `GridBoard` muestra la barra **GridKit** en la vista 3D: un botón por cada clave de `tiles`, **Erase**, **Add cells**, **Remove cells**. Un trazo es un paso de deshacer. Si no hay layout, el primer trazo crea uno.
- **Los valores por casilla son claves.** `board.set_value(cell, &"terrain", &"forest")`; qué loseta se dibuja la elige `value_key` de la vista. Otras claves (dueño, costo) las lee el juego.
- **Caminos y rangos.** `find_path(from, to, cost)` con `cost` como `func(from, to) -> float` (`INF` es intransitable); `cells_in_range`, `flood`. Todo en orden fijo (fila, después columna): el mismo resultado en cada corrida.
- **Clics sin colliders.** `GridView3D.cell_clicked` / `cell_hovered`; un arrastre de cámara no es un clic (`click_max_drag_px`).
- **Un cursor por significado.** Un `GridCursor` para los movimientos válidos, otro para la selección, otro para el hover.
- **Ningún kit depende de otro.** GridKit no tiene reglas, unidades, turnos ni red: el juego conecta.

## Árbol

```
Level
├── Camera, Sun
└── Board (GridBoard)              # layout = res://maps/level_1.tres, o shape + columns × rows
    └── View (GridView3D)          # tiles = {plain, forest, water}; value_key = terrain
        ├── Moves (GridCursor)     # los movimientos válidos
        └── Hover (GridCursor)     # la casilla bajo el puntero
```

Arrancá desde `addons/grid_kit/examples/minimal_3d/minimal_3d.tscn` (hexágonos, mapa en un `GridLayout`) o `squares_3d` (cuadrados 8 × 8, rango y camino).

## Qué va dónde

| Kit | Juego |
|---|---|
| La grilla: casillas, valores, vecinos, distancia, rango, caminos, flood | Qué significa cada valor (terreno, dueño, costo) y las reglas que los usan |
| `GridLayout`: el mapa guardado, y el pincel que lo pinta | Qué mapas hay y cuál se carga; el estado de la partida |
| Una escena por casilla y la señal de clic y de hover | Las escenas de las losetas, las unidades sobre el tablero, qué hace un clic |
| Marcar casillas (`GridCursor`) | Cuáles marcar y cuándo |

## API esencial

Al hacer clic en una casilla se marcan las que quedan a 2 pasos, y la casilla (2, 3) pasa a ser bosque. Los tres `@export` se asignan en el inspector:

```gdscript
@export var board: GridBoard
@export var view: GridView3D
@export var moves: GridCursor

func _ready() -> void:
	board.set_value(Vector2i(2, 3), &"terrain", &"forest")
	view.cell_clicked.connect(_on_cell_clicked)

func _on_cell_clicked(cell: Vector2i) -> void:
	moves.highlight(board.cells_in_range(cell, 2))
```

| Pieza | Qué usás |
|---|---|
| `CellGrid` (`HexGrid.rect/hexagon`, `SquareGrid.rect/disc`) | `set_value`, `get_value`, `erase_value`, `neighbors`, `distance(a, b)`, `cells_in_range`, `find_path`, `flood`, `add_cells`, `remove_cells`, `to_dict` / `CellGrid.from_dict`, `value_changed`, `cells_changed` |
| `GridLayout` | `make_grid()` (una copia), `GridLayout.from_grid(grid)`, `set_value`, `erase_value`, `add_cell`, `remove_cell` |
| `GridBoard` | `layout`, `shape`, `diagonals`, `columns`, `rows`, `radius`, `cell_size`; `use_grid(grid)`, `paint(key, {cell: value})`, `set_cells(add, remove)`, `cell_to_position`, `position_to_cell`; `cell_changed`, `rebuilt` |
| `GridView3D` | `tiles`, `default_tile`, `value_key`; `cell_clicked`, `cell_hovered`, `tile_created`, `drawn`, `tile_at`, `cell_at_screen`, `cell_at_ray` |
| `GridCursor` | `highlight(cells)`, `clear()`, `highlighted()`; `marker`, `color`, `lift`, `fill` |

## Listo cuando

- El `GridBoard` no muestra avisos y la persona vio la barra **GridKit** (o sabe que aparece al seleccionar el tablero).
- F6: el tablero se dibuja con sus losetas, un clic marca lo que el juego quiere y el hover sigue al puntero.
- Las reglas del juego corren sin ningún nodo (`HexGrid.rect(…)` o `layout.make_grid()`).
- `godot --headless --path gridkit_lab --script res://addons/grid_kit/tests/grid_test_runner.gd` da `GRIDKIT TESTS PASS` (en el repo del kit).

## Antipatrones

- Preguntar la forma en el código del juego (`if grid is HexGrid`): usá `neighbors`, `distance` y `cells_in_range` de la grilla.
- Calcular la distancia a mano (`abs(a.x - b.x) + …`): en hexágonos no es eso. `grid.distance(a, b)`.
- Un mapa pintado en un `_ready` casilla por casilla: va en un `GridLayout` que se pinta en el editor.
- Cambiar el `GridLayout` en juego esperando que el tablero lo siga: el tablero juega una copia. El estado de la partida va en su grilla.
- Reglas del juego (movimiento, alcance de un arma, quién es dueño) dentro de los nodos del kit: van en el juego.
- Un cursor por casilla en vez de un cursor por significado.
