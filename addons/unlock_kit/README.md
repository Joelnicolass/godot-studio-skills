# <img src="icons/unlock_kit.svg" width="32" height="32" alt=""> UnlockKit

Árboles de tecnologías, de talentos o de habilidades, y la progresión de un metajuego: qué se puede desbloquear ahora, qué necesita qué y cuánto cuesta. Hay tres piezas:

- **`UnlockGraph`**: el árbol como datos puros (`RefCounted`, sin nodos ni escena). Cada entrada tiene un id, los ids que necesita todos, los ids de los que le alcanza uno y un costo. Las reglas de tu juego lo usan directo y se testea headless.
- **`UnlockTree`** y **`UnlockEntry`** (Node): el árbol armado en el editor. Una entrada adentro de otra la necesita, así que el árbol de escena es el árbol de desbloqueos.
- **`UnlockTreeView`** (Control, opcional): dibuja el árbol, también en el editor, y avisa los clics. Con una escena tuya por entrada, toma tu tema, tu foco y tu arte.

UnlockKit **no conoce tu moneda**: el costo es un dato, y `buy(id, pay)` le pide a una función tuya que lo cobre. **No tiene** los efectos de cada entrada (qué da una tecnología), red ni autoload.

## Instalar

```bash
./install.sh --addon /path/to/godot-project unlock_kit
```

Habilitá el plugin **UnlockKit** (tipos `UnlockTree`, `UnlockEntry` y `UnlockTreeView` en Create Node).

## En 3 pasos

1. Agregá un `UnlockTree` y, adentro, un `UnlockEntry` por tecnología. Anidalas: `Irrigation` adentro de `Farming` necesita `Farming`. Un `Node` común agrupa una rama y no agrega requisitos. En el inspector poné el `cost` (por ejemplo `points: 2`) y marcá `start_unlocked` en las que se tienen desde el principio.
2. Si querés verlo, agregá un `UnlockTreeView` y asignale el árbol en `tree`: lo dibuja en el editor mientras lo armás.
3. Comprá con una llamada. `buy` cobra con tu función y desbloquea, solo si se puede desbloquear y tu función cobró:

```gdscript
var points := 5

@onready var tree: UnlockTree = %Tree


func buy(id: StringName) -> bool:
	return tree.buy(id, pay_points)


func pay_points(cost: Dictionary) -> bool:
	var price: int = cost.get(&"points", 0)
	if points < price:
		return false
	points -= price
	return true
```

Tu función recibe el costo (`{clave: monto}`, también vacío si es gratis), cobra todo o nada y devuelve `true` si cobró. Si `id` no se puede desbloquear, ni la llama.

## Ejemplo mínimo

`examples/minimal/minimal.tscn` (F6): nueve tecnologías en tres ramas. `Farming` se tiene desde el principio, `Aqueduct` necesita `Irrigation` (su padre) y `Masonry` (un `requires`), y a `Market` le alcanza con `Pottery` o con `Writing` (su `requires_any`, en línea punteada). Las cajas verdes están desbloqueadas, las doradas se pueden desbloquear y las oscuras todavía no. Un clic en una caja la compra con `tree.buy(id, _pay)` si alcanzan los puntos; el tooltip dice qué falta. **+3 points** suma puntos y **Reset** vuelve al principio. El registro dice qué pasó o por qué no.

```
Minimal              # minimal.gd: guarda los puntos y su _pay; conecta la vista y los botones
├── Box              # Points, los botones +3 points y Reset, %View y el registro
│   └── %View        # UnlockTreeView: tree = %Tree
└── %Tree            # UnlockTree
    ├── Land         # un Node común: agrupa una rama
    │   └── Farming          # start_unlocked
    │       ├── Irrigation   # 2 points
    │       │   └── Aqueduct # 4 points, requires = [Masonry]; su señal unlocked va a minimal.gd
    │       └── Pottery      # 1 point
    ├── Stone
    │   └── Masonry          # 2 points
    │       └── Walls        # 3 points
    ├── Lore
    │   └── Writing          # 2 points
    │       └── Library      # 3 points
    └── Market               # 3 points, requires_any = [Pottery, Writing]
```

## Cómo funciona

- **Entradas.** Cada una tiene un id (`StringName`), los ids que necesita y un costo `{clave: monto}`. En el árbol, el id es `id` o, si está vacío, el nombre del nodo. Lo que muestra una vista es `title` o, si está vacío, el id.
- **Requisitos: todos.** Una entrada necesita **todos** estos: su entrada padre (la `UnlockEntry` más cercana hacia arriba) y cada una de `requires`.
- **Requisitos: uno de.** Si tiene `requires_any`, además le alcanza con que **una** de esas esté desbloqueada (la rueda o la cerámica). La vista dibuja esos enlaces punteados.
- **Preguntar.** `can_unlock(id)` dice si se puede. `why_not(id)` dice por qué no, como el motivo de rechazo de una jugada: `""` (se puede), `"unknown"` (no es una entrada), `"already_unlocked"` o `"locked"` (falta un requisito). `missing(id)` dice qué falta: los de `requires` que no están y, si no hay ninguno de `requires_any`, todos esos (alcanza con uno). Traducilos a los mensajes de tu juego.
- **Comprar.** `buy(id, pay)` hace todo en orden: si se puede desbloquear, llama `pay` con el costo; si `pay` devuelve `true`, desbloquea. Si no se puede, ni cobra. Si `pay` devuelve otra cosa, no desbloquea.
- **Desbloquear sin costo.** `unlock(id)` desbloquea si `can_unlock(id)`. Si no, devuelve false y no cambia nada: no es un error, es una jugada normal. Sirve para regalos, trucos o reglas que cobran de otra forma.
- **Deshacer.** `lock(id)` vuelve a bloquear. Devuelve false si no estaba desbloqueada o si otra desbloqueada la necesita (la tiene en `requires`, o es la única desbloqueada de su `requires_any`): deshacé desde la punta.
- **Señales.** `unlock` y `buy` emiten `unlocked(id)` y después `availability_changed` (cambió lo que se puede desbloquear). Cada `UnlockEntry` emite también sus propias `unlocked` y `locked`, así conectás un efecto por entrada desde el panel Nodo › Señales. `restore` no emite `unlocked` ni `locked`: emite una sola `availability_changed` (releé todo).
- **El árbol se rearma solo.** Cambiar un valor del inspector, agregar, mover, renombrar o sacar una entrada rearma el grafo una vez por cuadro (o antes, si alguien lo lee), conserva lo desbloqueado y emite `rebuilt`. Si se va el árbol entero (al cerrar la escena), no se rearma. Es un objeto nuevo: no guardes `tree.graph`, leelo cada vez. En el editor el árbol muestra siempre el principio (solo lo `start_unlocked`).
- **Columnas.** `depth(id)` es la cadena más larga de requisitos debajo de una entrada (de los dos tipos): 0 sin requisitos, si no 1 más que su requisito más profundo. La vista pone una columna por profundidad, de izquierda a derecha, y en cada columna las entradas en el orden del árbol. Con `direction = TOP_TO_BOTTOM`, una fila por profundidad, de arriba hacia abajo, y en cada fila las entradas de izquierda a derecha; las curvas siguen la dirección. Una entrada con `view_position` va ahí, en píxeles, y no ocupa lugar.
- **Problemas.** Un requisito que no es una entrada, una entrada que se necesita a sí misma, o entradas que se necesitan en círculo: `problems()` los describe en palabras y el editor los muestra como avisos.
- **Guardar.** Guardá `unlocked_ids()` (o `to_dict(false)`) y, al cargar, llamá `restore(ids)` (no revisa el orden). `to_dict()` y `UnlockGraph.from_dict()` guardan también las entradas, para un grafo que arman tus reglas. Son datos planos y sobreviven a JSON.

### Un grafo por jugador

`tree.new_graph()` arma un grafo nuevo con las entradas del árbol, con las `start_unlocked` desbloqueadas. Guardá uno por jugador en tus reglas y mostrá el del jugador activo con `use_graph`. Al empezar la partida, cada jugador recibe el suyo y la vista muestra el del primero:

```gdscript
func start_match(players: Array[Player]) -> void:
	for player in players:
		player.unlocks = tree.new_graph()
	tree.use_graph(players[0].unlocks)
```

Las entradas siguen dando títulos, iconos y descripciones a la vista, por id; un id del grafo sin entrada es un aviso. Otra forma: instanciá la escena del árbol una vez por jugador, y cada instancia tiene su grafo.

## Entradas con datos propios

Lo que da una entrada en tu juego va en tu propio script, que extiende `UnlockEntry` con campos tipados, nunca con un `Dictionary` suelto. Empezá con `@tool`, así el editor sigue rearmando el árbol al cambiarla. Esta tecnología suma comida por turno:

```gdscript
@tool
class_name TechEntry
extends UnlockEntry

## Food per turn this tech gives once unlocked.
@export var food_per_turn := 0
```

Las reglas preguntan el tipo y leen los campos. Esta tecnología desbloqueada suma su comida:

```gdscript
func _on_tree_unlocked(id: StringName) -> void:
	var tech := tree.entry(id) as TechEntry
	if tech != null:
		food_per_turn += tech.food_per_turn
```

El inspector muestra los campos nuevos, y `UnlockTree` y `UnlockTreeView` las tratan como a cualquier `UnlockEntry`.

## API

### `UnlockGraph` (RefCounted)

| Miembro | Qué hace |
| --- | --- |
| `UnlockGraph.new()` | Un grafo vacío |
| `add(id, needs = [], cost = {}, needs_any = []) -> bool` | Define una entrada: `needs` se piden todos y de `needs_any` alcanza uno. Pueden nombrar ids que se agregan después. Un id vacío o repetido es un error y no agrega (false); un monto negativo es un error y esa clave queda afuera |
| `has(id)`, `ids()` | Si existe, y todas en el orden en que se agregaron |
| `requires(id)`, `requires_any(id)` | Lo que necesita todo, y aquello de lo que le alcanza uno |
| `cost_of(id) -> Dictionary` | Una copia del costo, `{clave: monto}` (`{}` si es gratis) |
| `is_unlocked(id)`, `can_unlock(id)`, `why_not(id) -> String`, `missing(id)` | Preguntar |
| `buy(id, pay: Callable) -> bool` | Si se puede, llama `pay(cost_of(id))` y, si devuelve `true`, desbloquea |
| `unlock(id) -> bool`, `lock(id) -> bool` | Desbloquear sin costo y deshacer. Si no se puede, false y nada cambia |
| `unlocked_ids()`, `available_ids()` | Las desbloqueadas (en el orden en que se desbloquearon) y las que se pueden desbloquear ahora (en el orden en que se agregaron) |
| `depth(id) -> int` | La cadena más larga de requisitos debajo (0 sin requisitos) |
| `restore(saved_ids)` | Desbloquea exactamente esas (una partida guardada); `restore([])` bloquea todo. Sin `unlocked` ni `locked`; una `availability_changed`. Un id desconocido es un error y se saltea |
| `problems() -> PackedStringArray` | Requisitos que no son entradas, entradas que se necesitan a sí mismas y círculos, en palabras |
| `to_dict(with_entries = true)` / `UnlockGraph.from_dict(data)` | `{"entries": [{"id", "requires", "requires_any", "cost"}], "unlocked": [...]}`; con `false`, solo `{"unlocked": [...]}` |
| señales `unlocked(id)`, `locked(id)`, `availability_changed` | En pasado: ya ocurrió |

### `UnlockEntry` (Node)

- **Inspector:** `id` (vacío: el nombre del nodo), `title` (vacío: el id), `description`, `icon`, `cost` (`{clave: monto}`), `requires` (más entradas del mismo árbol que necesita todas, además de su padre), `requires_any` (entradas del mismo árbol de las que le alcanza una), `start_unlocked` (desbloqueada al armar el grafo y en `reset`, gratis) y `view_position` (dónde va su caja en la vista; (0, 0) es la columna automática).
- **Señales:** `unlocked` y `locked`, emitidas por su árbol.
- **Métodos:** `entry_id()` (el id que usa el grafo) e `is_unlocked()`.
- **Avisos del editor:** fuera de un `UnlockTree`; un lugar vacío en `requires` o `requires_any`, o un nodo que no es una entrada o es de otro árbol; un monto negativo; un id repetido (en la que queda afuera: cuenta la primera); un círculo; y `start_unlocked` en una entrada cuyo padre o `requires` no empiezan desbloqueados, o sin ninguna de `requires_any` que empiece desbloqueada.

### `UnlockTree` (Node)

- **Grafo:** `graph` es el `UnlockGraph` que muestra. `new_graph()` arma uno nuevo desde las entradas (uno por jugador), `use_graph(graph)` muestra el de tus reglas y `use_own_graph()` vuelve al de las entradas, desde el principio.
- **Métodos:** los mismos de `UnlockGraph` (`buy`, `can_unlock`, `why_not`, `unlock`, `lock`, `cost_of`, `is_unlocked`, `unlocked_ids`, `available_ids`, `missing`, `requires`, `requires_any`, `restore`, `to_dict`), más `reset()` (vuelve al principio: en su propio grafo, con las `start_unlocked` desbloqueadas; en uno de `use_graph`, todo bloqueado), `entry(id) -> UnlockEntry` (null si no hay), `entries()` (en el orden del árbol) y `title_of(id)` (el `title` de su entrada, o el id).
- **Señales:** `unlocked(id)`, `locked(id)`, `availability_changed` y `rebuilt` (muestra otro grafo o cambiaron sus entradas: releé todo).
- **Avisos del editor:** sin entradas, y los `problems()` del grafo.

### `UnlockTreeView` (Control)

- **Inspector:** `tree` y `entry_scene`; en **Layout**, `direction` (`LEFT_TO_RIGHT` o `TOP_TO_BOTTOM`), `box_size`, `gap` (el espacio entre cajas: x a lo ancho, y a lo alto), `font_size` y `corner_radius`; en **Colors**, `unlocked_color`, `available_color`, `locked_color`, `line_color` y `text_color`.
- **Dibujo:** una caja por entrada con su icono, su título y su costo («2 points»), en el color de su estado y con esquinas de `corner_radius`, y una curva de cada requisito a la entrada (punteada para `requires_any`). La fuente sale del tema del juego: la fuente de `Label` de un `Theme` en la vista o en un ancestro, o su `default_font`, o la del proyecto; `font_size` decide el tamaño.
- **Foco:** las cajas dibujadas responden solo al mouse. Para el foco de teclado y de mando, usá `entry_scene` con un `Button`. Su tamaño mínimo es el del árbol: ponela adentro de un `ScrollContainer` si el árbol es grande. Se redibuja sola con las señales del árbol.
- **Una escena por entrada:** con `entry_scene`, la vista instancia tu escena una vez por entrada en lugar de dibujar la caja, y sigue dibujando las curvas. El contrato:
  - la raíz es un `Control` y su script declara `var entry_id: StringName` y `var tree: UnlockTree`;
  - la vista asigna los dos antes de que entre al árbol de escena, y la ubica sobre la caja de su entrada (posición y tamaño `box_size`);
  - la escena lee su estado de `tree` y escucha sus señales (`unlocked`, `locked`, `availability_changed`, `rebuilt`);
  - si la raíz es un `BaseButton`, su `pressed` sale como `entry_pressed` (también con teclado y mando); con cualquier raíz, el puntero sale como `entry_hovered`.
  Así la caja toma el `Theme` del juego y el foco. Sin `entry_scene`, la vista dibuja las cajas.
- **Tooltip:** título, descripción, costo y lo que falta («Needs: …», «Needs one of: …», o «Unlocked»). Los textos pasan por `tr()`.
- **Señales:** `entry_pressed(id)` (clic izquierdo en una caja) y `entry_hovered(id)` (`&""` cuando sale). La vista nunca desbloquea: lo decide tu juego.
- **Métodos:** `entry_at(point) -> StringName` y `box_rect(id) -> Rect2`.

## Querés → escribí

| Querés | Escribí |
|---|---|
| Que una tecnología necesite otra | Poné su `UnlockEntry` adentro de la otra |
| Que necesite una de otra rama | Agregá la otra a su `requires` |
| Que le alcance con una de varias | Poné esas en su `requires_any` |
| Agrupar una rama sin agregar requisitos | Un `Node` común entre el árbol y las entradas |
| Una tecnología con la que se empieza | `start_unlocked` en su entrada |
| Comprar | `tree.buy(id, pay)`: tu `pay(cost) -> bool` cobra todo o nada |
| Decirle al jugador por qué no | `tree.why_not(id)` y `tree.missing(id)` |
| Un efecto cuando se desbloquea una entrada | Conectá su señal `unlocked` en el panel Nodo |
| Un efecto para cualquier entrada | `tree.unlocked.connect(func(id): ...)` |
| Datos del efecto en la entrada | Un script `@tool` que `extends UnlockEntry` con `@export` tipados ([arriba](#entradas-con-datos-propios)) |
| Deshacer | `tree.lock(id)` y devolvé lo que cobraste |
| Las entradas sin requisitos | `tree.requires(id).is_empty() and tree.requires_any(id).is_empty()` |
| Guardar y cargar | `save["unlocks"] = tree.unlocked_ids()` y después `tree.restore(save["unlocks"])` |
| Un grafo por jugador | `player.unlocks = tree.new_graph()` y `tree.use_graph(player.unlocks)` |
| Un árbol armado por código | `var graph := UnlockGraph.new()` y `graph.add(&"irrigation", [&"farming"], {&"points": 2})` |
| Volver al principio | `tree.reset()` |
| Ver el árbol | Un `UnlockTreeView` con `tree` asignado |
| Mover una caja | `view_position` en su entrada |
| Un árbol de arriba hacia abajo | `direction = TOP_TO_BOTTOM` en la vista |
| La fuente del juego en las cajas | Un `Theme` en la vista o en un ancestro (su fuente de `Label` o su `default_font`) |
| Navegar el árbol con teclado o mando | `entry_scene` con raíz `Button` |
| Cajas con tu tema, foco y arte | Una escena con raíz `Button` en `entry_scene` (ver el contrato arriba) |

## Tips

- **Ids estables.** Si guardás partidas, escribí el `id` a mano: renombrar el nodo cambia el id que sale de su nombre.
- **Las reglas usan el grafo, no los nodos.** En un juego con varios jugadores, guardá el `new_graph()` de cada uno en el estado de la partida y mostrá el del jugador activo con `tree.use_graph()`. La vista escucha `rebuilt` y se redibuja.
- **Los costos son tuyos.** El kit no sabe qué es `points`: puede ser una moneda, una ficha o experiencia. Tu `pay` lo cobra como cobre tu juego.
- **Un árbol grande** entra en un `ScrollContainer`: la vista pide su tamaño mínimo.

## Tests

```bash
godot --headless --path unlockkit_lab --script res://addons/unlock_kit/tests/unlock_test_runner.gd
```

Sale `UNLOCKKIT TESTS PASS (n)`. Los tests cubren:

- El grafo: entradas, requisitos que se agregan después, «todos» y «uno de», `why_not` y `missing`, `buy` (cuándo llama a `pay` y qué hace con lo que devuelve), `unlock` y `lock` con sus señales, `availability_changed` una vez por llamada, `depth`, `restore`, los problemas (requisito desconocido, círculos, también por `requires_any`) y `to_dict` (también tras JSON y sin las entradas).
- Los nodos: el grafo desde entradas anidadas (un `Node` común no agrega requisitos), `requires_any`, `buy`, un costo cambiado en el juego, las señales por entrada, los cambios en vivo que conservan lo desbloqueado (un rearmado por cuadro, ninguno si se va el árbol entero), `new_graph` por jugador, `use_graph` y su aviso, una instancia por jugador, `reset`, una entrada con datos propios y los avisos del editor (también `start_unlocked` debajo de una bloqueada).
- La vista: columnas por profundidad (o filas, de arriba hacia abajo), `view_position`, `corner_radius` y la fuente del tema, el tamaño mínimo, clics, hover, tooltips (también «uno de»), `entry_scene` y que se redibuje con el árbol.
- El ejemplo jugado con clics en las cajas y los botones, y la escena lista sin correrla (lo que muestra el editor).
- Que el addon no nombre a ningún otro kit.

El lab tiene además un chequeo dentro del editor real: ver `unlockkit_lab/README.md`.
