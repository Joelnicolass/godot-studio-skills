# Cambios de DeckKit

## 0.1.0

Primera versión:

- `CardData`: una carta como recurso (`id`, `title`, `text`, `art`, `tags`, `has_tag`). Un juego la extiende con campos tipados.
- `CardStack`: una pila de cartas como datos puros, con el índice 0 arriba y copias de la misma carta que se distinguen por índice. Mirar (`top`, `find_id`, `count_tag`), agregar y sacar (`add`, `remove_at`, `remove`, `take`, `clear`), `draw_to`, `move_at` y su atajo `move` (también dentro de la misma pila), un tope `max_size` que mueve solo lo que entra, `shuffle(rng)` con tu generador, `refill_from` y `to_dict` / `from_dict` con un catálogo. Señales `added`, `removed` y `shuffled`: todas salen de acá.
- `CardPile`: arma la pila desde el inspector o muestra la de tus reglas (`use_stack`). Sus señales nombran la otra pila como el `CardPile` que la muestra (`CardPile.showing(stack)`), también cuando mueven tus reglas. `face_up` y la señal `flipped`. Avisos del editor.
- `Deck`: un `CardPile` con su propio generador (`rng_seed`; 0 = una semilla propia) o el de tu partida (`rng`), que nunca se toca si lo asignaste. Se mezcla al empezar cuando la escena ya está lista (así el `_ready` de un padre le da `rng` antes), rellena mezclando y vuelve a empezar con `reset()`.
- `HandView`: muestra una pila en fila o en abanico, también en el editor, dibujada o con una escena por carta (`card_scene`). Las cartas se deslizan a su lugar (`settle_time`). Mouse (un clic es apretar y soltar sobre la misma carta), teclado y mando (`keyboard`: toma el foco, `ui_left` / `ui_right` eligen, `ui_accept` aprieta) y arrastrar entre vistas con la API de Godot (`drag_cards`; la vista donde cae emite `card_dropped` y el juego mueve la carta). `card_pressed(card, index)`, `card_hovered(card, index)`, `card_dropped(card, from_index, from, to_index)`, `card_index_at`, `card_at`, `card_rect`, `drop_index`, `drag_preview` y `HandView.CardDrag`.
- Ejemplo `examples/minimal` (mazo de 12 cartas con tres copias de Coin, mano de 5 con `card_face.tscn`, descarte con clic o arrastrando, semilla), tests propios (también que no se use el azar global) y `deckkit_lab/` con un chequeo en el editor real.
