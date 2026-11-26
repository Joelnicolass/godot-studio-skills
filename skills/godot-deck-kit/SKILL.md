---
name: godot-deck-kit
description: >-
  Cartas en un juego Godot 4 con el addon DeckKit: qué cartas hay dónde (el
  mazo, la mano, el descarte, la mesa). Cada carta es un recurso `CardData`
  (id, título, texto, arte, tags) que el juego extiende con campos tipados;
  un `CardStack` de datos puros con el índice 0 arriba roba, mueve entre
  pilas, mezcla con tu `RandomNumberGenerator` (misma semilla, mismo orden),
  rellena el mazo con el descarte y se guarda con `to_dict`; las copias de una
  carta se distinguen por índice (`move_at`). Nodos `CardPile` y `Deck` (con
  `rng_seed` o el `rng` de la partida) para el editor y un `HandView` que
  muestra una mano en abanico, dibujada o con una escena por carta
  (`card_scene`), también en el editor, con mouse, teclado, mando y
  arrastrar entre vistas. Usar cuando el usuario quiere un
  mazo, una mano, robar cartas, un descarte, mezclar, un deckbuilder, un
  solitario, un juego de cartas, un mazo de eventos o /add-deck. No son las
  reglas de las cartas, los costos, los turnos ni la red.
---

# Godot — cartas, mazos y manos (DeckKit)

Addon `addons/deck_kit/` en el proyecto del **juego**. Referencia: `addons/deck_kit/README.md`.

Si el addon no está:

```bash
./install.sh --addon /path/to/godot-project deck_kit
```

Habilitá el plugin **DeckKit** (tipos `CardPile`, `Deck` y `HandView` en Create Node; `CardData` en New Resource). Pedido acotado: `/add-deck`. Composición: [godot-composition-first](../godot-composition-first/SKILL.md).

## Reglas

- **Dos niveles.** Las reglas del juego guardan un `CardStack` por pila (el mazo, la mano de cada jugador, el descarte): datos puros, se testea headless. `CardPile` y `Deck` son los nodos que la arman con las cartas del inspector o muestran la de tus reglas (`use_stack`).
- **Una carta es un `CardData`.** Un `.tres` por carta (`strike_card.tres`), con su `id`. Los números del juego van en una subclase con `@export` tipados (`class_name EventCard extends CardData`), nunca en un `Dictionary`.
- **Arriba es el índice 0.** `draw_to` pone cada carta arriba de la otra pila: la última robada queda arriba, y en un `HandView`, a la derecha.
- **Las copias se distinguen por índice.** La misma `CardData` puede estar varias veces: `move_at(index, to)` y `remove_at(index)` mueven esa justa; `move(card)` toma la primera copia desde arriba. `HandView.card_pressed(card, index)` da el índice de la que se clickeó.
- **Todo se mueve con el kit.** `draw_to`, `move_at` y `refill_from`, nunca sacando de un array a mano: así las señales `removed` / `added` llegan siempre, desde el `CardStack`, con la otra pila nombrada (`CardPile.showing(stack)`). Lo robado se escucha con `added` en la mano.
- **El azar es del juego.** `shuffle(rng)` pide un `RandomNumberGenerator`. El `Deck` trae el suyo con `rng_seed`; para compartir el de la partida, `deck.rng = match_rng` (en el `_ready` del padre alcanza: el mazo se mezcla al terminar ese cuadro). Nada de `randi()`, `randomize()`, `Array.shuffle()` ni `pick_random()`: misma semilla, mismo orden.
- **Topes:** `max_size` (-1 = sin tope). Una pila llena recibe solo lo que entra; no es un error.
- **Editor primero.** Las cartas se arrastran a `start_cards`, el `HandView` las muestra en el editor (con `faces_in_editor`, también las de un mazo boca abajo) y el nodo avisa de un lugar vacío, una carta sin `id`, dos cartas con el mismo `id` y más cartas que el tope.
- **El diseño de la carta es una escena.** `HandView.card_scene`: una raíz `Control` con `var card: CardData` (y `@tool` para verla en el editor). El `HandView` la ubica, la desliza (`settle_time`) y maneja el mouse. Sin escena, dibuja un panel simple.
- **La vista escucha.** `added`, `removed`, `shuffled`, `rebuilt` y `flipped`; el `HandView` ya lo hace solo. `card_pressed` y `card_hovered` (con el índice) para jugar con el mouse, el teclado o el mando (`keyboard`, encendido: flechas y `ui_accept`).
- **Arrastrar es del juego.** Con `drag_cards` en las dos vistas, la vista donde cae una carta emite `card_dropped(card, from_index, from, to_index)` y el juego la mueve: `from.pile.move_at(from_index, to.pile, to_index)`. El kit no mueve nada solo.
- **Guardar.** `to_dict()` guarda ids; `CardStack.from_dict(data, catalog)` los busca en la lista de cartas del juego. Para seguir la misma mezcla, guardá `deck.rng.seed` y `deck.rng.state` y ponelos en ese orden al cargar.
- **No tiene** estado por copia (una carta mejorada es otra `CardData`) ni cara por carta (`face_up` es de la pila).
- **Ningún kit depende de otro.** DeckKit no tiene reglas de cartas, costos, turnos, red ni autoload: el juego conecta.

## Árbol

```
Table (Node)
├── Deck (Deck)              # start_cards = [cards/*.tres], rng_seed, face_up apagado
├── Hand (CardPile)          # max_size 5
├── Discard (CardPile)
└── Hud (Control)
    ├── HandView (HandView)  # pile = Hand, card_scene; card_pressed → hand.move_at(index, discard)
    └── Draw (Button)        # deck.draw_to(hand)
```

Arrancá desde `addons/deck_kit/examples/minimal/minimal.tscn`.

## Con otros kits

El juego escribe el pegamento; el addon no nombra a nadie.

- **TurnKit:** en la fase de robar, `turns.phase_started.connect(func(phase): if phase == &"draw": deck.draw_to(hand, 2))`.
- **WalletKit:** una carta que cuesta es una subclase (`class_name PlayCard extends CardData` con `@export var cost: Dictionary[StringName, int]`); al jugarla, con `card` tipada como `PlayCard`: `if wallet.pay(card.cost): hand.move_at(index, discard)`, con el `index` de `card_pressed`.
- **CommandKit:** `do_play(seat, index)` mueve la carta con `hand.move_at(index, discard)` y `undo_play(seat, index)` la devuelve con `discard.move_at(0, hand, index)`. El robo y la mezcla no se deshacen. El `rng` de la partida vive en el estado del juego y se asigna al `Deck`, así un replay roba lo mismo.

## Qué va dónde

| Kit | Juego |
|---|---|
| Qué cartas hay en cada pila y en qué orden | Qué hace cada carta y cuándo se juega |
| Robar, mover, rellenar, el tope | Cuántas se roban, cuándo se rellena, qué pasa con la mano llena |
| Mezclar con un `rng` | El `rng` y su semilla, en el estado de la partida |
| `CardData` con id, título, texto, arte y tags | Las subclases con los números del juego |
| `HandView`, `card_scene`, `settle_time`, `card_pressed`, `card_hovered`, `card_dropped` | El diseño de la carta, sonidos, la mesa, qué pasa cuando una carta cae en otra vista |
| `to_dict` / `from_dict` | Dónde se guarda y qué ve cada jugador por la red |

## Listo cuando

- El `Deck` y los `CardPile` no muestran avisos y el `HandView` muestra las cartas en el editor.
- F6: robar llena la mano hasta su tope, clickear descarta esa copia, rellenar mezcla, y la misma semilla da el mismo orden.
- Nadie llama `randi()`, `Array.shuffle()` ni `pick_random()` para las cartas.
- `godot --headless --path deckkit_lab --script res://addons/deck_kit/tests/deck_test_runner.gd` da `DECKKIT TESTS PASS` (en el repo del kit).

## Antipatrones

- Las reglas de una carta (daño, costo, efecto) dentro del kit: van en el juego, o en una subclase de `CardData` como datos.
- Un `Dictionary` de datos en la carta en vez de `@export` tipados en una subclase.
- Un `Array` propio de cartas al lado del `CardStack`: las señales no llegan y la vista no se entera.
- `move(card, …)` con la `CardData` de un clic cuando hay copias: sale la primera copia, no la clickeada. Usá `move_at(index, …)`.
- Llamar `deck.reset()` solo para que use el `rng` de la partida: alcanza con asignarlo en el `_ready` del padre.
- `Array.shuffle()` o un `RandomNumberGenerator.new()` sin semilla en cada mezcla: el orden no se repite.
- Una pila por jugador creada desde el nodo: las reglas la guardan y el nodo la muestra con `use_stack`.
- Guardar las cartas por título o por ruta: se guardan por `id`, y cada carta distinta tiene el suyo.
