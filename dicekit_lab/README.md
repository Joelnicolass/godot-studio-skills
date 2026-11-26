# dicekit_lab

- **Qué es:** un proyecto Godot chico que corre el ejemplo y los tests de DiceKit sin ningún juego.
- **Qué no es:** un juego. `addons/dice_kit` es un symlink a la copia canónica del kit.
- **Quién habla con quién:** nadie más. Los tests arman sus propios árboles, y `test_examples` juega `minimal` con sus botones (también con la misma semilla dos veces).
- **Verificar:** `godot --headless --path dicekit_lab --script res://addons/dice_kit/tests/dice_test_runner.gd` → `DICEKIT TESTS PASS (n)`. La primera vez, importá una vez antes (`godot --headless --path dicekit_lab --import`). El proyecto tiene encendidos los avisos estrictos de GDScript (`untyped_declaration` y `unsafe_*`).
- **Jugar:** abrí el proyecto. F5 corre `minimal`.
- **Chequeo del editor:** `godot --headless --editor --path dicekit_lab -- --dicekit-editor-check` → `DICEKIT EDITOR CHECK PASS (n)`. El plugin `editor_check` solo actúa con ese argumento (sin él, abrir el lab es normal). Abre `minimal.tscn` en el editor, mira los dados de la bandeja en la vista 3D, cambia `rng_seed` y `count` desde el inspector (y deshace con el atajo), aprieta **Roll** y lee `last_result`. Nunca guarda el ejemplo: guarda una copia en `editor_check/tmp`, la revisa y la borra, y al final comprueba que el ejemplo en disco no cambió. Es el único chequeo que pasa por el editor real y **no reemplaza** mirar el inspector y la vista 3D con los ojos.
