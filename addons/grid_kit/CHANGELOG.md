# Cambios de GridKit

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
