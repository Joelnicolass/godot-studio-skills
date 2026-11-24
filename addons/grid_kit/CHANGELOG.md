# Cambios de GridKit

## 0.1.0

Primera versión:

- `HexGrid`: el tablero hexagonal como datos puros (pointy-top, offset odd-r). Valores por casilla, vecinos, distancia, rango, caminos con costo, flood y `to_dict` / `from_dict`. Resultados en orden fijo.
- `GridBoard`: arma la grilla desde el inspector (rectángulo o hexágono) o muestra la de tus reglas (`use_grid`).
- `GridView3D`: una escena por casilla según un valor. Clic o toque sin arrastre (`cell_clicked`) y hover (`cell_hovered`), sin colliders.
- `GridCursor`: marca casillas con un hexágono o con tu escena.
- Ejemplo `examples/minimal_3d`, tests propios y `gridkit_lab/`.
