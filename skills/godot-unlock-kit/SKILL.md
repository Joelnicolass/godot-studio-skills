---
name: godot-unlock-kit
description: >-
  Árboles de tecnologías, de talentos o de habilidades en un juego Godot 4 con
  el addon UnlockKit: qué se puede desbloquear ahora, qué necesita qué y cuánto
  cuesta. El árbol se arma en el editor anidando nodos `UnlockEntry` (una
  entrada adentro de otra la necesita; `requires` agrega enlaces cruzados,
  `requires_any` los de «uno de»; `start_unlocked` marca las del principio),
  un `UnlockTreeView` lo dibuja en el editor y en el juego (o instancia una
  escena tuya por entrada), y se compra con una llamada, `buy(id, pay)`.
  Motivos de rechazo (`why_not`, `missing`), deshacer con `lock`, guardar con
  `unlocked_ids` / `restore`, un grafo por jugador con `new_graph`, y un
  `UnlockGraph` de datos puros para las reglas. Usar cuando el usuario quiere
  un árbol de tecnologías, talentos, habilidades, perks, investigación,
  progresión de metajuego, mejoras que se desbloquean o /add-unlocks. No
  conoce la moneda ni aplica los efectos, ni es la red.
---

# Godot — árboles de desbloqueos (UnlockKit)

Addon `addons/unlock_kit/` en el proyecto del **juego**. Referencia: `addons/unlock_kit/README.md`.

Si el addon no está:

```bash
./install.sh --addon /path/to/godot-project unlock_kit
```

Habilitá el plugin **UnlockKit** (tipos `UnlockTree`, `UnlockEntry` y `UnlockTreeView` en Create Node). Pedido acotado: `/add-unlocks`. Composición: [godot-composition-first](../godot-composition-first/SKILL.md).

## Reglas

- **El árbol de escena es el árbol de desbloqueos.** Un `UnlockTree` con `UnlockEntry` adentro: una entrada adentro de otra la necesita (Farming › Irrigation › Aqueduct). Un `Node` común agrupa una rama sin agregar requisitos. `requires` suma entradas de otra rama (enlaces cruzados).
- **Todos y uno de.** Se pide todo lo de `requires` (y el padre); de `requires_any` alcanza una (la rueda o la cerámica). Los dos son datos del inspector, y la vista dibuja «uno de» punteado.
- **Una llamada para comprar.** `tree.buy(id, pay)`: si se puede, llama a la función `pay(cost) -> bool` del juego y, si cobró, desbloquea. `unlock(id)` desbloquea sin costo. Si no se puede, devuelven false y no cambia nada: no es un error.
- **El kit no conoce la moneda.** `cost_of(id)` es un dato `{clave: monto}` y `pay` es del juego. Tampoco aplica efectos: el juego escucha `unlocked`, y los datos del efecto van en un script propio que extiende `UnlockEntry`.
- **Motivos.** `why_not(id)` devuelve un `String`, como un motivo de `can_*` de CommandKit: `""`, `"unknown"`, `"already_unlocked"` o `"locked"`; `missing(id)` dice qué falta. El juego los traduce a sus mensajes.
- **Editor primero.** Costo, título, descripción, icono, `requires`, `requires_any`, `start_unlocked` y `view_position` en el inspector de cada entrada. Un `UnlockTreeView` con `tree` asignado dibuja el árbol en el editor (de izquierda a derecha o de arriba hacia abajo, con la fuente del `Theme` del juego); con `entry_scene`, cada caja es una escena del juego (tema, foco de teclado y mando, arte). Avisos: un id repetido, un requisito de otro árbol, un círculo, una entrada fuera de un árbol, `start_unlocked` debajo de una bloqueada.
- **Un efecto por entrada.** Cada `UnlockEntry` emite sus propias `unlocked` y `locked`: se conectan en el panel Nodo › Señales.
- **Dos niveles.** Con varios jugadores, las reglas guardan `player.unlocks = tree.new_graph()` por jugador (o una instancia del árbol por jugador) y el árbol muestra el activo con `tree.use_graph(player.unlocks)`. `rebuilt` avisa que hay que redibujar todo.
- **Guardar.** `unlocked_ids()` y `restore(ids)`. Ids estables: escribí `id` a mano si se guardan partidas.
- **Ningún kit depende de otro.** UnlockKit no tiene monedas, efectos, red ni autoload: el juego conecta.

## Árbol

```
Level
├── Research (Node)                      # el juego: su pay, los efectos, guardar
├── Tree (UnlockTree)
│   ├── Economy (Node)                   # una rama: no agrega requisitos
│   │   └── Farming (UnlockEntry)        # start_unlocked
│   │       └── Irrigation (UnlockEntry) # cost = {points: 2}
│   ├── Military (Node)
│   │   └── Bronze (UnlockEntry)
│   │       └── Swords (UnlockEntry)     # requires = [Irrigation]: un enlace cruzado
│   └── Trade (UnlockEntry)              # requires_any = [Irrigation, Bronze]: alcanza una
└── Hud
    └── TreeView (UnlockTreeView)        # tree = %Tree; entry_pressed → Research.buy(id)
```

Arrancá desde `addons/unlock_kit/examples/minimal/minimal.tscn`.

## Qué va dónde

| Kit | Juego |
|---|---|
| Qué necesita qué, qué se puede desbloquear ahora, el orden | Qué da cada entrada (sus efectos) |
| El costo como dato (`cost_of`) y el orden de `buy` | La función `pay`: con qué moneda, todo o nada |
| `why_not`, `missing` | Los mensajes al jugador |
| `unlocked`, `locked`, `availability_changed`, `rebuilt` | El HUD, los sonidos, las animaciones |
| `unlocked_ids` / `restore`, `to_dict`, `new_graph` | Dónde se guarda, un grafo por jugador y cómo viaja por la red |

## Con otros kits (el juego conecta)

Ningún kit nombra a otro: estas recetas viven en el código del juego.

**Con WalletKit.** Comprar una tecnología cobra su costo de la billetera, todo o nada, y la desbloquea: `Wallet.pay` ya es un `pay`:

```gdscript
@export var tree: UnlockTree
@export var wallet: Wallet


func buy(id: StringName) -> bool:
	return tree.buy(id, wallet.pay)
```

**Con CommandKit.** Investigar es una jugada con motivo de rechazo y deshacer (devuelve lo cobrado):

```gdscript
func can_research(_seat: int, id: StringName) -> String:
	var why := tree.why_not(id)
	if why != "":
		return why
	return "" if wallet.can_pay(tree.cost_of(id)) else "too_expensive"


func do_research(_seat: int, id: StringName) -> void:
	tree.buy(id, wallet.pay)


func undo_research(_seat: int, id: StringName) -> void:
	tree.lock(id)
	wallet.add(tree.cost_of(id))
```

**Con StatKit.** Un efecto por entrada: al desbloquear, el juego agrega los modificadores con el id de la entrada como `source`, y al bloquear los saca con `remove_source(id)`.

## Listo cuando

- El `UnlockTree` y sus entradas no muestran avisos, y la persona vio el árbol dibujado en el editor por un `UnlockTreeView`.
- F6: un clic en una entrada disponible la compra con `buy`; una bloqueada dice qué falta (también «uno de»); sin alcanzar no cambia nada.
- Guardar y cargar devuelve lo desbloqueado (`unlocked_ids` / `restore`).
- `godot --headless --path unlockkit_lab --script res://addons/unlock_kit/tests/unlock_test_runner.gd` da `UNLOCKKIT TESTS PASS`, y `godot --headless --editor --path unlockkit_lab -- --unlockkit-editor-check` da `UNLOCKKIT EDITOR CHECK PASS` (en el repo del kit).

## Antipatrones

- `can_unlock`, cobrar y `unlock` a mano, en ese orden: usá `buy(id, pay)`, que no se equivoca de orden.
- Los efectos como código en la entrada o un `Dictionary` suelto de datos: el juego escucha `unlocked`, y los datos van en `@export` tipados de un script que extiende `UnlockEntry`.
- Requisitos escritos como texto en el juego, o un `if` con ids para «uno de»: anidá las entradas, usá `requires` o `requires_any`.
- Armar el grafo de cada jugador con `from_dict(tree.to_dict())`: usá `tree.new_graph()`.
- Guardar `tree.graph` en otro lado: cambia cuando el árbol se rearma; leelo cada vez.
- Desbloquear en `_ready` para el estado inicial: usá `start_unlocked`, o `restore` desde una partida guardada.
- Ids que salen del nombre del nodo en un juego que guarda partidas: escribí `id`.
