---
description: "Tableros de hexágonos o de cuadrados (addon GridKit): la grilla como datos, el mapa guardado como un GridLayout que se pinta en la vista 3D del editor, una escena por casilla con clic y hover, y cursores que marcan casillas."
---

Agregá un **tablero de hexágonos o de cuadrados** en el **proyecto Godot del juego** con el addon GridKit:
- un `GridBoard` con la forma del tablero (hexágonos o cuadrados, tamaño o radio) o con un `GridLayout` guardado;
- un `GridView3D` hijo con una escena por casilla (`tiles`);
- un `GridCursor` por cada cosa que se marca (movimientos válidos, selección, hover);
- si el juego tiene niebla de guerra, un `GridFog` hijo del `GridView3D` (y un `CellFog` en las reglas);
- la grilla del juego (`CellGrid`) para las reglas, si el juego tiene reglas sobre las casillas.

Después la persona pinta el mapa con la barra **GridKit** de la vista 3D; el agente arma el tablero y conecta lo que hace el clic.

Esto **no** son las reglas del juego, las unidades ni los turnos: el kit sabe de casillas, vecinos, distancia, rango, caminos y qué conoce cada jugador, y el juego decide qué significan y qué ve cada unidad. **No** es la red.

Cargar: `godot-grid-kit`, `godot-composition-first`.

Si falta `addons/grid_kit/`:

```bash
./install.sh --addon /ABS/GODOT_ROOT grid_kit
```

Habilitá **GridKit**. Si `godot-studio-workflow` está cargado: orquestador → árbol (este chat si son 1–3 archivos; si no, `studio-tech-lead`) → OK → `studio-developer`. Sin subagente extra.

## 1. Alcance

Si falta, preguntá en una sola tanda:

1. La forma: hexágonos o cuadrados (y con o sin diagonales), de qué tamaño o con qué radio, y el ancho de una casilla.
2. Los valores por casilla: terreno, y qué más (dueño, costo de pasar, altura); qué loseta se dibuja por cada valor.
3. Si el mapa se pinta a mano en el editor (un `GridLayout`) o lo arma el juego (generado, cargado de un archivo, por red).
4. Qué hace un clic y qué marca el hover; qué cursores hacen falta (movimientos, selección, camino).
5. Si hay reglas sobre las casillas (alcance, costo de moverse, caminos): quién las tiene y en qué parte del juego viven.
6. Si hay niebla de guerra: cuántos jugadores, cuánto ve cada unidad o ciudad, si hay regiones que se revelan para todos.
7. Si el juego es en red o tiene turnos (el kit no los trae: el juego conecta).

## 2. Plan

Mostrá el árbol de archivos antes de tocar el juego (`[+]` nuevo, `[~]` cambiado, `[-]` borrado), por ejemplo:

```
[~] project.godot                        # plugin GridKit
[+] maps/level_1.tres                    # GridLayout: la forma y el terreno (se pinta con la barra GridKit)
[+] tiles/plain.tscn, forest.tscn, water.tscn   # una escena por valor de terrain
[+] board/board.tscn                    # GridBoard (layout) → GridView3D (tiles) → Moves, Hover (GridCursor)
[+] board/board.gd                      # clic → Moves.highlight(cells_in_range); hover → Hover
[~] levels/level/level.tscn                    # instancia el tablero y la cámara
[~] game/rules.gd                        # usa un CellGrid: find_path con el costo del terreno
```

Arrancá desde `addons/grid_kit/examples/minimal_3d` (hexágonos, mapa en un `GridLayout`) o `squares_3d` (cuadrados, rango y camino).

## 3. Implementar

Seguí [godot-grid-kit](../skills/godot-grid-kit/SKILL.md) y `addons/grid_kit/README.md`.

- El `GridBoard` con su forma o con `layout`; el `GridView3D` con `tiles`, `default_tile` y `value_key`.
- Las losetas son escenas con un `Node3D` de raíz; `cell_size` es el ancho de lado a lado (hexágonos) o el lado (cuadrados).
- Las reglas usan un `CellGrid` (`board.grid`, o el del estado de la partida con `board.use_grid`), no los nodos: `neighbors`, `distance`, `cells_in_range`, `find_path(from, to, cost)`, `flood`.
- Un `GridCursor` por significado, con `highlight(cells)` y `clear()`.
- Si hay niebla: el estado guarda un `CellFog` y lo recalcula después de cada orden con `see(seat, grid.cells_near(own_cells, radius))` (o `cells_visible_from` si el terreno tapa la vista); la escena pone un `GridFog` hijo del `GridView3D` con `use_fog(state.fog)` y `shown_observer` en el asiento de esta máquina. Las piezas del juego y los clics sobre casillas ocultas se filtran con `fog.sees(seat, cell)`. En red, cada cliente recibe solo `fog.observer_to_dict(seat)`.
- Si las casillas tienen alturas: `height_key` (por ejemplo `height`) y `height_scale` en el `GridBoard`; todo lo que va sobre el tablero se ubica con `board.cell_to_position(cell)`, que ya trae la altura. Las losetas, macizas hacia abajo.
- Decile a la persona cómo pintar: seleccionar el `GridBoard` muestra la barra **GridKit** (una loseta, **Erase**, **Add cells**, **Remove cells**, y **Raise**, **Lower** y **Set height** para las alturas); un trazo se deshace con Ctrl+Z; lo pintado queda en el `layout`.
- Corré `godot --headless --path gridkit_lab --script res://addons/grid_kit/tests/grid_test_runner.gd` si tocás el kit.

## 4. Listo cuando

- El `GridBoard` no muestra avisos y la persona pintó (o sabe pintar) el mapa con la barra **GridKit**.
- F6: el tablero se dibuja con una loseta por casilla; un clic y el hover marcan lo que pidió el alcance.
- Las reglas corren sin nodos con un `CellGrid`.
- Nada de reglas del juego, unidades, turnos ni red dentro de `addons/grid_kit`.
