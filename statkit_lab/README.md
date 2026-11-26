# statkit_lab

- **Qué es:** un proyecto Godot chico que corre el ejemplo y los tests de StatKit sin ningún juego.
- **Qué no es:** un juego. `addons/stat_kit` es un symlink a la copia canónica del kit.
- **Quién habla con quién:** nadie más. Los tests arman sus propios árboles, y `test_examples` juega `minimal` con sus botones (espada, escudo, pantano, los dos anillos y la bendición).
- **Verificar:** `godot --headless --path statkit_lab --script res://addons/stat_kit/tests/stat_test_runner.gd` → `STATKIT TESTS PASS (n)`. La primera vez, importá una vez antes (`godot --headless --path statkit_lab --import`).
- **Jugar:** abrí el proyecto. F5 corre `minimal`.
- **Chequeo del editor:** `godot --headless --editor --path statkit_lab -- --statkit-editor-check` → `STATKIT EDITOR CHECK PASS (n)`. El plugin `editor_check` solo actúa con ese argumento (sin él, abrir el lab es normal). Abre el ejemplo, elige `Hero` y lee los valores que muestra el grupo **Values** del inspector; después abre una copia en `editor_check/tmp`, cambia `amount` de un modificador, `max_values`, `base_values` y `start_modifiers` como lo hace el inspector, deshace con Cmd/Ctrl+Z, guarda la escena y mira que **Values** no quede guardado. Nunca escribe los archivos del ejemplo (lo comprueba) y borra la copia al terminar. Es el único chequeo que pasa por el editor real y **no reemplaza** mirar el inspector con los ojos.
- **Mirar el inspector:** abrí `minimal.tscn` y elegí `Hero`. En el grupo **Values** está el valor final de cada estadística; cambiá `amount` en `modifiers/sword.tres` y el ataque cambia sin correr nada.
