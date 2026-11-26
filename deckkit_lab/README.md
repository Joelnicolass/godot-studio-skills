# deckkit_lab

- **Qué es:** un proyecto Godot chico que corre el ejemplo y los tests de DeckKit sin ningún juego.
- **Qué no es:** un juego. `addons/deck_kit` es un symlink a la copia canónica del kit.
- **Quién habla con quién:** nadie más. Los tests arman sus propios árboles, y `test_examples` juega `minimal` con sus botones y clics (robar, descartar una de dos copias, arrastrar al descarte y de vuelta, rellenar y repartir con la misma semilla dos veces).
- **Verificar:** `godot --headless --path deckkit_lab --script res://addons/deck_kit/tests/deck_test_runner.gd` → `DECKKIT TESTS PASS (n)`. La primera vez, importá una vez antes (`godot --headless --path deckkit_lab --import`).
- **Chequeo del editor:** `godot --headless --editor --path deckkit_lab -- --deckkit-editor-check` → `DECKKIT EDITOR CHECK PASS (n)`. El plugin `editor_check` solo actúa con ese argumento (sin él, abrir el lab es normal). Abre una copia temporal de `minimal.tscn` en el editor, mira que el `HandView` del mazo muestre las 12 cartas de inicio, cambia `start_cards` y `card_scene` por el historial del editor (como el inspector), deshace y rehace con Ctrl/Cmd+Z, guarda y lee el archivo; al terminar borra la copia y verifica que el ejemplo no se tocó. Es el único chequeo que pasa por el editor real y **no reemplaza** mirar las cartas con los ojos.
- **Jugar:** abrí el proyecto. F5 corre `minimal`.
