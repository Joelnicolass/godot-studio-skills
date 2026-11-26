# <img src="icons/deck_kit.svg" width="32" height="32" alt=""> DeckKit

Cartas para deckbuilders, solitarios, juegos de cartas o de mesa y mazos de eventos. Responde «qué cartas hay dónde»: el mazo, la mano, el descarte, la mesa. Hay dos niveles:

- **`CardStack`**: una pila de cartas en orden, como datos puros (`RefCounted`, sin nodos ni escena). Roba, mueve entre pilas, mezcla con tu `RandomNumberGenerator`, rellena el mazo con el descarte y se guarda con `to_dict`. Las reglas de tu juego lo usan directo y se testea headless.
- **Para la escena**:
  - `CardData` (Resource): una carta, con `id`, título, texto, arte y tags. Un `.tres` por carta.
  - `CardPile` (Node): arma o muestra un `CardStack` con las cartas del inspector. Una mano, un descarte, la mesa.
  - `Deck` (un `CardPile`): el mazo del que se roba. Tiene su propio generador con semilla (o usa el de tu partida) y se mezcla al empezar.
  - `HandView` (Control, opcional): muestra una pila en fila o en abanico, también en el editor. Dibuja cada carta, o instancia tu escena por carta (`card_scene`). Se juega con el mouse, el teclado o el mando, y las cartas se pueden arrastrar entre vistas (`drag_cards`).

DeckKit **no tiene** reglas de juego, costos, turnos, red ni autoload. Qué hace una carta, cuándo se roba y cuánto se roba lo decide tu juego. Tampoco tiene:

- **Estado por copia:** las copias de una carta son la misma `CardData`. Una carta mejorada, girada o con un contador es otra `CardData` (con su propio `id`) o un dato de tu juego al lado de la pila.
- **Cara por carta:** `face_up` es de la pila entera. Un solitario con cartas boca arriba y boca abajo en la misma columna usa dos pilas (las tapadas y las destapadas) o lleva esa cuenta en el juego.

## Instalar

```bash
./install.sh --addon /path/to/godot-project deck_kit
```

Habilitá el plugin **DeckKit** (tipos `CardPile`, `Deck` y `HandView` en Create Node; `CardData` en New Resource).

## En 3 pasos

1. Creá tus cartas: en el FileSystem, New Resource › `CardData`, con `id`, `title`, `text`, `art` y `tags`. Un archivo por carta (`strike_card.tres`). Para tener copias, arrastrá la misma carta varias veces.
2. Agregá un `Deck` con las cartas en `start_cards` (la primera queda arriba), `face_up` apagado y un `rng_seed`. Agregá un `CardPile` para la mano (`max_size` 5) y otro para el descarte. Un `HandView` muestra la pila de su `pile`, también en el editor: apuntalo al mazo y ves sus cartas sin correr el juego.
3. Jugá. Robar del mazo a la mano, descartar la carta que se clickea (por su índice, así sale la copia que tocaste) y devolver el descarte al mazo, mezclado:

```gdscript
@onready var deck: Deck = %Deck
@onready var hand: CardPile = %Hand
@onready var discard: CardPile = %Discard
@onready var hand_view: HandView = %HandView


func _ready() -> void:
	hand_view.card_pressed.connect(func(_card: CardData, index: int) -> void: hand.move_at(index, discard))


func draw_one() -> void:
	if deck.is_empty():
		deck.refill_from(discard)
	deck.draw_to(hand)
```

## Ejemplo mínimo

`examples/minimal/minimal.tscn` (F6): un mazo de 12 cartas (10 distintas: Coin tres veces, y 3 con el tag `event`), una mano de 5 y un descarte. **Draw** roba la carta de arriba a la mano; clickear una carta de la mano (o elegirla con las flechas y Enter) descarta esa carta, aunque haya otra igual; arrastrarla al descarte también, arrastrarla dentro de la mano la cambia de lugar y arrastrarla desde el descarte la devuelve. **Refill** pone el descarte debajo del mazo y lo mezcla. **Seed** reparte de nuevo con esa semilla: la misma semilla da siempre el mismo orden. La mano muestra cada carta con la escena `card_face.tscn`, y las cartas se deslizan a su lugar. Los contadores dicen cuántas hay en cada pila y cuántos eventos quedan en el mazo, y el registro dice qué pasó. En el editor, `DeckView` muestra la cara de arriba del mazo; subile el `spread` para ver las 12.

```
Minimal                  # minimal.gd: contadores, botones y registro
├── Box
│   ├── Counts, Buttons  # Draw, Refill, Seed
│   ├── Table
│   │   ├── DeckView     # HandView del mazo (spread 3: una pila de dorsos), keyboard apagado
│   │   └── %DiscardView # HandView del descarte, drag_cards
│   ├── %HandView        # HandView de la mano: card_scene = card_face.tscn, abanico de 12°, drag_cards
│   └── Log
├── %Deck                # 12 CardData de cards/, rng_seed 1, face_up apagado
├── %Hand                # CardPile, max_size 5
└── %Discard             # CardPile
```

## Cómo funciona

- **Arriba es el índice 0.** `cards()` y `top()` van de arriba hacia abajo. `add(card)` pone arriba; `add(card, -1)`, abajo.
- **Copias:** la misma `CardData` puede estar varias veces en una pila, y se distinguen por el índice. `move_at(index, to)` y `remove_at(index)` usan esa carta justa. `move(card, to)` y `remove(card)` son atajos que toman la primera copia desde arriba: sirven cuando no hay copias o da igual cuál sale. El `HandView` da el índice de la carta que se clickea.
- **Mover:**
  - `draw_to(pile, n)` saca hasta `n` cartas de arriba y pone cada una arriba de `pile`, así que la última robada queda arriba (en un `HandView`, a la derecha). Devuelve las cartas en el orden en que salieron.
  - `move_at(index, to, to_index)` mueve una carta cualquiera. `to` puede ser la misma pila: así se manda una carta al fondo.
  - `refill_from(other, rng)` pone todas las cartas de `other` debajo, en su orden, y con un `rng` mezcla la pila.
- **Tope:** `max_size` (-1 = sin tope). Si no entran todas, se mueve lo que entra y el resto queda donde estaba. Bajar el tope en el juego no saca cartas: solo frena las que entran. En el editor, el `CardPile` arma la pila de nuevo con las que entran.
- **Señales:** todas salen del `CardStack`. Un movimiento emite `removed(cards, to)` en la pila de origen y después `added(cards, from)` en la de destino. `to` y `from` son null cuando las cartas vienen de la nada o se sacan (`add`, `remove`, `take`, `clear`). Un `CardPile` nombra la otra punta como el `CardPile` que muestra esa pila (`CardPile.showing(stack)`), también si el movimiento lo hicieron tus reglas sobre el `CardStack`. Para saber qué se robó, escuchá `added` en la mano.
- **Mezclar:** `shuffle(rng)` pide siempre un `RandomNumberGenerator` tuyo (Fisher–Yates con `rng.randi_range`). Misma semilla, mismo orden. El kit nunca usa el azar global (`randi()`, `randomize()`, `Array.shuffle()`, `pick_random()`), y un test lo cuida.
- **El `Deck`:**
  - Su `rng` sale de `rng_seed`. Con `rng_seed` 0 cada arranque usa una semilla propia, distinta para cada mazo.
  - Para usar el generador de la partida, asignalo: `deck.rng = match_rng`. Desde ahí `rng_seed` y `reset()` no lo tocan; `deck.rng = null` vuelve al propio.
  - Se mezcla al empezar el juego (`shuffle_at_start`) cuando la escena ya está lista, al final de ese cuadro. Así el `_ready` de un padre puede darle `rng` antes, sin `reset()`. Si el padre roba en su `_ready`, el mazo se mezcla justo antes de ese primer `draw_to`. En el editor queda en el orden del inspector.
  - `deck.shuffle()` y `deck.refill_from(discard)` usan su `rng` si no les pasás otro, así que el refill siempre mezcla.
  - `reset()` vuelve a las cartas de inicio y mezcla con el generador propio desde el principio. Las otras pilas no se tocan: vacialas vos.
  - `face_up` empieza encendido como en cualquier pila: apagalo en el inspector del mazo.
- **Errores:** robar o mover a null o a la misma pila (salvo `move_at`), un índice fuera de la pila, mezclar sin `rng`, agregar una carta null: error y no cambia nada. Mover a una pila llena o una carta que no está devuelve `false` sin error: es juego normal.
- **Guardar:** `to_dict()` da `{"cards": [ids, de arriba hacia abajo], "max_size": n}`, listo para JSON. `CardStack.from_dict(data, catalog)` busca cada id en tu lista de cartas. Un id que no está es un error y se saltea. Toda carta que se guarda necesita su `id`. Para que después de cargar el mazo mezcle igual que en la partida guardada, guardá también `deck.rng.seed` y `deck.rng.state`, y al cargar ponelos en ese orden (primero la semilla, después el estado).

## Cartas con datos propios

Una carta que lleva números del juego extiende `CardData` con campos tipados, nunca con un `Dictionary` suelto. Esta carta de evento suma comida y dura unos turnos:

```gdscript
class_name EventCard
extends CardData

## Food the event gives (negative: it takes food).
@export var food := 0
## Turns the event lasts.
@export_range(1, 10) var turns := 1
```

Las reglas preguntan el tipo y leen los campos. Cada evento que llega a la mano desde el mazo suma su comida, robe el nodo o roben tus reglas:

```gdscript
func _ready() -> void:
	hand.added.connect(_on_hand_added)


func _on_hand_added(cards: Array[CardData], from: CardPile) -> void:
	if from != deck:
		return
	for card in cards:
		var event := card as EventCard
		if event != null:
			food += event.food
```

El inspector muestra los campos nuevos, y `CardPile`, `Deck` y `HandView` las tratan como a cualquier `CardData`. Para mostrarlos en la mano, una `card_scene` propia.

## El diseño de la carta: `card_scene`

Sin `card_scene`, el `HandView` dibuja cada carta (título, arte o texto, tags) con sus colores. Para un marco, un costo en una esquina o los campos de tu tipo de carta, hacé una escena y ponela en `card_scene`. Esta carta muestra su título y su texto:

```gdscript
@tool
extends PanelContainer

## The card to show. HandView sets it.
var card: CardData:
	set(value):
		card = value
		if is_node_ready():
			_show()

@onready var _title: Label = %Title
@onready var _text: Label = %Text


func _ready() -> void:
	_show()


func _show() -> void:
	if card != null:
		_title.text = card.title
		_text.text = card.text
```

- La raíz es un `Control` y su script declara `var card: CardData`. El `HandView` hace una por carta, le pone `card`, la lleva a `card_size` y la ubica y la gira. Con `@tool`, se ve en el editor.
- El mouse lo maneja el `HandView`: la escena no recibe clics (queda en `MOUSE_FILTER_IGNORE`), y `card_pressed` y `card_hovered` andan igual.
- Una pila boca abajo no muestra la escena: el `HandView` dibuja el dorso (`back`).
- El ejemplo usa `examples/minimal/card_face.tscn`.

## Teclado, mando y arrastrar

- **Teclado y mando:** con `keyboard` (encendido por defecto), el `HandView` toma el foco (`focus_mode` All). `ui_left` y `ui_right` (flechas, cruceta del mando) eligen una carta, que se levanta como con el mouse y emite `card_hovered(card, index)`; `ui_accept` (Enter, Espacio, el botón A) emite `card_pressed(card, index)`. En una punta la flecha sigue de largo, así el foco pasa al control de al lado.
- **Clic:** `card_pressed` sale al soltar el botón sobre la misma carta que se apretó, como un `Button`. Así un arrastre no es un clic.
- **Arrastrar:** con `drag_cards` encendido en las dos vistas, una carta se arrastra a otra vista (o a otro lugar de la misma, para ordenar). La vista donde cae emite `card_dropped(card, from_index, from, to_index)`. El kit no mueve nada: lo decide tu juego. Una vista con `drag_cards` apagado no deja arrastrar ni recibe.

Cada carta que cae en esta vista se mueve desde la vista de la que vino, al lugar donde cayó:

```gdscript
@onready var table_view: HandView = %TableView


func _ready() -> void:
	table_view.card_dropped.connect(_on_card_dropped)


func _on_card_dropped(_card: CardData, from_index: int, from: HandView, to_index: int) -> void:
	from.pile.move_at(from_index, table_view.pile, to_index)
```

- `to_index` ya cuenta la carta como ida cuando las dos vistas muestran la misma pila, así `move_at` la deja donde cayó también al ordenar.
- Mientras se arrastra, sigue al puntero la carta como la dibuja la vista, o una instancia de `card_scene` (`drag_preview(index)`).
- Un nodo propio que recibe cartas (una casilla del tablero) lee `data is HandView.CardDrag` en su `_can_drop_data`: trae `card`, `index` y `from`.

## API

### `CardData` (Resource)

| Miembro | Qué hace |
| --- | --- |
| `id: StringName` | Cómo la encuentran `to_dict` y `from_dict`. Único en tu juego |
| `title: String` | El nombre en la carta (vacío: los views muestran el `id`) |
| `text: String` | Lo que dice la carta. Sin `art`, el `HandView` lo dibuja en su lugar |
| `art: Texture2D` | El dibujo |
| `tags: Array[StringName]` | Clases de carta (`event`, `attack`) |
| `has_tag(tag) -> bool` | Si tiene ese tag |

### `CardStack` (RefCounted)

| Miembro | Qué hace |
| --- | --- |
| `CardStack.new(start = [], max_size = -1)` | Una pila con `start` (de arriba hacia abajo) y un tope |
| `max_size` | El tope (-1 = sin tope) |
| `cards()`, `size()`, `is_empty()`, `has(card)` | Lo que hay. `cards()` es una copia |
| `top(n = 1)`, `find_id(id)`, `count_tag(tag)` | Mirar sin sacar: las de arriba, una por id, cuántas con un tag |
| `add(card, index = 0) -> bool` | Agrega desde la nada (`-1` = abajo). `false` si está llena |
| `remove_at(index) -> CardData`, `remove(card) -> bool` | Saca una carta hacia la nada: la de ese índice, o la primera copia |
| `take(n = 1)`, `clear()` | Saca hacia la nada las de arriba, o todas |
| `draw_to(pile, n = 1) -> Array[CardData]` | Roba hasta `n` de arriba a `pile` |
| `move_at(index, to, to_index = 0) -> bool`, `move(card, to, index = 0) -> bool` | Mueve una carta a otra pila (o dentro de la misma): la de ese índice, o la primera copia |
| `shuffle(rng)` | Mezcla con tu generador |
| `refill_from(other, rng = null) -> Array[CardData]` | Todas las de `other` abajo; con `rng`, mezcla |
| `to_dict()` / `CardStack.from_dict(data, catalog)` | Datos planos para guardar, mandar por red o comparar |
| señales `added(cards, from)`, `removed(cards, to)`, `shuffled` | En pasado: ya ocurrió |

### `CardPile` (Node)

- **Inspector:** `start_cards` (de arriba hacia abajo), `max_size` y `face_up`. Cambiar `start_cards` arma la pila de nuevo; cambiar `face_up` emite `flipped`. Nunca toca una pila de `use_stack`.
- **Avisos del editor:** un lugar vacío en `start_cards`, una carta sin `id`, dos cartas distintas con el mismo `id` y más cartas que `max_size`.
- **Pila:** `stack` es el `CardStack` que muestra. `use_stack(stack)` muestra el de tus reglas y `use_own_stack()` vuelve al del inspector. `CardPile.showing(stack)` dice qué pila lo muestra (la última que empezó a mostrarlo; null si ninguna).
- **Métodos:** los mismos de `CardStack` (`cards`, `size`, `is_empty`, `top`, `has`, `find_id`, `count_tag`, `add`, `remove_at`, `remove`, `take`, `clear`, `to_dict`), con otro `CardPile` donde va la otra pila: `draw_to(pile, n)`, `move_at(index, to, to_index)`, `move(card, to, index)`, `refill_from(other, rng)`. `shuffle(rng)` necesita un generador (el `Deck` usa el suyo).
- **Señales:** `added(cards, from)`, `removed(cards, to)` y `shuffled`, con la otra punta como `CardPile` (null si ninguna la muestra); `rebuilt` cuando el nodo pasa a mostrar otra pila (al recibirla, volvé a leer todas las cartas), y `flipped(face_up)`.
- **Guardar:** `to_dict()`, y para cargar, `pile.use_stack(CardStack.from_dict(data, catalog))`.

### `Deck` (extiende `CardPile`)

| Miembro | Qué hace |
| --- | --- |
| `rng_seed` | La semilla de su generador propio. 0: una propia en cada arranque. Cambiarla rearma solo el propio |
| `shuffle_at_start` | Mezclar al empezar el juego (con la escena lista) y en `reset()` |
| `rng` | El generador que usa. Asigná el de la partida para compartirlo; `null` vuelve al propio |
| `draw_to(pile, n = 1)` | Como en `CardPile`; si la mezcla del arranque todavía no pasó, pasa antes |
| `shuffle(rng = null)`, `refill_from(pile, rng = null)` | Sin `rng`, usan el del mazo |
| `reset()` | Las cartas de inicio otra vez, mezcladas si `shuffle_at_start` |

### `HandView` (Control)

- **Inspector:** `pile` y `card_scene`; en Layout, `card_size`, `spread` (de un borde izquierdo al siguiente, se achica para que la fila entre en el ancho), `fan_degrees` (0 = fila recta), `hover_lift` y `settle_time` (cuánto tarda una carta en deslizarse a su lugar; 0 = salta); en Input, `keyboard` y `drag_cards`; en Look, `back` (el dorso; vacío, un dorso liso de `back_color`), `faces_in_editor`, `card_color`, `back_color`, `border_color`, `text_color` y `font_size`.
- **Cómo muestra:** el fondo de la pila a la izquierda y la de arriba a la derecha, así la última carta robada a una mano queda a la derecha. Sin `card_scene`, cada carta es un panel redondeado con el título, el arte (o el texto si no tiene arte) y los tags; con `card_scene`, una instancia de tu escena. Una pila boca abajo muestra dorsos; en el editor, con `faces_in_editor`, muestra las caras para que revises las cartas. Cuando cambia la pila, cada carta se desliza a su lugar (con copias, la que se queda es la que estaba más cerca); la carta bajo el puntero se levanta.
- **Señales:** `card_pressed(card, index)` (clic izquierdo, o `ui_accept`), `card_hovered(card, index)` (el puntero o las flechas; null y -1 al salir) y `card_dropped(card, from_index, from, to_index)` (una carta arrastrada cayó en esta vista). `index` es el de la pila (0 = arriba): pasáselo a `move_at`.
- **Métodos:** `card_index_at(position) -> int` (-1 si no hay carta), `card_at(position) -> CardData` (la de encima si se pisan), `card_rect(index) -> Rect2` (donde va la carta, antes del giro del abanico y del hover), `drop_index(position, drag = null) -> int` (dónde caería una carta) y `drag_preview(index) -> Control` (lo que sigue al puntero al arrastrar).
- **`HandView.CardDrag`:** lo que lleva un arrastre: `card`, `index` y `from` (la vista de origen).
- **Avisos del editor:** sin `pile`; una `card_scene` cuya raíz no es un `Control` o no declara `card`.

## Querés → escribí

| Querés | Escribí |
|---|---|
| Robar 5 al empezar el turno | `deck.draw_to(hand, 5)` |
| Robar, y si el mazo se vació, rellenarlo | `if deck.is_empty(): deck.refill_from(discard)` y después `deck.draw_to(hand)` |
| Descartar la carta clickeada | `hand_view.card_pressed.connect(func(_card, index): hand.move_at(index, discard))` |
| Descartar arrastrando | `drag_cards` en las dos vistas y `discard_view.card_dropped.connect(func(_card, i, from, _to): from.pile.move_at(i, discard, 0))` |
| Ordenar la mano arrastrando | `drag_cards` en su vista y `hand_view.card_dropped.connect(func(_card, i, from, to): from.pile.move_at(i, hand, to))` |
| Jugar con teclado o mando | Nada: `keyboard` viene encendido (flechas, Enter, la cruceta y A) |
| Soltar cartas en un nodo propio | `func _can_drop_data(_at, data): return data is HandView.CardDrag` |
| Descartar toda la mano | `hand.draw_to(discard, hand.size())` |
| Mandar la carta de arriba al fondo del mazo | `deck.move_at(0, deck, -1)` |
| Mirar las 3 de arriba sin robar | `deck.top(3)` |
| Saber qué se robó | `hand.added.connect(func(cards, from): if from == deck: ...)` |
| Saber si quedan eventos en el mazo | `deck.count_tag(&"event")` |
| Una mano de 7 | `max_size` 7 en el `CardPile` de la mano |
| Tres copias de una carta | La misma `CardData` tres veces en `start_cards` |
| Siempre el mismo orden (tests, desafío diario) | `rng_seed` distinto de 0 en el `Deck` |
| El generador de la partida | `deck.rng = match_rng` (en el `_ready` del padre alcanza) |
| Guardar y seguir la misma secuencia | Guardá `deck.rng.seed` y `deck.rng.state`; al cargar, ponelos en ese orden |
| Repartir de nuevo | `hand.clear()`, `discard.clear()` y `deck.reset()` |
| La mano del rival boca abajo | `face_up` apagado en su `CardPile` |
| Datos propios en las cartas | `class_name EventCard extends CardData` con `@export` tipados |
| Otro diseño de carta (marco, costo arriba) | Una escena con `var card: CardData` en `card_scene` del `HandView` |
| Que las cartas salten en vez de deslizarse | `settle_time` 0 en el `HandView` |
| Una mano por jugador en tus reglas | Un `CardStack` por jugador y `hand.use_stack(player.hand)` |
| Guardar y cargar | `pile.to_dict()` y `pile.use_stack(CardStack.from_dict(data, all_cards))` |

## Tips

- **Las reglas usan `CardStack`, no el nodo.** Guardá las pilas de cada jugador en el estado de tu partida y mostralas con `pile.use_stack(player.hand)`. Las señales salen del `CardStack` y los nodos las nombran con el `CardPile` que muestra cada pila, así una animación sabe de dónde viene una carta.
- **Un solo generador por partida** hace que un replay o la red den lo mismo: asignalo a cada `Deck` (`deck.rng = match_rng`) o pasalo en cada `shuffle(rng)`.
- **Con copias, usá índices.** `move_at(index, …)` y `remove_at(index)`; `move(card, …)` toma la primera copia desde arriba.
- **«Cualquiera de» o una condición propia** para robar o jugar es una regla del juego: chequeala antes de llamar `draw_to` o `move_at`.
- **En red**, el servidor mezcla y roba, y manda `to_dict()` de las pilas que cada jugador puede ver (o la semilla, si todos pueden ver todo).
- **Para que `to_dict` guarde una carta**, cada `CardData` distinta lleva su propio `id`; las copias comparten el suyo.

## Tests

```bash
godot --headless --path deckkit_lab --script res://addons/deck_kit/tests/deck_test_runner.gd
```

Sale `DECKKIT TESTS PASS (n)`. Los tests cubren:

- La pila sola: mirar, agregar y sacar, las copias por índice (`move_at`, `remove_at`), robar a otra pila (orden y señales), mover (también dentro de la misma), el tope, mezclar (misma semilla, mismo orden, contra un orden fijo de la semilla 42), rellenar, los errores y `to_dict` (también por JSON).
- Los nodos: la pila del inspector, las señales que nombran la otra pila (también cuando roban tus reglas), `showing` y que se limpie, los cambios en vivo, `use_stack`, los avisos y el `Deck` (`rng_seed`, semilla 0, un `rng` asignado que nadie toca, la mezcla del arranque después del `_ready` del padre, `refill_from`, `reset`, y guardar, cargar y rellenar con la misma mezcla).
- El `HandView`: dónde va cada carta, el `spread` que se achica, el abanico, el clic (apretar y soltar) y el hover con el índice (con copias), el teclado, arrastrar entre dos vistas por el viewport, `drop_index` al ordenar, la vista previa, `card_scene`, que las cartas se deslicen, que escuche solo las cartas que muestra y que no rehaga los paneles en cada cuadro.
- El ejemplo jugado con sus botones, clics y arrastres (también sobre una de dos copias, y al descarte y de vuelta), y la misma semilla dos veces.
- Que el addon no nombre a ningún otro kit ni use el azar global.

En el editor real, el lab tiene un chequeo aparte: ver `deckkit_lab/README.md`.
