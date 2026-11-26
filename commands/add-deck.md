---
description: "Cartas (addon DeckKit): CardData por carta, un Deck con semilla o el rng de la partida, CardPile para la mano y el descarte, robar, mover por índice (copias), mezclar con tu RandomNumberGenerator, rellenar, un HandView en abanico con una escena por carta y guardar con to_dict."
---

Agregá **cartas** en el **proyecto Godot del juego** con el addon DeckKit:
- un `CardData` (`.tres`) por carta, o una subclase con los números del juego;
- un `Deck` con las cartas en `start_cards` y su `rng_seed` (o el `rng` de la partida);
- un `CardPile` por pila: la mano (con `max_size`), el descarte, la mesa (o un `CardStack` por pila en las reglas, mostrado con `use_stack`);
- un `HandView` que muestra la mano (dibujada o con una `card_scene` propia) y avisa `card_pressed(card, index)`.

Después la persona ve las cartas en el inspector y en el editor; el agente arma y explica.

Esto **no** son las reglas de las cartas: el kit sabe qué carta está dónde, y el juego decide qué hace cada una, cuándo se roba y cuánto cuesta. **No** son los turnos, los costos ni la red: el juego conecta.

Cargar: `godot-deck-kit`, `godot-composition-first`.

Si falta `addons/deck_kit/`:

```bash
./install.sh --addon /ABS/GODOT_ROOT deck_kit
```

Habilitá **DeckKit**. Si `godot-studio-workflow` está cargado: orquestador → árbol (este chat si son 1–3 archivos; si no, `studio-tech-lead`) → OK → `studio-developer`. Sin subagente extra.

## 1. Alcance

Si falta, preguntá en una sola tanda:

1. Qué cartas hay (cuántas distintas y cuántas copias de cada una) y qué datos lleva cada una (título, texto, arte, tags, números del juego).
2. Qué pilas hay: el mazo, la mano de cada jugador, el descarte, la mesa. Cuántas cartas entran en la mano.
3. Cuándo se roba y cuántas, qué pasa cuando el mazo se vacía (rellenar con el descarte, perder) y si la mano llena descarta.
4. Si el orden tiene que repetirse (semilla fija, replay, red) y si ya hay un `RandomNumberGenerator` de la partida.
5. Cómo se ven y cómo se juegan: mano en fila o en abanico, el diseño de la carta (¿una escena propia?), mazo boca abajo, mano del rival oculta; clic, teclado o mando, y si las cartas se arrastran (a qué vistas). Si el juego guarda la partida o es en red.

## 2. Plan

Mostrá el árbol de archivos antes de tocar el juego (`[+]` nuevo, `[~]` cambiado, `[-]` borrado), por ejemplo:

```
[~] project.godot                        # plugin DeckKit
[+] cards/strike_card.tres               # CardData: id, title, text, art, tags (uno por carta)
[+] cards/event_card.gd                  # class_name EventCard extends CardData: @export var food
[+] cards/storm_card.tres                # EventCard
[+] table/table.tscn                     # Deck (start_cards, rng_seed), Hand (CardPile, max_size 5), Discard
[+] table/table.gd                       # draw_to, refill_from, card_pressed → move_at(index) al descarte
[+] cards/card_face.tscn                 # card_scene: raíz Control con card_face.gd (@tool, var card: CardData)
[~] ui/hud.tscn                          # HandView con pile = Hand y card_scene
[~] docs/tuning.md                       # tamaño de la mano, rng_seed
```

Arrancá desde `addons/deck_kit/examples/minimal/minimal.tscn` (robar, descartar con un clic, rellenar, la semilla).

## 3. Implementar

Seguí [godot-deck-kit](../skills/godot-deck-kit/SKILL.md) y `addons/deck_kit/README.md`.

- Un `.tres` por carta en una carpeta del juego, cada una con su `id`. Los números del juego en una subclase de `CardData` con `@export` tipados.
- `start_cards`, `max_size` y `face_up` en el inspector de cada pila; `rng_seed` y `shuffle_at_start` en el `Deck`.
- Las reglas mueven con `draw_to`, `move_at` (por índice: con copias, la carta justa) y `refill_from`, y mezclan con `shuffle(rng)`. Con el generador de la partida: `deck.rng = match_rng` en el `_ready` del padre (el mazo se mezcla al terminar ese cuadro).
- Lo robado se escucha con `added` en la mano (`from == deck`), robe el nodo o roben las reglas.
- El diseño de la carta: una escena en `card_scene` con `var card: CardData`; `settle_time` para que se deslicen.
- Arrastrar: `drag_cards` en las vistas que dan y reciben, y en cada una `card_dropped` → `from.pile.move_at(from_index, to.pile, to_index)`. El teclado y el mando ya andan (`keyboard`).
- Con un `CardStack` por jugador en las reglas: `hand.use_stack(player.hand)`, y la vista escucha `rebuilt`.
- Guardar con `to_dict()` y cargar con `use_stack(CardStack.from_dict(data, all_cards))`; para seguir la misma mezcla, `deck.rng.seed` y `deck.rng.state`. En red, el servidor mezcla y roba.
- Decile a la persona cómo verlo: las cartas se arrastran a `start_cards`, el `HandView` las dibuja en el editor, y el nodo avisa de un lugar vacío, una carta sin `id` o más cartas que el tope.

## 4. Listo cuando

- Las pilas no muestran avisos y la persona vio las cartas en el inspector y en el editor.
- F6: robar respeta el tope de la mano; clickear una carta mueve esa (aunque haya copias); rellenar devuelve el descarte mezclado; la misma semilla da el mismo orden.
- Nadie usa `randi()`, `Array.shuffle()` ni `pick_random()` para las cartas.
- Nada de reglas de cartas, costos, turnos ni red dentro de `addons/deck_kit`.
