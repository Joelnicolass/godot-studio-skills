---
description: "Árboles de tecnologías, talentos o habilidades (addon UnlockKit): entradas anidadas en el editor, enlaces cruzados con requires y «uno de» con requires_any, comprar con buy(id, pay), por qué no con why_not, deshacer con lock, un grafo por jugador con new_graph, una vista que dibuja el árbol y guardar con unlocked_ids."
---

Agregá un **árbol de desbloqueos** (tecnologías, talentos, habilidades, progresión de metajuego) en el **proyecto Godot del juego** con el addon UnlockKit:
- un `UnlockTree` con una `UnlockEntry` por entrada, anidadas: una entrada adentro de otra la necesita, `requires` agrega enlaces cruzados y `requires_any` los de «uno de»;
- el costo, el título, la descripción y el icono en el inspector de cada entrada, y `start_unlocked` en las del principio;
- un `UnlockTreeView` que dibuja el árbol (también en el editor) y avisa los clics, o instancia una escena del juego por entrada;
- el código del juego: una función `pay(cost) -> bool` que cobra, `tree.buy(id, pay)` para comprar, y los efectos escuchando `unlocked`.

Después la persona ve el árbol dibujado en el editor y lo cambia en el inspector; el agente arma y explica.

Esto **no** conoce la moneda ni aplica efectos: el kit dice qué se puede desbloquear y qué cuesta y ata el orden de la compra, y el juego cobra en su `pay` (con sus reglas o con otro kit) y decide qué da cada entrada. **No** es la red: un juego en red desbloquea en el servidor y manda `unlocked_ids()`.

Cargar: `godot-unlock-kit`, `godot-composition-first`.

Si falta `addons/unlock_kit/`:

```bash
./install.sh --addon /ABS/GODOT_ROOT unlock_kit
```

Habilitá **UnlockKit**. Si `godot-studio-workflow` está cargado: orquestador → árbol (este chat si son 1–3 archivos; si no, `studio-tech-lead`) → OK → `studio-developer`. Sin subagente extra.

## 1. Alcance

Si falta, preguntá en una sola tanda:

1. Qué se desbloquea (tecnologías, talentos, habilidades, mejoras) y cuántas entradas hay, en qué ramas.
2. Qué necesita qué: la cadena de cada rama, los enlaces cruzados entre ramas y las que piden «una de varias».
3. Qué cuesta cada una y con qué se paga (puntos, una moneda, experiencia); con qué se empieza.
4. Qué da cada entrada al desbloquearse, y si se puede deshacer.
5. Cuántos jugadores (un árbol por jugador), si se guarda la partida y si es en red. Si el jugador ve el árbol (una vista) o solo un menú.

## 2. Plan

Mostrá el árbol de archivos antes de tocar el juego (`[+]` nuevo, `[~]` cambiado, `[-]` borrado), por ejemplo:

```
[~] project.godot                        # plugin UnlockKit
[+] research/tech_tree.tscn       # UnlockTree con las UnlockEntry anidadas por rama; costos en el inspector
[+] research/research.gd          # pay(cost) -> bool, buy(id) con tree.buy(id, pay), los efectos en unlocked
[+] research/tech_entry.gd        # @tool, extends UnlockEntry: los datos del efecto como @export tipados
[+] ui/tech_tree_panel.tscn       # UnlockTreeView: tree asignado; entry_pressed → research.buy(id)
[~] save/save_game.gd             # guarda unlocked_ids(), carga con restore(ids)
[~] levels/level/level.tscn       # instancia el árbol y el panel
[~] docs/tuning.md                # una fila por costo: archivo, nodo (la entrada), cost
```

Arrancá desde `addons/unlock_kit/examples/minimal/minimal.tscn` (tres ramas, un enlace cruzado, un «uno de», una tecnología del principio, comprar con puntos).

## 3. Implementar

Seguí [godot-unlock-kit](../skills/godot-unlock-kit/SKILL.md) y `addons/unlock_kit/README.md`.

- Una `UnlockEntry` por entrada, anidada bajo la que necesita; un `Node` común por rama; `requires` solo para los enlaces cruzados; `requires_any` para «una de varias».
- `cost`, `title`, `description` e `icon` en el inspector de cada entrada; `id` escrito a mano si se guardan partidas.
- El juego compra con una llamada: `tree.buy(id, pay)`, donde `pay(cost) -> bool` cobra todo o nada. Si no se puede, `why_not(id)` (un `String`) y `missing(id)` dan el motivo.
- Lo que da cada entrada va en un script `@tool` que `extends UnlockEntry`, con `@export` tipados.
- Los efectos escuchan `tree.unlocked` (o la señal `unlocked` de una entrada, conectada en el editor). Deshacer: `lock(id)` y devolver lo cobrado.
- Con varios jugadores: `player.unlocks = tree.new_graph()` por jugador en las reglas y `tree.use_graph(player.unlocks)` para el activo (o una instancia del árbol por jugador); la vista escucha `rebuilt`.
- Guardar con `unlocked_ids()` / `restore(ids)`. En red, el servidor desbloquea y manda la lista.
- Decile a la persona cómo verlo: abrir la escena del árbol muestra la vista dibujada, y el editor avisa de un id repetido, un requisito de otro árbol o un ciclo.

## 4. Listo cuando

- El árbol y sus entradas no muestran avisos, y la persona vio el árbol dibujado en el editor.
- F6: comprar una entrada disponible con `buy` cobra y desbloquea; una bloqueada dice qué falta; sin alcanzar no cambia nada.
- Los efectos se aplican en `unlocked`, y guardar y cargar devuelve lo desbloqueado.
- Nada de monedas, efectos ni red dentro de `addons/unlock_kit`.
